//
//  RootTabView.swift
//  Puttor
//
//  4-tab root, replacing the default ContentView.swift template.
//  Ported from (tabs)/_layout.tsx.
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    /// Lives outside the .id()'d TabView below, so switching language or
    /// appearance (which rebuilds that subtree) doesn't reset the active tab.
    @State private var selectedTab = 0

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            OnCourseListView()
                .tabItem {
                    Label(L("tab.course"), systemImage: "flag.fill")
                }
                .tag(0)

            StatisticsView()
                .tabItem {
                    Label(L("tab.stats"), systemImage: "chart.bar.fill")
                }
                .tag(1)

            GamesHomeView()
                .tabItem {
                    Label(L("tab.games"), systemImage: "scope")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(L("tab.settings"), systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(Theme.primary)
        .id("\(localization.languageCode)-\(themeManager.appearance.rawValue)")
        .preferredColorScheme(themeManager.colorScheme)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Putter.self, Round.self, Putt.self, GameSession.self, GameAttempt.self], inMemory: true)
}
