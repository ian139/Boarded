import Foundation

#if canImport(Supabase)
import Supabase
#endif

enum AppLaunchConfiguration {
    #if DEBUG
    static var isUITestFixture: Bool {
        ProcessInfo.processInfo.arguments.contains("--boarded-ui-fixture")
    }
    #else
    static let isUITestFixture = false
    #endif
}

/// Recoverable configuration error surfaced when Supabase is not configured.
/// Production code throws this instead of silently falling back to fixtures.
enum SupabaseConfigError: LocalizedError {
    case unconfigured

    var errorDescription: String? {
        switch self {
        case .unconfigured:
            return "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to the app's Info.plist."
        }
    }
}

enum SupabaseConfig {
    static var current: (url: URL, anonKey: String)? {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlString),
            !key.isEmpty
        else {
            return nil
        }
        return (url: url, anonKey: key)
    }
}

#if canImport(Supabase)
enum SupabaseClientProvider {
    static let client: SupabaseClient? = {
        guard let config = SupabaseConfig.current else { return nil }
        return SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }()
}
#endif
