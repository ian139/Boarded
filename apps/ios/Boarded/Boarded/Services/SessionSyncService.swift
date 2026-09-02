import Foundation
import Network
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Replays locally-pending sessions and attempts to Supabase. Replay is
/// idempotent because every record carries a client-generated UUID and the
/// server upserts on `id`; a replayed write never duplicates data. Attempts are
/// never dropped: a failed attempt stays `failed` and is retried on the next
/// connectivity or app-active trigger.
@MainActor
final class SessionSyncService: ObservableObject {
    private enum ReplayError: LocalizedError {
        case missingImage(UUID)
        case notSent(UUID)

        var errorDescription: String? {
            switch self {
            case .missingImage(let draftID):
                return "The image for pending draft \(draftID.uuidString) is missing."
            case .notSent(let attemptID):
                return "Only sent attempts can be shared (\(attemptID.uuidString))."
            }
        }
    }

    private enum DraftImageCleanupError: LocalizedError {
        case invalidFileName(String)
        case failed(String, String)

        var errorDescription: String? {
            switch self {
            case .invalidFileName(let fileName):
                return "The draft image file name is invalid: \(fileName)."
            case .failed(let fileName, let reason):
                return "Failed to remove draft image \(fileName): \(reason)"
            }
        }
    }
    @Published private(set) var state: SyncState = .synced
    @Published private(set) var errorMessage: String?

    private let repository: any SessionRepository
    private let feedRepository: any FeedRepository
    private let modelContext: ModelContext
    private let userID: UUID
    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "boarded.session-sync.monitor")

    private var isSyncing = false
    private var hasConnectivity = true
    private var appActiveObserver: NSObjectProtocol?

    var isOnline: Bool { hasConnectivity }

    convenience init(
        repository: any SessionRepository,
        modelContext: ModelContext,
        userID: UUID,
        connectivityOverride: Bool? = nil
    ) {
        self.init(
            repository: repository,
            feedRepository: AppServices.feedRepository,
            modelContext: modelContext,
            userID: userID,
            connectivityOverride: connectivityOverride
        )
    }

    init(
        repository: any SessionRepository,
        feedRepository: any FeedRepository,
        modelContext: ModelContext,
        userID: UUID,
        connectivityOverride: Bool? = nil
    ) {
        self.repository = repository
        self.feedRepository = feedRepository
        self.modelContext = modelContext
        self.userID = userID
        self.pathMonitor = NWPathMonitor()
        self.hasConnectivity = connectivityOverride ?? true
        if connectivityOverride == nil {
            pathMonitor.pathUpdateHandler = { [weak self] path in
                let online = path.status == .satisfied
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let wasOffline = !self.hasConnectivity
                    self.hasConnectivity = online
                    if online && wasOffline {
                        await self.replay()
                    }
                }
            }
            pathMonitor.start(queue: monitorQueue)
        }

        #if canImport(UIKit)
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.replay()
            }
        }
        #endif
    }

    deinit {
        pathMonitor.cancel()
        if let appActiveObserver {
            NotificationCenter.default.removeObserver(appActiveObserver)
        }
    }

    /// Persists a pending session locally before any network I/O. Throws when
    /// the save fails so callers never silently lose a session.
    func enqueue(session: PendingSession) throws {
        session.syncState = .queued
        modelContext.insert(session)
        try modelContext.save()
        state = .queued
        errorMessage = nil
    }

    /// Persists a pending attempt locally before any network I/O. Throws when
    /// the save fails so callers never silently lose an attempt.
    func enqueue(attempt: PendingAttempt) throws {
        attempt.syncState = .queued
        modelContext.insert(attempt)
        try modelContext.save()
        state = .queued
        errorMessage = nil
    }

    /// Writes an optional image before persisting the draft. If persistence
    /// fails, the newly-written image is removed so a draft never points at a
    /// partial or unrelated file.
    func enqueue(draft: PendingSendDraft, imageData: Data? = nil) throws {
        var wroteImage = false
        if let imageData {
            let fileName = draft.imageFileName ?? "\(draft.id.uuidString).jpg"
            draft.imageFileName = fileName
            try DraftImageStore.write(imageData, fileName: fileName)
            wroteImage = true
        }

        draft.syncState = .queued
        modelContext.insert(draft)
        do {
            try modelContext.save()
        } catch {
            if wroteImage, let fileName = draft.imageFileName {
                DraftImageStore.delete(fileName: fileName)
            }
            throw error
        }
        state = .queued
        errorMessage = nil
    }

    /// Removes an attempt from the local timeline. Attempts that have entered
    /// replay are represented by a durable tombstone so an undo cannot be
    /// lost between an in-flight upsert and a later retry. Linked send-post drafts
    /// and their draft images are cleaned up so sync cannot remain queued.
    func delete(attempt: PendingAttempt) throws {
        guard attempt.userId == userID else { return }
        let linkedDrafts = fetchAllDrafts().filter { $0.attemptId == attempt.id }
        let imageFileNames = linkedDrafts.compactMap(\.imageFileName)

        for draft in linkedDrafts {
            modelContext.delete(draft)
        }

        let requiresRemoteDelete = attempt.syncState != .queued
        if requiresRemoteDelete, !fetchAllAttemptDeletions().contains(where: { $0.id == attempt.id }) {
            modelContext.insert(
                PendingAttemptDeletion(id: attempt.id, userId: attempt.userId)
            )
        }
        modelContext.delete(attempt)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            state = .failed
            errorMessage = error.localizedDescription
            throw error
        }

        let hasPendingWork = !fetchPendingSessions().isEmpty
            || !fetchPendingAttempts().isEmpty
            || !fetchPendingDrafts().isEmpty
            || !fetchPendingAttemptDeletions().isEmpty
        state = requiresRemoteDelete || hasPendingWork ? .queued : .synced
        errorMessage = nil

        var cleanupError: DraftImageCleanupError?
        for fileName in imageFileNames {
            do {
                try cleanupDraftImage(fileName: fileName)
            } catch let error as DraftImageCleanupError {
                cleanupError = cleanupError ?? error
            }
        }
        if let cleanupError {
            state = .failed
            errorMessage = cleanupError.localizedDescription
            throw cleanupError
        }
    }

    /// Removes a pending or failed send-post draft without touching its
    /// already-synced climbing attempt. This is used when the composer replaces
    /// a saved draft with a different send, or when a draft is explicitly discarded.
    /// If an image is associated with the draft, its remote storage object is deleted
    /// idempotently before the local database row and cached image are removed.
    /// If remote deletion fails, the local draft and image are retained with a
    /// retryable error.
    func delete(draft: PendingSendDraft) async throws {
        guard let attempt = fetchAllAttemptsIncludingSynced().first(where: { $0.id == draft.attemptId }),
              attempt.userId == userID else {
            return
        }
        let fileName = draft.imageFileName
        let path = canonicalImagePath(userID: attempt.userId, postID: draft.id)

        if fileName != nil {
            do {
                try await feedRepository.deletePostImage(path: path)
            } catch {
                state = .failed
                errorMessage = error.localizedDescription
                throw error
            }
        }

        modelContext.delete(draft)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            state = .failed
            errorMessage = error.localizedDescription
            throw error
        }
        state = hasPendingWork() ? .queued : .synced
        errorMessage = nil
        if let fileName {
            do {
                try cleanupDraftImage(fileName: fileName)
            } catch let error as DraftImageCleanupError {
                state = .failed
                errorMessage = error.localizedDescription
                throw error
            }
        }
    }

    func replay() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let pendingSessions = fetchPendingSessions()
        let pendingAttempts = fetchPendingAttempts()
        let pendingAttemptPayloads = pendingAttempts.map { (id: $0.id, remote: $0.remote) }
        let pendingDrafts = fetchPendingDrafts()
        let pendingDeletions = fetchPendingAttemptDeletions()

        guard !pendingSessions.isEmpty
                || !pendingAttempts.isEmpty
                || !pendingDrafts.isEmpty
                || !pendingDeletions.isEmpty else {
            state = .synced
            errorMessage = nil
            return
        }

        // Claim every attempt before the first network await. Undo can
        // interleave with a session upsert, so a queued snapshot must already
        // be considered potentially remote when the user removes it.
        for attempt in pendingAttempts {
            attempt.syncState = .syncing
        }
        do {
            try modelContext.save()
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
            return
        }

        state = .syncing
        errorMessage = nil
        var replayFailed = false

        // Sessions first so attempts always have a parent row to reference.
        var sessionsReady = true
        for session in pendingSessions {
            session.syncState = .syncing
            try? modelContext.save()
            do {
                _ = try await repository.upsertSession(session.remote)
                session.syncState = .synced
                try? modelContext.save()
            } catch {
                session.syncState = .failed
                try? modelContext.save()
                replayFailed = true
                sessionsReady = false
                errorMessage = error.localizedDescription
                break
            }
        }

        if sessionsReady {
            for payload in pendingAttemptPayloads {
                do {
                    _ = try await repository.upsertAttempt(payload.remote)
                    // An undo can happen while the upsert is in flight. In
                    // that case leave the tombstone to the delete phase below
                    // instead of resurrecting the local attempt as synced.
                    if !fetchAllAttemptDeletions().contains(where: { $0.id == payload.id }),
                       let attempt = fetchAllAttempts().first(where: { $0.id == payload.id }) {
                        attempt.syncState = .synced
                        try? modelContext.save()
                    }
                } catch {
                    // The attempt may have been deleted while the request was
                    // in flight. Its tombstone, not the deleted model, owns
                    // the retry in that case.
                    if !fetchAllAttemptDeletions().contains(where: { $0.id == payload.id }),
                       let attempt = fetchAllAttempts().first(where: { $0.id == payload.id }) {
                        attempt.syncState = .failed
                        try? modelContext.save()
                    }
                    replayFailed = true
                    errorMessage = error.localizedDescription
                }
            }
        }

        // Deletions intentionally follow every upsert, including an upsert
        // which failed locally after the network request began. This closes
        // the race where undo lands while a request is in flight.
        var deletionFailed = false
        for deletion in fetchPendingAttemptDeletions() {
            deletion.syncState = .syncing
            try? modelContext.save()
            do {
                try await repository.deleteAttempt(id: deletion.id)
                modelContext.delete(deletion)
                try modelContext.save()
            } catch {
                deletion.syncState = .failed
                try? modelContext.save()
                deletionFailed = true
                errorMessage = error.localizedDescription
            }
        }

        let attemptsByID = Dictionary(
            uniqueKeysWithValues: fetchAllAttempts().map { ($0.id, $0) }
        )
        var draftFailed = false

        for draft in pendingDrafts {
            guard let attempt = attemptsByID[draft.attemptId], attempt.syncState == .synced else {
                continue
            }

            draft.syncState = .syncing
            try? modelContext.save()
            do {
                guard attempt.remote.isSendEligible else {
                    throw ReplayError.notSent(attempt.id)
                }

                let imagePath: String?
                if let fileName = draft.imageFileName {
                    guard let imageData = DraftImageStore.read(fileName: fileName) else {
                        throw ReplayError.missingImage(draft.id)
                    }
                    let path = canonicalImagePath(userID: attempt.userId, postID: draft.id)
                    try await feedRepository.uploadPostImage(data: imageData, path: path)
                    imagePath = path
                } else {
                    imagePath = nil
                }

                _ = try await feedRepository.createPost(
                    id: draft.id,
                    attemptID: draft.attemptId,
                    caption: draft.caption,
                    imagePath: imagePath,
                    imageAlt: draft.imageAlt
                )
                modelContext.delete(draft)
                try modelContext.save()
                if let fileName = draft.imageFileName {
                    DraftImageStore.delete(fileName: fileName)
                }
            } catch {
                draft.syncState = .failed
                try? modelContext.save()
                draftFailed = true
                errorMessage = error.localizedDescription
            }
        }

        if replayFailed || deletionFailed || draftFailed {
            state = .failed
        } else if !fetchPendingSessions().isEmpty
                    || !fetchPendingAttempts().isEmpty
                    || !fetchPendingDrafts().isEmpty
                    || !fetchPendingAttemptDeletions().isEmpty {
            // Drafts whose attempts are not synced remain queued for a later
            // replay; they must not be published out of order.
            state = .queued
        } else {
            state = .synced
        }
    }

    private func fetchPendingSessions() -> [PendingSession] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingSession>(
            predicate: #Predicate {
                $0.userId == activeUserID && $0.syncStateRaw != "synced"
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPendingAttempts() -> [PendingAttempt] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingAttempt>(
            predicate: #Predicate {
                $0.userId == activeUserID && $0.syncStateRaw != "synced"
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPendingDrafts() -> [PendingSendDraft] {
        let ownedAttemptIDs = Set(fetchAllAttemptsIncludingSynced().map(\.id))
        let descriptor = FetchDescriptor<PendingSendDraft>(
            predicate: #Predicate { $0.syncStateRaw != "synced" }
        )
        return (try? modelContext.fetch(descriptor))?.filter {
            ownedAttemptIDs.contains($0.attemptId)
        } ?? []
    }

    private func fetchPendingAttemptDeletions() -> [PendingAttemptDeletion] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingAttemptDeletion>(
            predicate: #Predicate {
                $0.userId == activeUserID && $0.syncStateRaw != "synced"
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllAttemptDeletions() -> [PendingAttemptDeletion] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingAttemptDeletion>(
            predicate: #Predicate { $0.userId == activeUserID }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllAttemptsIncludingSynced() -> [PendingAttempt] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingAttempt>(
            predicate: #Predicate { $0.userId == activeUserID }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllAttempts() -> [PendingAttempt] {
        fetchAllAttemptsIncludingSynced()
    }

    private func fetchAllDrafts() -> [PendingSendDraft] {
        let ownedAttemptIDs = Set(fetchAllAttemptsIncludingSynced().map(\.id))
        return (try? modelContext.fetch(FetchDescriptor<PendingSendDraft>()))?.filter {
            ownedAttemptIDs.contains($0.attemptId)
        } ?? []
    }

    private func hasPendingWork() -> Bool {
        !fetchPendingSessions().isEmpty
            || !fetchPendingAttempts().isEmpty
            || !fetchPendingDrafts().isEmpty
            || !fetchPendingAttemptDeletions().isEmpty
    }

    private func cleanupDraftImage(fileName: String) throws {
        guard isSafeDraftImageFileName(fileName) else {
            throw DraftImageCleanupError.invalidFileName(fileName)
        }

        let url = DraftImageStore.directory.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw DraftImageCleanupError.failed(fileName, error.localizedDescription)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            throw DraftImageCleanupError.failed(fileName, "The file is still present.")
        }
    }

    private func isSafeDraftImageFileName(_ fileName: String) -> Bool {
        !fileName.isEmpty
            && fileName != "."
            && fileName != ".."
            && fileName == URL(fileURLWithPath: fileName).lastPathComponent
            && !fileName.contains("\0")
    }

    private func canonicalImagePath(userID: UUID, postID: UUID) -> String {
        "\(userID.uuidString.lowercased())/\(postID.uuidString.lowercased()).jpg"
    }
}
