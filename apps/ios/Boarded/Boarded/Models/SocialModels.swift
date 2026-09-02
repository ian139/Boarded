import Foundation

// MARK: - Shared enums

enum AttemptOutcome: String, Codable, CaseIterable, Sendable {
    case sent
    case fell
    case stopped
}

enum SyncState: String, Codable, CaseIterable, Sendable {
    case queued
    case syncing
    case failed
    case synced
}

enum MeetupStatus: String, Codable, CaseIterable, Sendable {
    case scheduled
    case cancelled
}

enum OverlayStyle: String, Codable, CaseIterable, Sendable {
    case stats
    case attemptTimeline = "attempt_timeline"
}

// MARK: - Sessions and attempts

struct ClimbingSession: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let venueName: String
    let startedAt: Date
    let endedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case venueName = "venue_name"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ClimbAttempt: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let sessionId: UUID
    let userId: UUID
    let boardRouteId: UUID?
    let routeName: String
    let discipline: ClimbDiscipline
    let gradeSystem: GradeSystem
    let gradeLabel: String
    let outcome: AttemptOutcome
    let attemptNumber: Int
    let notes: String?
    let occurredAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case boardRouteId = "board_route_id"
        case routeName = "route_name"
        case discipline
        case gradeSystem = "grade_system"
        case gradeLabel = "grade_label"
        case outcome
        case attemptNumber = "attempt_number"
        case notes
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
    }
}

// MARK: - Session posts

struct SessionPost: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let sessionId: UUID
    let featuredAttemptId: UUID
    let caption: String?
    let imagePath: String
    let imageAlt: String
    let overlayStyle: OverlayStyle
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case featuredAttemptId = "featured_attempt_id"
        case caption
        case imagePath = "image_path"
        case imageAlt = "image_alt"
        case overlayStyle = "overlay_style"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SessionPostLike: Codable, Hashable, Sendable {
    let postId: UUID
    let userId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct SessionPostComment: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let content: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Meetups

struct Meetup: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let organizerId: UUID
    let title: String
    let description: String
    let venueName: String
    let area: String
    let startsAt: Date
    let endsAt: Date?
    let capacity: Int?
    let status: MeetupStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case organizerId = "organizer_id"
        case title
        case description
        case venueName = "venue_name"
        case area
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case capacity
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MeetupAttendee: Codable, Hashable, Sendable {
    let meetupId: UUID
    let userId: UUID
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case meetupId = "meetup_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

struct MeetupComment: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let meetupId: UUID
    let userId: UUID
    let content: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case meetupId = "meetup_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Feed

struct FeedAuthor: Codable, Hashable, Sendable {
    let id: UUID
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let bio: String?
    let homeArea: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case bio
        case homeArea = "home_area"
    }
}

struct FeedFeaturedAttempt: Codable, Hashable, Sendable {
    let id: UUID
    let routeName: String
    let discipline: ClimbDiscipline
    let gradeSystem: GradeSystem
    let gradeLabel: String
    let outcome: AttemptOutcome
    let attemptNumber: Int
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case routeName = "route_name"
        case discipline
        case gradeSystem = "grade_system"
        case gradeLabel = "grade_label"
        case outcome
        case attemptNumber = "attempt_number"
        case occurredAt = "occurred_at"
    }
}

struct FeedAttemptTimelineItem: Codable, Hashable, Sendable {
    let attemptNumber: Int
    let outcome: AttemptOutcome

    enum CodingKeys: String, CodingKey {
        case attemptNumber = "attempt_number"
        case outcome
    }
}

struct FeedSessionSummary: Codable, Hashable, Sendable {
    let id: UUID
    let venueName: String
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let attemptCount: Int
    let sendCount: Int
    let featuredAttempt: FeedFeaturedAttempt
    let attemptTimeline: [FeedAttemptTimelineItem]?

    init(
        id: UUID,
        venueName: String,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        attemptCount: Int,
        sendCount: Int,
        featuredAttempt: FeedFeaturedAttempt,
        attemptTimeline: [FeedAttemptTimelineItem]? = nil
    ) {
        self.id = id
        self.venueName = venueName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.attemptCount = attemptCount
        self.sendCount = sendCount
        self.featuredAttempt = featuredAttempt
        self.attemptTimeline = attemptTimeline
    }

    enum CodingKeys: String, CodingKey {
        case id
        case venueName = "venue_name"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case attemptCount = "attempt_count"
        case sendCount = "send_count"
        case featuredAttempt = "featured_attempt"
        case attemptTimeline = "attempt_timeline"
    }
}

struct SessionFeedItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let sessionId: UUID
    let featuredAttemptId: UUID
    let caption: String?
    let imagePath: String
    let imageAlt: String
    let overlayStyle: OverlayStyle
    let createdAt: Date
    let updatedAt: Date
    let author: FeedAuthor
    let session: FeedSessionSummary
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case featuredAttemptId = "featured_attempt_id"
        case caption
        case imagePath = "image_path"
        case imageAlt = "image_alt"
        case overlayStyle = "overlay_style"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case author
        case session
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isLiked = "is_liked"
    }

    /// Deterministic sibling for the canonical flattened image object.
    /// Feed payloads always use `<user>/<post>.jpg`; no legacy location is
    /// consulted when deriving the source asset.
    var sourceImagePath: String {
        String(imagePath.dropLast(".jpg".count)) + ".source.jpg"
    }
}

struct FeedCursor: Codable, Hashable, Sendable {
    let createdAt: Date
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case id
    }
}

struct FeedPage: Sendable {
    let items: [SessionFeedItem]
    let nextCursor: FeedCursor?
    let hasMore: Bool
}

// MARK: - Date helpers

private let fractionalISO8601Style = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: TimeZone(secondsFromGMT: 0)!)
private let standardISO8601Style = Date.ISO8601FormatStyle(timeZone: TimeZone(secondsFromGMT: 0)!)

func parseISO8601Date(_ value: String?) -> Date? {
    guard let value else { return nil }
    if let date = try? fractionalISO8601Style.parse(value) {
        return date
    }
    return try? standardISO8601Style.parse(value)
}

func iso8601Timestamp(_ date: Date = Date()) -> String {
    date.formatted(fractionalISO8601Style)
}

extension JSONDecoder {
    /// Decoder matching the PostgREST wire format: ISO8601 timestamps with an
    /// optional fractional-second component.
    static func boarded() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = parseISO8601Date(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected ISO8601 date, got \(string)"
                )
            }
            return date
        }
        return decoder
    }
}
