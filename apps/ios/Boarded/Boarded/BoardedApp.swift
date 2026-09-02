import SwiftUI
import SwiftData
import UIKit

@main
struct BoardedApp: App {
    init() {
        let tabs=UITabBarAppearance(); tabs.configureWithOpaqueBackground(); tabs.backgroundColor=UIColor(AppColor.backgroundElevated); tabs.shadowColor=UIColor(AppColor.divider); tabs.stackedLayoutAppearance.selected.iconColor=UIColor(AppColor.accentDefault); tabs.stackedLayoutAppearance.selected.titleTextAttributes=[.foregroundColor:UIColor(AppColor.accentDefault)]; tabs.stackedLayoutAppearance.normal.iconColor=UIColor(AppColor.textSecondary); tabs.stackedLayoutAppearance.normal.titleTextAttributes=[.foregroundColor:UIColor(AppColor.textSecondary)]; UITabBar.appearance().standardAppearance=tabs; UITabBar.appearance().scrollEdgeAppearance=tabs
        let nav=UINavigationBarAppearance(); nav.configureWithOpaqueBackground(); nav.backgroundColor=UIColor(AppColor.backgroundBase); nav.shadowColor=UIColor(AppColor.divider); nav.titleTextAttributes=[.foregroundColor:UIColor(AppColor.textPrimary)]; nav.largeTitleTextAttributes=[.foregroundColor:UIColor(AppColor.textPrimary)]; UINavigationBar.appearance().standardAppearance=nav; UINavigationBar.appearance().scrollEdgeAppearance=nav
    }
    var body: some Scene { WindowGroup { RootView() }.modelContainer(for: [PendingSession.self, PendingAttempt.self, PendingAttemptDeletion.self, PendingSessionDraft.self]) }
}
