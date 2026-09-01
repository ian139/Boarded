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
    @Published private(set) var state: SyncState = .synced
    @Published private(set) var errorMessage: String?

    private let repository: any SessionRepository
    private let feedRepository: any FeedRepository
    private let modelContext: ModelContext
    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "boarded.session-sync.monitor")

    private var isSyncing = false
    private var hasConnectivity = true
    private var appActiveObserver: NSObjectProtocol?

    var isOnline: Bool { hasConnectivity }

    convenience init(repository: any SessionRepository, modelContext: ModelContext) {
        self.init(
            repository: repository,
            feedRepository: AppServices.feedRepository,
            modelContext: modelContext
        )
    }

    init(
        repository: any SessionRepository,
        feedRepository: any FeedRepository,
        modelContext: ModelContext
    ) {
        self.repository = repository
        self.feedRepository = feedRepository
        self.modelContext = modelContext
        self.pathMonitor = NWPathMonitor()
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

    func replay() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let pendingSessions = fetchPendingSessions()
        let pendingAttempts = fetchPendingAttempts()
        let pendingDrafts = fetchPendingDrafts()

        guard !pendingSessions.isEmpty || !pendingAttempts.isEmpty || !pendingDrafts.isEmpty else {
            state = .synced
            errorMessage = nil
            return
        }

        state = .syncing
        errorMessage = nil

        // Sessions first so attempts always have a parent row to reference.
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
                state = .failed
                errorMessage = error.localizedDescription
                return
            }
        }

        for attempt in pendingAttempts {
            attempt.syncState = .syncing
            try? modelContext.save()
            do {
                _ = try await repository.upsertAttempt(attempt.remote)
                attempt.syncState = .synced
                try? modelContext.save()
            } catch {
                attempt.syncState = .failed
                try? modelContext.save()
                state = .failed
                errorMessage = error.localizedDescription
                return
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

        if draftFailed {
            state = .failed
        } else if !fetchPendingSessions().isEmpty
                    || !fetchPendingAttempts().isEmpty
                    || !fetchPendingDrafts().isEmpty {
            // Drafts whose attempts are not synced remain queued for a later
            // replay; they must not be published out of order.
            state = .queued
        } else {
            state = .synced
        }
    }

    private func fetchPendingSessions() -> [PendingSession] {
        let descriptor = FetchDescriptor<PendingSession>(
            predicate: #Predicate { $0.syncStateRaw != "synced" }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPendingAttempts() -> [PendingAttempt] {
        let descriptor = FetchDescriptor<PendingAttempt>(
            predicate: #Predicate { $0.syncStateRaw != "synced" }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPendingDrafts() -> [PendingSendDraft] {
        let descriptor = FetchDescriptor<PendingSendDraft>(
            predicate: #Predicate { $0.syncStateRaw != "synced" }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllAttempts() -> [PendingAttempt] {
        (try? modelContext.fetch(FetchDescriptor<PendingAttempt>())) ?? []
    }

    private func canonicalImagePath(userID: UUID, postID: UUID) -> String {
        "\(userID.uuidString.lowercased())/\(postID.uuidString.lowercased()).jpg"
    }
}
