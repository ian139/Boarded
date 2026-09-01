import Foundation
import Combine
import SwiftUI

protocol AttemptRepository {
    func load() -> AttemptLogSnapshot
    func save(_ snapshot: AttemptLogSnapshot)
}

struct UserDefaultsAttemptRepository: AttemptRepository {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "boarded.attempt-log.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> AttemptLogSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(AttemptLogSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func save(_ snapshot: AttemptLogSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
enum AttemptLogPresentationState: Equatable {
    case ready
    case loading
    case error(String)
}

@MainActor
final class AttemptLogStore: ObservableObject {
    @Published private(set) var snapshot: AttemptLogSnapshot
    @Published var isOffline: Bool
    @Published private(set) var confirmation: String? = nil
    @Published private(set) var presentedResult: ClimbSession? = nil
    @Published private(set) var presentationState: AttemptLogPresentationState = .ready
    private let isDeterministicFixture: Bool

    private let repository: any AttemptRepository

    init(repository: any AttemptRepository = UserDefaultsAttemptRepository(), fixture: AttemptLogFixture? = nil) {
        self.repository = repository
        isDeterministicFixture = fixture != nil
        let fixtureSnapshot = fixture.map(Self.snapshot(for:))
        snapshot = fixtureSnapshot?.0 ?? repository.load()
        isOffline = fixtureSnapshot?.1 ?? false
        if fixture == .result || fixture == .noSend { presentedResult = snapshot.history.first }
        if fixture == .loading { presentationState = .loading }
        if fixture == .error { presentationState = .error("Attempts could not be loaded. Your saved sessions remain on this device.") }
        if fixture == .success { confirmation = "All attempts synced" }
        if fixture == nil, snapshot.syncState != .synced {
            Task { [weak self] in await self?.retrySync() }
        }
    }

    var activeSession: ClimbSession? { snapshot.activeSession }
    var history: [ClimbSession] { snapshot.history }
    var syncState: SyncState { snapshot.syncState }

    func startSession(routeName: String, grade: String, at date: Date = Date()) {
        guard snapshot.activeSession == nil else { return }
        snapshot.activeSession = ClimbSession(
            id: UUID(), startedAt: date, routeName: routeName, grade: grade, attempts: []
        )
        queueChange(message: "Session started")
    }

    func record(_ outcome: AttemptOutcome, at date: Date = Date()) {
        guard snapshot.activeSession != nil else { return }
        snapshot.activeSession?.attempts.append(ClimbAttempt(id: UUID(), occurredAt: date, outcome: outcome))
        queueChange(message: "\(outcome.title) recorded")
    }

    func undoLatestAttempt() {
        guard snapshot.activeSession?.attempts.isEmpty == false else { return }
        snapshot.activeSession?.attempts.removeLast()
        queueChange(message: "Latest attempt undone")
    }

    func endSession(at date: Date = Date()) {
        guard var session = snapshot.activeSession else { return }
        session.endedAt = date
        snapshot.activeSession = nil
        snapshot.history.insert(session, at: 0)
        presentedResult = session
        queueChange(message: "Session saved")
    }

    func dismissResult() { presentedResult = nil }
    func clearConfirmation() { confirmation = nil }
    func reload() {
        presentationState = .ready
        snapshot = repository.load()
    }

    func retrySync() async {
        guard snapshot.syncState != .synced else { return }
#if DEBUG
        if isDeterministicFixture {
            if isOffline { isOffline = false }
            snapshot.syncState = .syncing
            persist()
            await Task.yield()
            snapshot.syncState = .synced
            confirmation = "All attempts synced"
            persist()
            return
        }
#endif
        snapshot.syncState = .queued
        confirmation = "Sync unavailable. Attempts remain saved on this device."
        persist()
    }

    private func queueChange(message: String) {
        snapshot.syncState = .queued
        confirmation = message
        persist()
    }

    private func persist() { repository.save(snapshot) }

    private static func snapshot(for fixture: AttemptLogFixture) -> (AttemptLogSnapshot, Bool) {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let sent = ClimbAttempt(id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, occurredAt: start.addingTimeInterval(95), outcome: .sent)
        let fell = ClimbAttempt(id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!, occurredAt: start.addingTimeInterval(42), outcome: .fell)
        var session = ClimbSession(id: UUID(uuidString: "00000000-0000-4000-8000-000000000010")!, startedAt: start, routeName: "North Arete", grade: "V6", attempts: [fell])
        switch fixture {
        case .empty, .loading, .error, .success:
            return (.empty, false)
        case .active:
            return (AttemptLogSnapshot(activeSession: session, history: [], syncState: .synced), false)
        case .offline:
            return (AttemptLogSnapshot(activeSession: session, history: [], syncState: .queued), true)
        case .queued:
            return (AttemptLogSnapshot(activeSession: session, history: [], syncState: .queued), false)
        case .sent:
            session.attempts.append(sent)
            return (AttemptLogSnapshot(activeSession: session, history: [], syncState: .queued), false)
        case .noSend:
            session.endedAt = start.addingTimeInterval(600)
            return (AttemptLogSnapshot(activeSession: nil, history: [session], syncState: .queued), false)
        case .result:
            session.attempts.append(sent)
            session.endedAt = start.addingTimeInterval(600)
            return (AttemptLogSnapshot(activeSession: nil, history: [session], syncState: .synced), false)
        }
    }
}
