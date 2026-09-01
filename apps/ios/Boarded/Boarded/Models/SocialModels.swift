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

// MARK: - Sessions and attempts

struct ClimbingSession: Codable, Identifiable, Hashable {
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

struct ClimbAttempt: Codable, Identifiable, Hashable {
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
    /// Only `sent` attempts may back a public send post (mirrors the
    /// `ensure_send_post_attempt_is_sent` trigger).
    var isSendEligible: Bool { outcome == .sent }

}

// MARK: - Send posts

struct SendPost: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let attemptId: UUID
    let caption: String?
    let imagePath: String?
    let imageAlt: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case attemptId = "attempt_id"
        case caption
        case imagePath = "image_path"
        case imageAlt = "image_alt"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SendPostLike: Codable, Hashable {
    let postId: UUID
    let userId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct SendPostComment: Codable, Identifiable, Hashable {
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

struct Meetup: Codable, Identifiable, Hashable {
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

struct MeetupAttendee: Codable, Hashable {
    let meetupId: UUID
    let userId: UUID
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case meetupId = "meetup_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

struct MeetupComment: Codable, Identifiable, Hashable {
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

struct FeedAuthor: Codable, Hashable {
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

struct FeedAttempt: Codable, Hashable {
    let id: UUID
    let boardRouteId: UUID?
    let routeName: String
    let discipline: ClimbDiscipline
    let gradeSystem: GradeSystem
    let gradeLabel: String
    let outcome: AttemptOutcome
    let attemptNumber: Int
    let occurredAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case boardRouteId = "board_route_id"
        case routeName = "route_name"
        case discipline
        case gradeSystem = "grade_system"
        case gradeLabel = "grade_label"
        case outcome
        case attemptNumber = "attempt_number"
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
    }
}

struct SendFeedItem: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let attemptId: UUID
    let caption: String?
    let imagePath: String?
    let imageAlt: String?
    let createdAt: Date
    let updatedAt: Date
    let author: FeedAuthor
    let attempt: FeedAttempt
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case attemptId = "attempt_id"
        case caption
        case imagePath = "image_path"
        case imageAlt = "image_alt"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case author
        case attempt
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isLiked = "is_liked"
    }
}

struct FeedCursor: Codable, Hashable {
    let createdAt: Date
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case id
    }
}

struct FeedPage {
    let items: [SendFeedItem]
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
