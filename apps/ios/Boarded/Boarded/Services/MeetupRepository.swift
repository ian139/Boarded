import Foundation

protocol MeetupRepository {
    func fetchMeetups(status: MeetupStatus?, area: String?) async throws -> [Meetup]
    func fetchMeetup(id: UUID) async throws -> Meetup
    func fetchAttendees(meetupID: UUID) async throws -> [MeetupAttendee]
    func fetchComments(meetupID: UUID) async throws -> [MeetupComment]
    func createMeetup(_ draft: MeetupDraft) async throws -> Meetup
    func updateMeetup(id: UUID, draft: MeetupDraft) async throws -> Meetup
    func cancelMeetup(id: UUID) async throws -> Meetup
    func joinMeetup(id: UUID) async throws -> MeetupAttendee
    func leaveMeetup(id: UUID) async throws
    func createComment(meetupID: UUID, content: String) async throws -> MeetupComment
}

struct MeetupDraft {
    let title: String
    let description: String
    let venueName: String
    let area: String
    let startsAt: Date
    let endsAt: Date?
    let capacity: Int?
}

enum MeetupRepositoryError: LocalizedError, Equatable {
    case unavailable
    case notFound
    case full
    case cancelled
    case past
    case organizerJoin
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Meetups are unavailable. Check your Supabase configuration."
        case .notFound: return "The meetup could not be found."
        case .full: return "This meetup is full."
        case .cancelled: return "Cancelled meetups cannot be joined."
        case .past: return "Past meetups cannot be joined."
        case .organizerJoin: return "Organizers cannot join their own meetup."
        case .unauthenticated: return "Sign in to join or create meetups."
        }
    }
}

/// Deterministic data source for previews and unit tests only. Production code
/// always uses SupabaseMeetupRepository and surfaces configuration/network errors.
///
/// The fixture enforces the same open-state semantics as the `join_meetup` RPC:
/// idempotent re-join, organizer exclusion, cancelled/past rejection, and
/// capacity (the organizer counts as one slot while attendee rows hold joiners).
final class MockMeetupRepository: MeetupRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var meetups: [Meetup]
    private var attendees: [MeetupAttendee]
    private var comments: [MeetupComment]

    /// Deterministic identity and clock used by the fixture.
    let currentUserID: UUID
    let now: Date

    init(
        meetups: [Meetup] = [],
        attendees: [MeetupAttendee] = [],
        comments: [MeetupComment] = [],
        currentUserID: UUID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
        now: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) {
        self.meetups = meetups
        self.attendees = attendees
        self.comments = comments
        self.currentUserID = currentUserID
        self.now = now
    }

    func fetchMeetups(status: MeetupStatus?, area: String?) async throws -> [Meetup] {
        lock.lock(); defer { lock.unlock() }
        return meetups.filter { meetup in
            (status == nil || meetup.status == status)
                && (area == nil || meetup.area == area)
        }
    }

    func fetchMeetup(id: UUID) async throws -> Meetup {
        lock.lock(); defer { lock.unlock() }
        guard let meetup = meetups.first(where: { $0.id == id }) else {
            throw MeetupRepositoryError.notFound
        }
        return meetup
    }

    func fetchAttendees(meetupID: UUID) async throws -> [MeetupAttendee] {
        lock.lock(); defer { lock.unlock() }
        return attendees.filter { $0.meetupId == meetupID }
    }

    func fetchComments(meetupID: UUID) async throws -> [MeetupComment] {
        lock.lock(); defer { lock.unlock() }
        return comments
            .filter { $0.meetupId == meetupID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func createMeetup(_ draft: MeetupDraft) async throws -> Meetup {
        lock.lock(); defer { lock.unlock() }
        let meetup = Meetup(
            id: UUID(),
            organizerId: currentUserID,
            title: draft.title,
            description: draft.description,
            venueName: draft.venueName,
            area: draft.area,
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            capacity: draft.capacity,
            status: .scheduled,
            createdAt: now,
            updatedAt: now
        )
        meetups.append(meetup)
        return meetup
    }

    func updateMeetup(id: UUID, draft: MeetupDraft) async throws -> Meetup {
        lock.lock(); defer { lock.unlock() }
        guard let index = meetups.firstIndex(where: { $0.id == id }) else { throw MeetupRepositoryError.notFound }
        let current = meetups[index]
        guard current.organizerId == currentUserID else { throw MeetupRepositoryError.unauthenticated }
        guard current.status == .scheduled else { throw MeetupRepositoryError.cancelled }
        let updated = Meetup(id: current.id, organizerId: current.organizerId, title: draft.title, description: draft.description, venueName: draft.venueName, area: draft.area, startsAt: draft.startsAt, endsAt: draft.endsAt, capacity: draft.capacity, status: current.status, createdAt: current.createdAt, updatedAt: now)
        meetups[index] = updated
        return updated
    }

    func cancelMeetup(id: UUID) async throws -> Meetup {
        lock.lock(); defer { lock.unlock() }
        guard let index = meetups.firstIndex(where: { $0.id == id }) else { throw MeetupRepositoryError.notFound }
        let current = meetups[index]
        guard current.organizerId == currentUserID else { throw MeetupRepositoryError.unauthenticated }
        let cancelled = Meetup(id: current.id, organizerId: current.organizerId, title: current.title, description: current.description, venueName: current.venueName, area: current.area, startsAt: current.startsAt, endsAt: current.endsAt, capacity: current.capacity, status: .cancelled, createdAt: current.createdAt, updatedAt: now)
        meetups[index] = cancelled
        return cancelled
    }

    func joinMeetup(id: UUID) async throws -> MeetupAttendee {
        lock.lock(); defer { lock.unlock() }
        guard let meetup = meetups.first(where: { $0.id == id }) else {
            throw MeetupRepositoryError.notFound
        }
        // Idempotent: an existing attendance row is returned unchanged.
        if let existing = attendees.first(where: { $0.meetupId == id && $0.userId == currentUserID }) {
            return existing
        }
        guard meetup.organizerId != currentUserID else {
            throw MeetupRepositoryError.organizerJoin
        }
        guard meetup.status == .scheduled else {
            throw MeetupRepositoryError.cancelled
        }
        let effectiveEnd = meetup.endsAt ?? meetup.startsAt
        guard effectiveEnd > now else {
            throw MeetupRepositoryError.past
        }
        let attendeeCount = attendees.filter { $0.meetupId == id }.count
        if let capacity = meetup.capacity, 1 + attendeeCount >= capacity {
            throw MeetupRepositoryError.full
        }
        let attendee = MeetupAttendee(meetupId: id, userId: currentUserID, joinedAt: now)
        attendees.append(attendee)
        return attendee
    }

    func leaveMeetup(id: UUID) async throws {
        lock.lock(); defer { lock.unlock() }
        attendees.removeAll { $0.meetupId == id && $0.userId == currentUserID }
    }

    func createComment(meetupID: UUID, content: String) async throws -> MeetupComment {
        lock.lock(); defer { lock.unlock() }
        let comment = MeetupComment(
            id: UUID(),
            meetupId: meetupID,
            userId: currentUserID,
            content: content,
            createdAt: now,
            updatedAt: now
        )
        comments.append(comment)
        return comment
    }
}

#if canImport(Supabase)
import Supabase

struct SupabaseMeetupRepository: MeetupRepository {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    @MainActor init() {
        self.init(client: SupabaseClientProvider.client)
    }

    func fetchMeetups(status: MeetupStatus?, area: String?) async throws -> [Meetup] {
        guard let client else { throw MeetupRepositoryError.unavailable }
        var query = client.from("meetups").select("*")
        if let status {
            query = query.eq("status", value: status.rawValue)
        }
        if let area {
            query = query.eq("area", value: area)
        }
        return try await query.order("starts_at", ascending: true).execute().value
    }

    func fetchMeetup(id: UUID) async throws -> Meetup {
        guard let client else { throw MeetupRepositoryError.unavailable }
        let rows: [Meetup] = try await client.from("meetups")
            .select("*")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { throw MeetupRepositoryError.notFound }
        return row
    }

    func fetchAttendees(meetupID: UUID) async throws -> [MeetupAttendee] {
        guard let client else { throw MeetupRepositoryError.unavailable }
        return try await client.from("meetup_attendees")
            .select("*")
            .eq("meetup_id", value: meetupID.uuidString)
            .execute()
            .value
    }

    func fetchComments(meetupID: UUID) async throws -> [MeetupComment] {
        guard let client else { throw MeetupRepositoryError.unavailable }
        return try await client.from("meetup_comments")
            .select("*")
            .eq("meetup_id", value: meetupID.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createMeetup(_ draft: MeetupDraft) async throws -> Meetup {
        guard let client else { throw MeetupRepositoryError.unavailable }
        let userID = try await client.auth.session.user.id
        let payload = MeetupInsert(
            organizer_id: userID,
            title: draft.title,
            description: draft.description,
            venue_name: draft.venueName,
            area: draft.area,
            starts_at: draft.startsAt,
            ends_at: draft.endsAt,
            capacity: draft.capacity
        )
        let rows: [Meetup] = try await client.from("meetups")
            .insert(payload)
            .select("*")
            .execute()
            .value
        guard let row = rows.first else { throw MeetupRepositoryError.notFound }
        return row
    }

    func updateMeetup(id: UUID, draft: MeetupDraft) async throws -> Meetup {
        guard let client else { throw MeetupRepositoryError.unavailable }
        let payload = MeetupUpdate(title: draft.title, description: draft.description, venue_name: draft.venueName, area: draft.area, starts_at: draft.startsAt, ends_at: draft.endsAt, capacity: draft.capacity)
        let rows: [Meetup] = try await client.from("meetups").update(payload).eq("id", value: id.uuidString).select("*").execute().value
        guard let row = rows.first else { throw MeetupRepositoryError.notFound }
        return row
    }

    func cancelMeetup(id: UUID) async throws -> Meetup {
        guard let client else { throw MeetupRepositoryError.unavailable }
        let rows: [Meetup] = try await client.from("meetups").update(MeetupStatusUpdate(status: .cancelled)).eq("id", value: id.uuidString).select("*").execute().value
        guard let row = rows.first else { throw MeetupRepositoryError.notFound }
        return row
    }

    func joinMeetup(id: UUID) async throws -> MeetupAttendee {
        guard let client else { throw MeetupRepositoryError.unavailable }
        let rows: [MeetupAttendee] = try await client.rpc("join_meetup", params: JoinMeetupParameters(meetup_id: id))
            .execute()
            .value
        guard let row = rows.first else { throw MeetupRepositoryError.notFound }
        return row
    }

    func leaveMeetup(id: UUID) async throws {
        guard let client else { throw MeetupRepositoryError.unavailable }
        let userID = try await client.auth.session.user.id
        _ = try await client.from("meetup_attendees")
            .delete()
            .eq("meetup_id", value: id.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
    }

    func createComment(meetupID: UUID, content: String) async throws -> MeetupComment {
        guard let client else { throw MeetupRepositoryError.unavailable }
        let userID = try await client.auth.session.user.id
        let payload = MeetupCommentInsert(meetup_id: meetupID, user_id: userID, content: content)
        let rows: [MeetupComment] = try await client.from("meetup_comments")
            .insert(payload)
            .select("*")
            .execute()
            .value
        guard let row = rows.first else { throw MeetupRepositoryError.notFound }
        return row
    }
}

private struct MeetupInsert: Encodable {
    let organizer_id: UUID
    let title: String
    let description: String
    let venue_name: String
    let area: String
    let starts_at: Date
    let ends_at: Date?
    let capacity: Int?
}

private struct MeetupUpdate: Encodable {
    let title: String
    let description: String
    let venue_name: String
    let area: String
    let starts_at: Date
    let ends_at: Date?
    let capacity: Int?
}

private struct MeetupStatusUpdate: Encodable {
    let status: MeetupStatus
}

private nonisolated struct JoinMeetupParameters: Encodable, Sendable {
    let meetup_id: UUID
}

private struct MeetupCommentInsert: Encodable {
    let meetup_id: UUID
    let user_id: UUID
    let content: String
}
#endif
