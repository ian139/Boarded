import Foundation
import Network
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Replays locally-pending sessions, attempts, and session posts to Supabase.
/// Replay is idempotent because every record carries a client-generated UUID
/// and the server upserts on `id`; a replayed write never duplicates data.
/// Records are never dropped on failure: failed rows stay `failed` and are
/// retried on the next connectivity or app-active trigger.
@MainActor
final class SessionSyncService: ObservableObject {
    private enum ReplayError: LocalizedError {
        case missingImage(UUID)
        case invalidSession(UUID)
        case sessionNotEnded(UUID)
        case missingFeaturedAttempt(UUID)

        var errorDescription: String? {
            switch self {
            case .missingImage(let draftID):
                return "The image for pending draft \(draftID.uuidString) is missing."
            case .invalidSession(let sessionID):
                return "The session \(sessionID.uuidString) is invalid or not owned by the active user."
            case .sessionNotEnded(let sessionID):
                return "Session \(sessionID.uuidString) must be ended before a session post can be published."
            case .missingFeaturedAttempt(let attemptID):
                return "The featured attempt \(attemptID.uuidString) was not found."
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

    /// Writes the draft image before persisting the draft. Replaces any prior
    /// pending draft for the same session so there is never more than one
    /// pending draft per session. If persistence fails, the newly-written image
    /// is removed and changes are rolled back.
    func enqueue(draft: PendingSessionDraft, imageData: Data? = nil) throws {
        var wroteImage = false
        if let imageData {
            let fileName = draft.imageFileName.isEmpty ? "\(draft.id.uuidString).jpg" : draft.imageFileName
            draft.imageFileName = fileName
            try DraftImageStore.write(imageData, fileName: fileName)
            wroteImage = true
        }

        let priorDrafts = fetchAllDrafts().filter { $0.sessionId == draft.sessionId && $0.id != draft.id }
        let priorImageFiles = priorDrafts.map(\.imageFileName).filter { !$0.isEmpty && $0 != draft.imageFileName }

        for prior in priorDrafts {
            modelContext.delete(prior)
        }

        draft.syncState = .queued
        modelContext.insert(draft)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            if wroteImage && !draft.imageFileName.isEmpty {
                DraftImageStore.delete(fileName: draft.imageFileName)
            }
            throw error
        }

        for fileName in priorImageFiles {
            DraftImageStore.delete(fileName: fileName)
        }

        state = .queued
        errorMessage = nil
    }

    /// Removes an attempt from the local timeline. Attempts that have entered
    /// replay are represented by a durable tombstone so an undo cannot be
    /// lost between an in-flight upsert and a later retry. If this attempt was
    /// featured in a session-post draft, that draft and its image are cleaned
    /// up so sync cannot remain queued on a missing featured attempt.
    func delete(attempt: PendingAttempt) throws {
        guard attempt.userId == userID else { return }
        let linkedDrafts = fetchAllDrafts().filter { $0.featuredAttemptId == attempt.id }
        let imageFileNames = linkedDrafts.map(\.imageFileName).filter { !$0.isEmpty }

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

    /// Removes a pending or failed session-post draft.
    /// If an image is associated with the draft, its remote storage object is deleted
    /// idempotently before the local database row and cached image are removed.
    /// If remote deletion fails, the local draft and image are retained with a
    /// retryable error.
    func delete(draft: PendingSessionDraft) async throws {
        let isOwned = fetchAllSessionsIncludingSynced().contains(where: { $0.id == draft.sessionId && $0.userId == userID })
            || fetchAllAttemptsIncludingSynced().contains(where: { ($0.sessionId == draft.sessionId || $0.id == draft.featuredAttemptId) && $0.userId == userID })
        guard isOwned else {
            return
        }
        let fileName = draft.imageFileName
        let path = canonicalImagePath(userID: userID, postID: draft.id)

        do {
            try await feedRepository.deletePostImage(path: path)
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
            throw error
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
        if !fileName.isEmpty {
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

        let sessionsByID = Dictionary(
            uniqueKeysWithValues: fetchAllSessionsIncludingSynced().map { ($0.id, $0) }
        )
        let attemptsByID = Dictionary(
            uniqueKeysWithValues: fetchAllAttempts().map { ($0.id, $0) }
        )
        var draftFailed = false

        var seenDraftSessionIDs = Set<UUID>()
        for draft in pendingDrafts {
            guard seenDraftSessionIDs.insert(draft.sessionId).inserted else {
                // Duplicate pending draft for the same session; clean it up locally
                // so backend unique constraint is never violated.
                modelContext.delete(draft)
                try? modelContext.save()
                if !draft.imageFileName.isEmpty {
                    DraftImageStore.delete(fileName: draft.imageFileName)
                }
                continue
            }

            guard let session = sessionsByID[draft.sessionId],
                  session.userId == userID,
                  session.endedAt != nil,
                  session.syncState == .synced,
                  let featuredAttempt = attemptsByID[draft.featuredAttemptId],
                  featuredAttempt.userId == userID,
                  featuredAttempt.sessionId == session.id,
                  featuredAttempt.syncState == .synced else {
                continue
            }

            draft.syncState = .syncing
            try? modelContext.save()
            do {
                let fileName = draft.imageFileName
                guard let imageData = DraftImageStore.read(fileName: fileName) else {
                    throw ReplayError.missingImage(draft.id)
                }
                let path = canonicalImagePath(userID: session.userId, postID: draft.id)
                try await feedRepository.uploadPostImage(data: imageData, path: path)

                _ = try await feedRepository.createPost(
                    id: draft.id,
                    sessionID: draft.sessionId,
                    featuredAttemptID: draft.featuredAttemptId,
                    caption: draft.caption,
                    imagePath: path,
                    imageAlt: draft.imageAlt,
                    overlayStyle: draft.overlayStyle
                )
                modelContext.delete(draft)
                try modelContext.save()
                DraftImageStore.delete(fileName: fileName)
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
            // Drafts whose sessions or attempts are not synced remain queued
            // for a later replay; they must not be published out of order.
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

    private func fetchPendingDrafts() -> [PendingSessionDraft] {
        let ownedSessionIDs = Set(fetchAllSessionsIncludingSynced().map(\.id))
        let ownedAttemptSessionIDs = Set(fetchAllAttemptsIncludingSynced().map(\.sessionId))
        let allOwnedSessionIDs = ownedSessionIDs.union(ownedAttemptSessionIDs)
        guard !allOwnedSessionIDs.isEmpty else {
            return []
        }
        let descriptor = FetchDescriptor<PendingSessionDraft>(
            predicate: #Predicate { $0.syncStateRaw != "synced" }
        )
        let pending = (try? modelContext.fetch(descriptor)) ?? []
        return pending.filter { allOwnedSessionIDs.contains($0.sessionId) }
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

    private func fetchAllSessionsIncludingSynced() -> [PendingSession] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingSession>(
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

    private func fetchAllDrafts() -> [PendingSessionDraft] {
        let ownedSessionIDs = Set(fetchAllSessionsIncludingSynced().map(\.id))
        let ownedAttemptSessionIDs = Set(fetchAllAttemptsIncludingSynced().map(\.sessionId))
        let allOwnedSessionIDs = ownedSessionIDs.union(ownedAttemptSessionIDs)
        guard !allOwnedSessionIDs.isEmpty else {
            return []
        }
        let allDrafts = (try? modelContext.fetch(FetchDescriptor<PendingSessionDraft>())) ?? []
        return allDrafts.filter { allOwnedSessionIDs.contains($0.sessionId) }
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
