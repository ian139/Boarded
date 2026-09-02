import SwiftUI
import SwiftData
import UIKit

@main
struct BoardedApp: App {
    private let modelContainer: ModelContainer

    init() {
        let tabs = UITabBarAppearance(); tabs.configureWithOpaqueBackground(); tabs.backgroundColor = UIColor(AppColor.backgroundElevated); tabs.shadowColor = UIColor(AppColor.divider); tabs.stackedLayoutAppearance.selected.iconColor = UIColor(AppColor.accentDefault); tabs.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColor.accentDefault)]; tabs.stackedLayoutAppearance.normal.iconColor = UIColor(AppColor.textSecondary); tabs.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColor.textSecondary)]; UITabBar.appearance().standardAppearance = tabs; UITabBar.appearance().scrollEdgeAppearance = tabs
        let nav = UINavigationBarAppearance(); nav.configureWithOpaqueBackground(); nav.backgroundColor = UIColor(AppColor.backgroundBase); nav.shadowColor = UIColor(AppColor.divider); nav.titleTextAttributes = [.foregroundColor: UIColor(AppColor.textPrimary)]; nav.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColor.textPrimary)]; UINavigationBar.appearance().standardAppearance = nav; UINavigationBar.appearance().scrollEdgeAppearance = nav

        let schema = Schema([PendingSession.self, PendingAttempt.self, PendingAttemptDeletion.self, PendingDraftDeletion.self, PendingSessionDraft.self])
        let environment = ProcessInfo.processInfo.environment
        let configuration: ModelConfiguration
        if AppLaunchConfiguration.isOfflineFixture,
           let storeID = environment["BOARDED_OFFLINE_STORE_ID"],
           !storeID.isEmpty {
            configuration = ModelConfiguration("BoardedOffline-\(storeID)")
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: AppLaunchConfiguration.isUITestFixture)
        }
        do {
            modelContainer = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Unable to initialize Boarded storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(modelContainer)
    }

}
