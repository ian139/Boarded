import Foundation
import Combine
import Supabase

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var userId: UUID? = nil
    @Published private(set) var userEmail: String? = nil
    @Published private(set) var profile: Profile? = nil
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil

    private let profileRepository: any ProfileRepository
    private let fixture: Bool

    init(profileRepository: any ProfileRepository, fixture: Bool = false) {
        self.profileRepository = profileRepository
        self.fixture = fixture
    }

    @MainActor convenience init(fixture: Bool = false) {
        self.init(profileRepository: AppServices.profileRepository, fixture: fixture)
    }

    var displayName: String {
        profile?.fullName
        ?? profile?.username
        ?? userEmail
        ?? "Climber"
    }

    /// True when a signed-in user has no profile row yet (legacy auth accounts
    /// created before profile provisioning). Gates profile-dependent UI.
    var needsProfileSetup: Bool {
        userId != nil && profile == nil
    }

    private var sessionGeneration = 0

    func load() async {
        #if DEBUG
        if fixture {
            userId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")
            userEmail = "fixture@boarded.test"
            profile = Profile(
                id: userId!,
                username: "fixture",
                fullName: "Fixture Climber",
                avatarUrl: nil,
                bio: "Building a climbing journal, one line at a time.",
                homeArea: nil,
                createdAt: parseISO8601Date("2026-01-01T00:00:00Z")
            )
            isLoading = false
            return
        }
        #endif
        sessionGeneration += 1
        let generation = sessionGeneration
        guard let client = SupabaseClientProvider.client else {
            userId = nil
            userEmail = nil
            profile = nil
            errorMessage = SupabaseConfigError.unconfigured.localizedDescription
            return
        }
        isLoading = true
        defer {
            if generation == sessionGeneration {
                isLoading = false
            }
        }
        do {
            let session = try await client.auth.session
            guard generation == sessionGeneration else { return }
            userId = session.user.id
            userEmail = session.user.email
            await fetchProfile(userId: session.user.id, generation: generation)
        } catch {
            guard generation == sessionGeneration else { return }
            userId = nil
            userEmail = nil
            profile = nil
        }
    }

    func signIn(email: String, password: String) async {
        #if DEBUG
        if fixture {
            await load()
            return
        }
        #endif
        guard let client = SupabaseClientProvider.client else {
            errorMessage = SupabaseConfigError.unconfigured.localizedDescription
            return
        }
        sessionGeneration += 1
        let generation = sessionGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == sessionGeneration {
                isLoading = false
            }
        }
        do {
            _ = try await client.auth.signIn(email: email, password: password)
            guard generation == sessionGeneration else { return }
            await load()
        } catch {
            guard generation == sessionGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Creates the auth account, then provisions the profile row with the
    /// requested username/display name. Profile creation is a separate step so
    /// a profile failure never leaves a half-provisioned account.
    func signUp(email: String, password: String, username: String, displayName: String) async {
        #if DEBUG
        if fixture {
            await load()
            return
        }
        #endif
        guard let client = SupabaseClientProvider.client else {
            errorMessage = SupabaseConfigError.unconfigured.localizedDescription
            return
        }
        sessionGeneration += 1
        let generation = sessionGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == sessionGeneration {
                isLoading = false
            }
        }
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            guard generation == sessionGeneration else { return }
            let session = try await client.auth.session
            guard generation == sessionGeneration else { return }
            userId = session.user.id
            userEmail = session.user.email
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let update = ProfileUpdate(
                fullName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
                username: trimmedUsername.isEmpty ? nil : trimmedUsername,
                bio: nil,
                homeArea: nil
            )
            profile = try await profileRepository.updateProfile(userID: session.user.id, update: update)
        } catch {
            guard generation == sessionGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        #if DEBUG
        if fixture {
            sessionGeneration += 1
            userId = nil
            userEmail = nil
            profile = nil
            errorMessage = nil
            isLoading = false
            return
        }
        #endif
        guard let client = SupabaseClientProvider.client else {
            errorMessage = SupabaseConfigError.unconfigured.localizedDescription
            return
        }
        sessionGeneration += 1
        let generation = sessionGeneration
        userId = nil
        userEmail = nil
        profile = nil
        isLoading = true
        defer {
            if generation == sessionGeneration {
                isLoading = false
            }
        }
        do {
            try await client.auth.signOut()
        } catch {
            guard generation == sessionGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func fetchProfile(userId: UUID, generation: Int? = nil) async {
        do {
            let fetched = try await profileRepository.fetchProfile(userID: userId)
            guard generation == nil || generation == sessionGeneration,
                  self.userId == userId else {
                return
            }
            profile = fetched
        } catch {
            guard generation == nil || generation == sessionGeneration,
                  self.userId == userId else {
                return
            }
            profile = nil
        }
    }

    func updateProfile(fullName: String?, username: String?, bio: String?, homeArea: String?) async throws {
        #if DEBUG
        if fixture {
            guard let userId else {
                let error = ProfileRepositoryError.invalidUserID
                errorMessage = error.localizedDescription
                throw error
            }
            profile = Profile(
                id: userId,
                username: username?.trimmingCharacters(in: .whitespacesAndNewlines),
                fullName: fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarUrl: profile?.avatarUrl,
                bio: bio?.trimmingCharacters(in: .whitespacesAndNewlines),
                homeArea: homeArea?.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: profile?.createdAt
            )
            errorMessage = nil
            return
        }
        #endif
        guard let userId else {
            let error = ProfileRepositoryError.invalidUserID
            errorMessage = error.localizedDescription
            throw error
        }

        sessionGeneration += 1
        let generation = sessionGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == sessionGeneration {
                isLoading = false
            }
        }

        let update = ProfileUpdate(
            fullName: fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username?.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio?.trimmingCharacters(in: .whitespacesAndNewlines),
            homeArea: homeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let updated = try await profileRepository.updateProfile(userID: userId, update: update)
            try Task.checkCancellation()
            guard generation == sessionGeneration, self.userId == userId else {
                throw CancellationError()
            }
            profile = updated
        } catch {
            if generation == sessionGeneration, !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }
}
