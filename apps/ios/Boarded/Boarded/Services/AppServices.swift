import Foundation
import SwiftData

/// Central service graph. Production code always resolves Supabase-backed
/// repositories; deterministic fixtures are used only for UI-test/preview
/// launch arguments and never as a silent production fallback.
enum AppServices {
    static let sessionRepository: any SessionRepository = {
        #if DEBUG
        if AppLaunchConfiguration.isUITestFixture || AppLaunchConfiguration.isOfflineFixture {
            return MockSessionRepository()
        }
        #endif
        #if canImport(Supabase)
        return SupabaseSessionRepository(client: SupabaseClientProvider.client)
        #else
        return MockSessionRepository()
        #endif
    }()

    static let feedRepository: any FeedRepository = {
        #if DEBUG
        if AppLaunchConfiguration.isUITestFixture || AppLaunchConfiguration.isOfflineFixture {
            return MockFeedRepository(items: UITestFixtures.feed, comments: UITestFixtures.comments, currentUserID: UITestFixtures.userID, now: UITestFixtures.now)
        }
        #endif
        #if canImport(Supabase)
        return SupabaseFeedRepository(client: SupabaseClientProvider.client)
        #else
        return MockFeedRepository()
        #endif
    }()

    static let meetupRepository: any MeetupRepository = {
        #if DEBUG
        if AppLaunchConfiguration.isUITestFixture || AppLaunchConfiguration.isOfflineFixture {
            return MockMeetupRepository(meetups: UITestFixtures.meetups, currentUserID: UITestFixtures.userID, now: UITestFixtures.now)
        }
        #endif
        #if canImport(Supabase)
        return SupabaseMeetupRepository(client: SupabaseClientProvider.client)
        #else
        return MockMeetupRepository()
        #endif
    }()

    static let profileRepository: any ProfileRepository = {
        #if DEBUG
        if AppLaunchConfiguration.isUITestFixture || AppLaunchConfiguration.isOfflineFixture {
            return MockProfileRepository(profile: UITestFixtures.profile, statistics: UITestFixtures.statistics)
        }
        #endif
        #if canImport(Supabase)
        return SupabaseProfileRepository(client: SupabaseClientProvider.client)
        #else
        return MockProfileRepository()
        #endif
    }()

    @MainActor
    static func makeSessionSyncService(modelContext: ModelContext) -> SessionSyncService {
        SessionSyncService(
            repository: sessionRepository,
            feedRepository: feedRepository,
            modelContext: modelContext,
            connectivityOverride: AppLaunchConfiguration.isOfflineFixture ? false : nil
        )
    }
}
