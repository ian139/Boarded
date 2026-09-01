import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var selectedUserID: UUID?
    @Published private(set) var points: Int?
    @Published private(set) var routesCount = 0
    @Published private(set) var sendsCount = 0
    @Published private(set) var likesCount = 0
    @Published private(set) var flashedCount = 0
    @Published private(set) var highestGrade: String?
    @Published private(set) var leaderboard: [ProfileLeaderboardEntry] = []
    @Published private(set) var previousClimbs: [ProfileClimbHistoryItem] = []
    @Published private(set) var highlights = ProfileHighlights(bestClimb: nil, longestProject: nil)
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var followCounts = ProfileFollowCounts(followerCount: 0, followingCount: 0)
    @Published private(set) var isFollowing = false
    @Published private(set) var isUpdatingFollow = false
    @Published private(set) var followErrorMessage: String?
    @Published private(set) var followCountsRefreshErrorMessage: String?

    var hasLoadedSelectedProfile: Bool {
        !isLoading && errorMessage == nil && profile != nil
    }

    private let repository: any ProfileRepository
    private var generation = 0
    private var currentUserID: UUID?

    init(repository: any ProfileRepository) {
        self.repository = repository
    }

    @MainActor convenience init() {
        self.init(repository: SupabaseProfileRepository())
    }

    func load(userID: UUID?) async {
        generation += 1
        let request = generation
        selectedUserID = userID
        clearProfileContent()
        isLoading = userID != nil
        errorMessage = nil
        guard let userID else { return }
        defer {
            if request == generation {
                isLoading = false
            }
        }
        do {
            async let fetchedProfile = repository.fetchProfile(userID: userID)
            async let fetchedLeaderboard = repository.fetchLeaderboard()
            async let fetchedHistory = repository.fetchClimbHistory(userID: userID)
            async let fetchedMetrics = repository.fetchMetrics(userID: userID)
            async let fetchedCounts = repository.fetchFollowCounts(profileID: userID)
            let (newProfile, newLeaderboard, newHistory, newMetrics, newCounts) = try await (fetchedProfile, fetchedLeaderboard, fetchedHistory, fetchedMetrics, fetchedCounts)
            try Task.checkCancellation()
            guard request == generation else { return }
            let newIsFollowing: Bool
            if let currentUserID, currentUserID != userID {
                newIsFollowing = try await repository.isFollowing(profileID: userID, followerID: currentUserID)
                try Task.checkCancellation()
                guard request == generation else { return }
            } else {
                newIsFollowing = false
            }
            profile = newProfile
            leaderboard = newLeaderboard
            routesCount = newMetrics.routesCount
            likesCount = newMetrics.likesCount
            followCounts = newCounts
            isFollowing = newIsFollowing
            applyHistory(newHistory, userID: userID, request: request)
        } catch is CancellationError {
            return
        } catch {
            guard request == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func selectAccount(userID: UUID) async {
        generation += 1
        let request = generation
        selectedUserID = userID
        clearProfileContent(preservingLeaderboard: true)
        isLoading = true
        errorMessage = nil
        defer {
            if request == generation {
                isLoading = false
            }
        }
        do {
            async let fetchedProfile = repository.fetchProfile(userID: userID)
            async let fetchedHistory = repository.fetchClimbHistory(userID: userID)
            async let fetchedMetrics = repository.fetchMetrics(userID: userID)
            async let fetchedCounts = repository.fetchFollowCounts(profileID: userID)
            let (newProfile, newHistory, newMetrics, newCounts) = try await (fetchedProfile, fetchedHistory, fetchedMetrics, fetchedCounts)
            try Task.checkCancellation()
            guard request == generation else { return }
            let newIsFollowing: Bool
            if let currentUserID, currentUserID != userID {
                newIsFollowing = try await repository.isFollowing(profileID: userID, followerID: currentUserID)
                try Task.checkCancellation()
                guard request == generation else { return }
            } else {
                newIsFollowing = false
            }
            profile = newProfile
            routesCount = newMetrics.routesCount
            likesCount = newMetrics.likesCount
            followCounts = newCounts
            isFollowing = newIsFollowing
            applyHistory(newHistory, userID: userID, request: request)
        } catch is CancellationError {
            return
        } catch {
            guard request == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func retry() async { await load(userID: selectedUserID) }
    func refreshCurrentProfile() async {
        guard let selectedUserID else { return }
        await load(userID: selectedUserID)
    }

    func myProfile(currentUserID: UUID?) async {
        guard let currentUserID else { return }
        await selectAccount(userID: currentUserID)
    }

    func syncProfileFromSession(currentUserID: UUID?, profile: Profile?) {
        guard let currentUserID, selectedUserID == currentUserID, let profile else { return }
        self.profile = profile
    }

    func setCurrentUserID(_ userID: UUID?) {
        currentUserID = userID
    }

    func setFollowing(_ shouldFollow: Bool, currentUserID: UUID) async {
        guard hasLoadedSelectedProfile,
              let profileID = selectedUserID,
              profileID != currentUserID,
              !isUpdatingFollow else { return }
        let request = generation
        let previous = isFollowing
        let previousCounts = followCounts
        isUpdatingFollow = true
        followErrorMessage = nil
        followCountsRefreshErrorMessage = nil
        isFollowing = shouldFollow
        followCounts = ProfileFollowCounts(
            followerCount: max(0, previousCounts.followerCount + (shouldFollow ? 1 : -1)),
            followingCount: previousCounts.followingCount
        )
        do {
            if shouldFollow {
                try await repository.follow(profileID: profileID, followerID: currentUserID)
            } else {
                try await repository.unfollow(profileID: profileID, followerID: currentUserID)
            }
        } catch {
            guard request == generation, selectedUserID == profileID else { return }
            isFollowing = previous
            followCounts = previousCounts
            followErrorMessage = error.localizedDescription
            isUpdatingFollow = false
            return
        }
        guard request == generation, selectedUserID == profileID else { return }
        isUpdatingFollow = false
        await refreshFollowCounts(profileID: profileID, request: request)
    }

    func retryFollowCounts() async {
        guard hasLoadedSelectedProfile, let profileID = selectedUserID else { return }
        await refreshFollowCounts(profileID: profileID, request: generation)
    }

    private func refreshFollowCounts(profileID: UUID, request: Int) async {
        followCountsRefreshErrorMessage = nil
        do {
            let counts = try await repository.fetchFollowCounts(profileID: profileID)
            guard request == generation, selectedUserID == profileID else { return }
            followCounts = counts
        } catch {
            guard request == generation, selectedUserID == profileID else { return }
            followCountsRefreshErrorMessage = error.localizedDescription
        }
    }


    private func applyHistory(_ history: [ProfileClimbHistoryItem], userID: UUID, request: Int) {
        guard request == generation else { return }
        previousClimbs = history.sorted {
            let lhs = $0.completedAt ?? .distantPast
            let rhs = $1.completedAt ?? .distantPast
            return lhs == rhs ? $0.id < $1.id : lhs > rhs
        }
        let records = previousClimbs.map { climb in
            ProfileScoringRecord(
                id: climb.id,
                userId: userID.uuidString,
                routeId: climb.routeId,
                routeName: climb.routeName,
                routeGrade: climb.route?.gradeV,
                ascentGrade: climb.grade,
                flashed: climb.flashed,
                completedAt: climb.completedAt,
                route: climb.route
            )
        }
        let calculated = ProfileStatistics.calculate(records: records, selectedUserID: userID.uuidString)
        points = leaderboard.first(where: { $0.id == userID.uuidString })?.points ?? calculated.points
        sendsCount = calculated.sendsCount
        flashedCount = calculated.flashedCount
        highestGrade = calculated.highestGrade
        highlights = calculated.highlights
        isLoading = false
    }
    private func clearProfileContent(preservingLeaderboard: Bool = false) {
        profile = nil
        points = nil
        routesCount = 0
        sendsCount = 0
        likesCount = 0
        flashedCount = 0
        highestGrade = nil
        if !preservingLeaderboard {
            leaderboard = []
        }
        previousClimbs = []
        highlights = ProfileHighlights(bestClimb: nil, longestProject: nil)
        followCounts = ProfileFollowCounts(followerCount: 0, followingCount: 0)
        isFollowing = false
        isUpdatingFollow = false
        followErrorMessage = nil
        followCountsRefreshErrorMessage = nil
    }
}

@MainActor
final class FollowingFeedViewModel: ObservableObject {
    @Published private(set) var items: [FollowingFeedItem] = []
    @Published private(set) var routesByID: [UUID: Route] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var paginationErrorMessage: String?

    private let profileRepository: any ProfileRepository
    private let routesRepository: any RoutesRepository
    private let pageSize: Int
    private var generation = 0
    private var loadedUserID: UUID?

    init(profileRepository: any ProfileRepository, routesRepository: any RoutesRepository, pageSize: Int = 20) {
        self.profileRepository = profileRepository
        self.routesRepository = routesRepository
        self.pageSize = pageSize
    }

    func load(userID: UUID?) async {
        generation += 1
        let request = generation
        loadedUserID = userID
        items = []
        routesByID = [:]
        canLoadMore = userID != nil
        errorMessage = nil
        paginationErrorMessage = nil
        guard let userID else {
            isLoading = false
            isLoadingMore = false
            return
        }
        isLoading = true
        defer {
            if request == generation { isLoading = false }
        }
        do {
            let page = try await profileRepository.fetchFollowingFeed(cursor: nil, limit: pageSize)
            try Task.checkCancellation()
            guard request == generation, loadedUserID == userID else { return }
            let routes = try await enrichedRoutes(for: page, userID: userID)
            try Task.checkCancellation()
            guard request == generation, loadedUserID == userID else { return }
            items = page
            routesByID = routes
            canLoadMore = page.count == pageSize
        } catch is CancellationError {
        } catch {
            guard request == generation, loadedUserID == userID else { return }
            items = []
            routesByID = [:]
            canLoadMore = false
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(userID: UUID?) async {
        guard canLoadMore, !isLoadingMore, let userID, userID == loadedUserID, let cursor = items.last?.cursor else { return }
        let request = generation
        isLoadingMore = true
        paginationErrorMessage = nil
        defer {
            if request == generation { isLoadingMore = false }
        }
        do {
            let page = try await profileRepository.fetchFollowingFeed(cursor: cursor, limit: pageSize)
            try Task.checkCancellation()
            guard request == generation, loadedUserID == userID else { return }
            let existing = Set(items.map(\.routeId))
            let additions = page.filter { !existing.contains($0.routeId) }
            let combined = items + additions
            let routes = try await enrichedRoutes(for: combined, userID: userID)
            try Task.checkCancellation()
            guard request == generation, loadedUserID == userID else { return }
            items = combined
            routesByID = routes
            canLoadMore = page.count == pageSize
            paginationErrorMessage = nil
        } catch is CancellationError {
        } catch {
            guard request == generation, loadedUserID == userID else { return }
            paginationErrorMessage = error.localizedDescription
        }
    }

    private func enrichedRoutes(for items: [FollowingFeedItem], userID: UUID) async throws -> [UUID: Route] {
        let routes = try await routesRepository.fetchRoutes(userId: userID)
        let feedIDs = Set(items.map(\.routeId))
        return Dictionary(uniqueKeysWithValues: routes.compactMap { route in
            guard let id = UUID(uuidString: route.id), feedIDs.contains(id) else { return nil }
            return (id, route)
        })
    }
}
