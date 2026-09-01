import Foundation
import Combine
import SwiftData

@MainActor
final class SessionLoggerViewModel: ObservableObject {
    @Published private(set) var activeSession: PendingSession?
    @Published private(set) var attempts: [PendingAttempt] = []
    @Published private(set) var syncState: SyncState = .synced
    @Published private(set) var errorMessage: String?

    private let modelContext: ModelContext
    private let syncService: SessionSyncService
    private let userId: UUID
    private var replayTask: Task<Void, Never>?
    private var replayRequested = false

    init(modelContext: ModelContext, syncService: SessionSyncService, userId: UUID) {
        self.modelContext = modelContext
        self.syncService = syncService
        self.userId = userId
    }

    var isActive: Bool { activeSession != nil }

    func startSession(venueName: String, at date: Date = Date()) {
        guard activeSession == nil else { return }
        let session = PendingSession(
            userId: userId,
            venueName: venueName.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: date,
            endedAt: nil
        )
        do {
            try syncService.enqueue(session: session)
            activeSession = session
            attempts = []
            errorMessage = nil
            syncState = syncService.state
            scheduleOnlineReplay()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordAttempt(
        routeName: String,
        discipline: ClimbDiscipline,
        gradeSystem: GradeSystem,
        gradeLabel: String,
        outcome: AttemptOutcome,
        notes: String?,
        at date: Date = Date()
    ) {
        guard let session = activeSession else { return }
        let attempt = PendingAttempt(
            sessionId: session.id,
            userId: userId,
            boardRouteId: nil,
            routeName: routeName.trimmingCharacters(in: .whitespacesAndNewlines),
            discipline: discipline,
            gradeSystem: gradeSystem,
            gradeLabel: gradeLabel,
            outcome: outcome,
            attemptNumber: attempts.count + 1,
            notes: notes,
            occurredAt: date
        )
        do {
            try syncService.enqueue(attempt: attempt)
            attempts.append(attempt)
            errorMessage = nil
            syncState = syncService.state
            scheduleOnlineReplay()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoLatestAttempt() {
        guard let last = attempts.popLast() else { return }
        modelContext.delete(last)
        try? modelContext.save()
    }

    func endSession(at date: Date = Date()) {
        guard let session = activeSession else { return }
        session.endedAt = date
        do {
            try syncService.enqueue(session: session)
            activeSession = nil
            attempts = []
            errorMessage = nil
            syncState = syncService.state
            scheduleOnlineReplay()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retrySync() async {
        await syncService.replay()
        syncState = syncService.state
        errorMessage = syncService.errorMessage
    }

    private func scheduleOnlineReplay() {
        guard syncService.isOnline else { return }
        replayRequested = true
        guard replayTask == nil else { return }
        replayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.replayRequested {
                self.replayRequested = false
                await self.syncService.replay()
            }
            self.syncState = self.syncService.state
            self.errorMessage = self.syncService.errorMessage
            self.replayTask = nil
        }
    }
}
