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
    @Published private(set) var state: SyncState = .synced

    private let repository: any SessionRepository
    private let modelContext: ModelContext
    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "boarded.session-sync.monitor")

    private var isSyncing = false
    private var hasConnectivity = true
    private var appActiveObserver: NSObjectProtocol?

    init(repository: any SessionRepository, modelContext: ModelContext) {
        self.repository = repository
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
    }

    /// Persists a pending attempt locally before any network I/O. Throws when
    /// the save fails so callers never silently lose an attempt.
    func enqueue(attempt: PendingAttempt) throws {
        attempt.syncState = .queued
        modelContext.insert(attempt)
        try modelContext.save()
        state = .queued
    }

    func replay() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let pendingSessions = fetchPendingSessions()
        let pendingAttempts = fetchPendingAttempts()

        guard !pendingSessions.isEmpty || !pendingAttempts.isEmpty else {
            state = .synced
            return
        }

        state = .syncing

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
                return
            }
        }

        state = .synced
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
}
