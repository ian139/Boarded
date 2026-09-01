import Foundation

struct Hold: Codable, Identifiable, Hashable {
    let id: String
    var x: Double
    var y: Double
    var type: HoldType
    var color: String
    var size: HoldSize
    /// An optional image-space radius. Older routes only have a discrete `size`.
    /// Keeping this optional preserves decoding and rendering for existing JSON.
    var radius: Double?
    let notes: String?

    init(
        id: String,
        x: Double,
        y: Double,
        type: HoldType,
        color: String,
        size: HoldSize,
        radius: Double? = nil,
        notes: String?
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.type = type
        self.color = color
        self.size = size
        self.radius = radius
        self.notes = notes
    }
}

enum HoldType: String, Codable, CaseIterable {
    case start
    case hand
    case foot
    case finish
}

enum HoldSize: String, Codable, CaseIterable {
    case small
    case medium
    case large
}
struct VGradeOption: Identifiable, Hashable {
    let value: Int
    let label: String

    var id: Int { value }

    static let all: [VGradeOption] = [
        VGradeOption(value: -1, label: "VB"),
        VGradeOption(value: 0, label: "V0"),
        VGradeOption(value: 1, label: "V1"),
        VGradeOption(value: 2, label: "V2"),
        VGradeOption(value: 3, label: "V3"),
        VGradeOption(value: 4, label: "V4"),
        VGradeOption(value: 5, label: "V5"),
        VGradeOption(value: 6, label: "V6"),
        VGradeOption(value: 7, label: "V7"),
        VGradeOption(value: 8, label: "V8"),
        VGradeOption(value: 9, label: "V9"),
        VGradeOption(value: 10, label: "V10"),
        VGradeOption(value: 11, label: "V11"),
        VGradeOption(value: 12, label: "V12"),
        VGradeOption(value: 13, label: "V13"),
        VGradeOption(value: 14, label: "V14"),
        VGradeOption(value: 15, label: "V15"),
        VGradeOption(value: 16, label: "V16"),
        VGradeOption(value: 17, label: "V17")
    ]

    nonisolated static func label(for value: Int?) -> String? {
        guard let value else { return nil }
        if value == -1 { return "VB" }
        return (0...17).contains(value) ? "V\(value)" : nil
    }

    static func value(for label: String?) -> Int? {
        guard let label else { return nil }
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return all.first { $0.label.caseInsensitiveCompare(normalized) == .orderedSame }?.value
    }
}



struct Route: Codable, Identifiable, Hashable {
    let id: String
    let userId: String?
    let wallId: String
    let name: String
    let description: String?
    let gradeV: String?
    let gradeFont: String?
    let holds: [Hold]
    let isPublic: Bool
    let viewCount: Int
    let shareToken: String?
    let createdAt: String
    let updatedAt: String
    let userName: String?
    var wallImageUrl: String?
    var wallImageWidth: Int?
    var wallImageHeight: Int?
    var likeCount: Int?
    var isLiked: Bool?
    var ascents: [Ascent]
    let comments: [Comment]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case wallId = "wall_id"
        case name
        case description
        case gradeV = "grade_v"
        case gradeFont = "grade_font"
        case holds
        case isPublic = "is_public"
        case viewCount = "view_count"
        case shareToken = "share_token"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userName = "user_name"
        case wallImageUrl = "wall_image_url"
        case wallImageWidth = "wall_image_width"
        case wallImageHeight = "wall_image_height"
        case likeCount = "like_count"
        case isLiked = "is_liked"
        case ascents
        case comments
    }
}

struct Wall: Codable, Identifiable, Hashable {
    let id: String
    let userId: String?
    let name: String
    let description: String?
    let imageUrl: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let isPublic: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case imageUrl = "image_url"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Ascent: Codable, Identifiable, Hashable {
    let id: String
    let routeId: String
    let userId: String?
    let userName: String?
    let gradeV: String?
    let rating: Int?
    let notes: String?
    let flashed: Bool?
    let createdAt: String?
    init(
        id: String,
        routeId: String,
        userId: String? = nil,
        userName: String? = nil,
        gradeV: String? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        flashed: Bool? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.routeId = routeId
        self.userId = userId
        self.userName = userName
        self.gradeV = gradeV
        self.rating = rating
        self.notes = notes
        self.flashed = flashed
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case routeId = "route_id"
        case userId = "user_id"
        case userName = "user_name"
        case gradeV = "grade_v"
        case rating
        case notes
        case flashed
        case createdAt = "created_at"
    }
}
struct AscentInsert: Encodable {
    let id: String
    let routeId: String
    let userId: String?
    let userName: String
    let gradeV: String?
    let rating: Int?
    let notes: String?
    let flashed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case routeId = "route_id"
        case userId = "user_id"
        case userName = "user_name"
        case gradeV = "grade_v"
        case rating
        case notes
        case flashed
    }
}

struct Comment: Codable, Identifiable, Hashable {
    let id: String
    let routeId: String
    let userId: String?
    let userName: String?
    let content: String
    let isBeta: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case routeId = "route_id"
        case userId = "user_id"
        case userName = "user_name"
        case content
        case isBeta = "is_beta"
        case createdAt = "created_at"
    }
}

private func normalizedHoldCoordinate(_ value: Double) -> Double {
    value > 1 ? value / 100.0 : value
}

extension Hold {
    var normalizedX: Double {
        normalizedHoldCoordinate(x)
    }

    var normalizedY: Double {
        normalizedHoldCoordinate(y)
    }
}

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

func normalizedRemoteImageURLString(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else { return nil }
    return trimmed
}

extension Route {
    var normalizedWallImageUrl: String? {
        normalizedRemoteImageURLString(wallImageUrl)
    }

    var wallImageURL: URL? {
        guard let normalizedWallImageUrl else { return nil }
        return URL(string: normalizedWallImageUrl)
    }
}

extension Wall {
    var normalizedImageUrl: String? {
        normalizedRemoteImageURLString(imageUrl)
    }

}

extension HoldType {
    var shortLabel: String {
        switch self {
        case .start: return "S"
        case .hand: return "H"
        case .foot: return "F"
        case .finish: return "T"
        }
    }

    var colorHex: String {
        switch self {
        case .start: return "#00E599"
        case .hand: return "#FF5C00"
        case .foot: return "#FFFFFF"
        case .finish: return "#FF5C00"
        }
    }
}
