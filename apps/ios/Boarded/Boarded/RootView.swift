import SwiftUI

/// Minimal composition boundary for the social/session core. The designer
/// follow-on replaces this shell with the real tab structure and screens.
struct RootView: View {
    @StateObject private var session = AppSession(fixture: AppLaunchConfiguration.isUITestFixture)

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.space16) {
                if session.isLoading {
                    ProgressView()
                } else if session.userId == nil {
                    Text("Sign in to start logging sessions.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary)
                } else {
                    Text("Welcome, \(session.displayName)")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .boardedPageBackground()
        }
        .tint(AppColor.accentDefault)
        .preferredColorScheme(.dark)
        .environmentObject(session)
        .task { await session.load() }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View { RootView() }
}
