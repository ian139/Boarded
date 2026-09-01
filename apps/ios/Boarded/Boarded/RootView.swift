import SwiftUI

enum AppTab: Hashable { case home, log, meetups, profile }

@MainActor final class AppNavigation: ObservableObject {
    @Published var selectedTab: AppTab = .home
}

struct RootView: View {
    @StateObject private var session = AppSession(fixture: AppLaunchConfiguration.isUITestFixture)
    @StateObject private var navigation = AppNavigation()
    @State private var authenticationPresented = false

    var body: some View {
        Group {
            if session.isLoading { launchState }
            else if session.needsProfileSetup { ProfileSetupView() }
            else { tabs }
        }
        .tint(AppColor.accentDefault)
        .preferredColorScheme(.dark)
        .environmentObject(session)
        .environmentObject(navigation)
        .environment(\.boardedAuth, BoardedAuthContext(isAuthenticated: session.userId != nil, requestAuthentication: { authenticationPresented = true }))
        .sheet(isPresented: $authenticationPresented) { NavigationStack { AuthenticationView() } }
        .task { await session.load() }
    }

    private var launchState: some View { VStack(spacing:AppSpacing.space16) { Text("Boarded").font(AppTypography.displayL); BoardedRouteLine().frame(width:120,height:96); ProgressView().accessibilityLabel("Loading Boarded") }.frame(maxWidth:.infinity,maxHeight:.infinity).boardedPageBackground() }
    private var tabs: some View {
        TabView(selection: $navigation.selectedTab) {
            NavigationStack { HomeFeedView() }.tabItem { Label("Home", systemImage: "house") }.tag(AppTab.home)
            NavigationStack { LogTabView() }.tabItem { Label("Log", systemImage: "figure.climbing") }.tag(AppTab.log)
            NavigationStack { MeetupsListView() }.tabItem { Label("Meetups", systemImage: "person.3") }.tag(AppTab.meetups)
            NavigationStack { ProfileView() }.tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(AppTab.profile)
        }
        .accessibilityIdentifier("main-tabs")
    }
}
