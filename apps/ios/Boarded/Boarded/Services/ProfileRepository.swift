import Foundation

protocol ProfileRepository {
    func fetchProfile(userID: UUID) async throws -> Profile?
    func fetchStatistics(userID: UUID) async throws -> ProfileStatistics
    func createProfile(_ draft: ProfileDraft) async throws -> Profile
    func updateProfile(userID: UUID, update: ProfileUpdate) async throws -> Profile
}

enum ProfileRepositoryError: LocalizedError, Equatable {
    case unavailable
    case invalidUserID
    case invalidUsername
    case alreadyExists

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Profile data is unavailable. Check your Supabase configuration."
        case .invalidUserID: return "The selected account is invalid."
        case .invalidUsername: return "Choose a username before creating your profile."
        case .alreadyExists: return "A profile already exists for this account."
        }
    }
}
private extension ProfileDraft {
    var sanitized: ProfileDraft {
        ProfileDraft(
            id: id,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
            homeArea: homeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}



/// Deterministic data source for previews and unit tests only. Production code
/// always uses SupabaseProfileRepository and surfaces configuration/network errors.
final class MockProfileRepository: ProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var profile: Profile?
    private let statistics: ProfileStatistics

    init(profile: Profile? = nil, statistics: ProfileStatistics = .empty) {
        self.profile = profile
        self.statistics = statistics
    }
    func createProfile(_ draft: ProfileDraft) async throws -> Profile {
        let draft = draft.sanitized
        guard !draft.username.isEmpty else {
            throw ProfileRepositoryError.invalidUsername
        }

        lock.lock()
        defer { lock.unlock() }
        guard profile == nil else { throw ProfileRepositoryError.alreadyExists }

        let created = Profile(
            id: draft.id,
            username: draft.username,
            fullName: draft.displayName?.isEmpty == true ? nil : draft.displayName,
            avatarUrl: nil,
            bio: nil,
            homeArea: draft.homeArea?.isEmpty == true ? nil : draft.homeArea,
            createdAt: Date()
        )
        profile = created
        return created
    }


    func fetchProfile(userID: UUID) async throws -> Profile? {
        lock.lock(); defer { lock.unlock() }
        return profile
    }

    func fetchStatistics(userID: UUID) async throws -> ProfileStatistics {
        lock.lock(); defer { lock.unlock() }
        return statistics
    }

    func updateProfile(userID: UUID, update: ProfileUpdate) async throws -> Profile {
        lock.lock(); defer { lock.unlock() }
        guard let current = profile else { throw ProfileRepositoryError.invalidUserID }
        let updated = Profile(
            id: current.id,
            username: update.username,
            fullName: update.fullName,
            avatarUrl: current.avatarUrl,
            bio: update.bio,
            homeArea: update.homeArea,
            createdAt: current.createdAt
        )
        profile = updated
        return updated
    }
}

#if canImport(Supabase)
import Supabase

struct SupabaseProfileRepository: ProfileRepository {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    @MainActor init() {
        self.init(client: SupabaseClientProvider.client)
    }

    func fetchProfile(userID: UUID) async throws -> Profile? {
        guard let client else { throw ProfileRepositoryError.unavailable }
        let profiles: [Profile] = try await client.from("profiles")
            .select("id,username,full_name,avatar_url,bio,home_area,created_at")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        return profiles.first
    }

    func createProfile(_ draft: ProfileDraft) async throws -> Profile {
        guard let client else { throw ProfileRepositoryError.unavailable }
        let draft = draft.sanitized
        guard !draft.username.isEmpty else {
            throw ProfileRepositoryError.invalidUsername
        }
        let rows: [Profile] = try await client.from("profiles")
            .insert(draft)
            .select("*")
            .execute()
            .value
        guard let row = rows.first else { throw ProfileRepositoryError.invalidUserID }
        return row
    }


    func fetchStatistics(userID: UUID) async throws -> ProfileStatistics {
        guard let client else { throw ProfileRepositoryError.unavailable }
        async let sessions: [ClimbingSession] = client.from("climbing_sessions")
            .select("*")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        async let attempts: [ClimbAttempt] = client.from("climb_attempts")
            .select("*")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        let (fetchedSessions, fetchedAttempts) = try await (sessions, attempts)
        return ProfileStatisticsCalculator.calculate(sessions: fetchedSessions, attempts: fetchedAttempts)
    }

    func updateProfile(userID: UUID, update: ProfileUpdate) async throws -> Profile {
        guard let client else { throw ProfileRepositoryError.unavailable }
        let rows: [Profile] = try await client.from("profiles")
            .update(update)
            .eq("id", value: userID.uuidString)
            .select("*")
            .execute()
            .value
        guard let row = rows.first else { throw ProfileRepositoryError.invalidUserID }
        return row
    }
}
#endif
