import Foundation

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let bio: String?
    let homeArea: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case bio
        case homeArea = "home_area"
        case createdAt = "created_at"
    }

    var displayName: String {
        if let fullName, !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }
        if let username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }
        return "Anonymous"
    }
}
struct ProfileDraft: Encodable {
    let id: UUID
    let username: String
    let displayName: String?
    let homeArea: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "full_name"
        case homeArea = "home_area"
    }
}



struct ProfileUpdate: Encodable {
    let fullName: String?
    let username: String?
    let bio: String?
    let homeArea: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case username
        case bio
        case homeArea = "home_area"
    }
}
