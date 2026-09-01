import Foundation

/// Central service graph. Production code always resolves Supabase-backed
/// repositories; deterministic fixtures are used only for UI-test/preview
/// launch arguments and never as a silent production fallback.
enum AppServices {
    static let sessionRepository: any SessionRepository = {
        #if DEBUG
        if AppLaunchConfiguration.isUITestFixture {
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
        if AppLaunchConfiguration.isUITestFixture {
            return MockFeedRepository()
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
        if AppLaunchConfiguration.isUITestFixture {
            return MockMeetupRepository()
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
        if AppLaunchConfiguration.isUITestFixture {
            return MockProfileRepository()
        }
        #endif
        #if canImport(Supabase)
        return SupabaseProfileRepository(client: SupabaseClientProvider.client)
        #else
        return MockProfileRepository()
        #endif
    }()
}
