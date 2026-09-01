//
//  BoardedApp.swift
//  Boarded
//
//  Created by Ian Rapko on 3/5/26.
//

import SwiftUI
import UIKit

@main
struct BoardedApp: App {
    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppColor.backgroundElevated)
        tabAppearance.shadowColor = UIColor(AppColor.divider)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColor.accentDefault)
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColor.accentDefault)]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColor.textSecondary)
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColor.textSecondary)]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = UIColor(AppColor.backgroundBase)
        navigationAppearance.shadowColor = UIColor(AppColor.divider)
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppColor.textPrimary)]
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
    }


    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
