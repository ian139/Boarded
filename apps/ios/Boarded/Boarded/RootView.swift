import SwiftUI
import UIKit

struct RootView: View {
    private enum Destination: Int { case home, log, topo, profile }

    @StateObject private var session = AppSession(fixture: AppLaunchConfiguration.isUITestFixture)
    @StateObject private var routesViewModel = RoutesViewModel(repository: AppServices.routesRepository)
    @StateObject private var routeDetailPresenter = RouteDetailPresenter()
    @State private var selectedTab: Destination
    private let logFixture: AttemptLogFixture?

    init() {
        let fixture = Self.fixtureConfiguration
        _selectedTab = State(initialValue: fixture == nil ? .home : .log)
        logFixture = fixture
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack { RoutesView() }
                    .accessibilityHidden(routeDetailPresenter.presentation != nil)
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(Destination.home)

                NavigationStack { LogView(fixture: logFixture) }
                    .accessibilityHidden(routeDetailPresenter.presentation != nil)
                    .tabItem { Label("Log", systemImage: "square.and.pencil") }
                    .tag(Destination.log)

                NavigationStack { EditorView() }
                    .accessibilityHidden(routeDetailPresenter.presentation != nil)
                    .tabItem { Label("Topo", systemImage: "point.3.connected.trianglepath.dotted") }
                    .tag(Destination.topo)

                NavigationStack { ProfileView() }
                    .accessibilityHidden(routeDetailPresenter.presentation != nil)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(Destination.profile)
            }
            .toolbarBackground(AppColor.backgroundElevated, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbar(routeDetailPresenter.presentation == nil ? .visible : .hidden, for: .tabBar)
            .allowsHitTesting(routeDetailPresenter.presentation == nil)
            .background {
                TabBarAccessibilityBridge(isHidden: routeDetailPresenter.presentation != nil)
                    .id(routeDetailPresenter.presentation != nil).frame(width: 0, height: 0)
            }
            .accessibilityHidden(routeDetailPresenter.presentation != nil)

            if let presentation = routeDetailPresenter.presentation {
                RouteDetailView(
                    route: presentation.route,
                    onRouteChanged: presentation.onRouteChanged,
                    onRouteDeleted: presentation.onRouteDeleted,
                    onDismiss: { routeDetailPresenter.dismiss(id: presentation.id) }
                )
                .environmentObject(presentation.routesViewModel)
                .id(presentation.id).zIndex(1)
            }
        }
        .tint(AppColor.accentDefault)
        .preferredColorScheme(.dark)
        .environmentObject(session)
        .environmentObject(routesViewModel)
        .environmentObject(routeDetailPresenter)
        .task { await session.load() }
    }

    private static var fixtureConfiguration: AttemptLogFixture? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--boarded-ui-fixture") else { return nil }
        guard arguments.indices.contains(flag + 1) else { return nil }
        let value = arguments[flag + 1]
        guard !value.hasPrefix("-"), value.hasPrefix("log-") else { return nil }
        return AttemptLogFixture(rawValue: String(value.dropFirst("log-".count)))
        #else
        return nil
        #endif
    }
}

private struct TabBarAccessibilityBridge: UIViewRepresentable {
    let isHidden: Bool
    final class Coordinator { weak var tabBar: UITabBar? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero); view.isUserInteractionEnabled = false; return view
    }
    func updateUIView(_ view: UIView, context: Context) {
        if let tabBar = context.coordinator.tabBar { tabBar.accessibilityElementsHidden = isHidden; return }
        DispatchQueue.main.async {
            guard let tabBar = tabBar(from: view) else { return }
            context.coordinator.tabBar = tabBar
            tabBar.accessibilityElementsHidden = isHidden
        }
    }
    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) { coordinator.tabBar?.accessibilityElementsHidden = false }
    private func tabBar(from view: UIView) -> UITabBar? {
        var responder: UIResponder? = view
        while let current = responder {
            if let tabController = current as? UITabBarController { return tabController.tabBar }
            responder = current.next
        }
        return findTabBarController(in: view.window?.rootViewController)?.tabBar
    }
    private func findTabBarController(in controller: UIViewController?) -> UITabBarController? {
        guard let controller else { return nil }
        if let tabController = controller as? UITabBarController { return tabController }
        for child in controller.children { if let result = findTabBarController(in: child) { return result } }
        if let presented = controller.presentedViewController { return findTabBarController(in: presented) }
        return nil
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View { RootView() }
}
