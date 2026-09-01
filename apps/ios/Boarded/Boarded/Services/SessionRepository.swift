import Foundation

protocol SessionRepository {
    func fetchSessions(userID: UUID) async throws -> [ClimbingSession]
    func fetchAttempts(sessionID: UUID) async throws -> [ClimbAttempt]
    func upsertSession(_ session: ClimbingSession) async throws -> ClimbingSession
    func upsertAttempt(_ attempt: ClimbAttempt) async throws -> ClimbAttempt
    func deleteAttempt(id: UUID) async throws
}

enum SessionRepositoryError: LocalizedError {
    case unavailable
    case notFound

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Session storage is unavailable. Check your Supabase configuration."
        case .notFound: return "The session or attempt could not be found."
        }
    }
}

/// Deterministic data source for previews and unit tests only. Production code
/// always uses SupabaseSessionRepository and surfaces configuration/network errors.
final class MockSessionRepository: SessionRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var sessions: [ClimbingSession]
    private var attempts: [ClimbAttempt]

    init(sessions: [ClimbingSession] = [], attempts: [ClimbAttempt] = []) {
        self.sessions = sessions
        self.attempts = attempts
    }

    func fetchSessions(userID: UUID) async throws -> [ClimbingSession] {
        lock.lock(); defer { lock.unlock() }
        return sessions.filter { $0.userId == userID }
    }

    func fetchAttempts(sessionID: UUID) async throws -> [ClimbAttempt] {
        lock.lock(); defer { lock.unlock() }
        return attempts.filter { $0.sessionId == sessionID }
    }

    func upsertSession(_ session: ClimbingSession) async throws -> ClimbingSession {
        lock.lock(); defer { lock.unlock() }
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        return session
    }

    func upsertAttempt(_ attempt: ClimbAttempt) async throws -> ClimbAttempt {
        lock.lock(); defer { lock.unlock() }
        if let index = attempts.firstIndex(where: { $0.id == attempt.id }) {
            attempts[index] = attempt
        } else {
            attempts.append(attempt)
        }
        return attempt
    }

    func deleteAttempt(id: UUID) async throws {
        lock.lock(); defer { lock.unlock() }
        guard let index = attempts.firstIndex(where: { $0.id == id }) else {
            return
        }
        attempts.remove(at: index)
    }
}

#if canImport(Supabase)
import Supabase

struct SupabaseSessionRepository: SessionRepository {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    @MainActor init() {
        self.init(client: SupabaseClientProvider.client)
    }

    func fetchSessions(userID: UUID) async throws -> [ClimbingSession] {
        guard let client else { throw SessionRepositoryError.unavailable }
        return try await client.from("climbing_sessions")
            .select("*")
            .eq("user_id", value: userID.uuidString)
            .order("started_at", ascending: false)
            .execute()
            .value
    }

    func fetchAttempts(sessionID: UUID) async throws -> [ClimbAttempt] {
        guard let client else { throw SessionRepositoryError.unavailable }
        return try await client.from("climb_attempts")
            .select("*")
            .eq("session_id", value: sessionID.uuidString)
            .order("attempt_number", ascending: true)
            .execute()
            .value
    }

    func upsertSession(_ session: ClimbingSession) async throws -> ClimbingSession {
        guard let client else { throw SessionRepositoryError.unavailable }
        let payload = SessionInsert(session: session)
        let rows: [ClimbingSession] = try await client.from("climbing_sessions")
            .upsert(payload, onConflict: "id")
            .select("*")
            .execute()
            .value
        guard let row = rows.first else { throw SessionRepositoryError.notFound }
        return row
    }

    func upsertAttempt(_ attempt: ClimbAttempt) async throws -> ClimbAttempt {
        guard let client else { throw SessionRepositoryError.unavailable }
        let payload = AttemptInsert(attempt: attempt)
        let rows: [ClimbAttempt] = try await client.from("climb_attempts")
            .upsert(payload, onConflict: "id")
            .select("*")
            .execute()
            .value
        guard let row = rows.first else { throw SessionRepositoryError.notFound }
        return row
    }

    func deleteAttempt(id: UUID) async throws {
        guard let client else { throw SessionRepositoryError.unavailable }
        _ = try await client.from("climb_attempts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

private struct SessionInsert: Encodable {
    let id: UUID
    let user_id: UUID
    let venue_name: String
    let started_at: Date
    let ended_at: Date?

    init(session: ClimbingSession) {
        self.id = session.id
        self.user_id = session.userId
        self.venue_name = session.venueName
        self.started_at = session.startedAt
        self.ended_at = session.endedAt
    }
}

private struct AttemptInsert: Encodable {
    let id: UUID
    let session_id: UUID
    let user_id: UUID
    let board_route_id: UUID?
    let route_name: String
    let discipline: String
    let grade_system: String
    let grade_label: String
    let outcome: String
    let attempt_number: Int
    let notes: String?
    let occurred_at: Date

    init(attempt: ClimbAttempt) {
        self.id = attempt.id
        self.session_id = attempt.sessionId
        self.user_id = attempt.userId
        self.board_route_id = attempt.boardRouteId
        self.route_name = attempt.routeName
        self.discipline = attempt.discipline.rawValue
        self.grade_system = attempt.gradeSystem.rawValue
        self.grade_label = attempt.gradeLabel
        self.outcome = attempt.outcome.rawValue
        self.attempt_number = attempt.attemptNumber
        self.notes = attempt.notes
        self.occurred_at = attempt.occurredAt
    }
}
#endif
