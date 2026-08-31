//
//  RootTabView.swift
//  Puttor
//
//  4-tab root, replacing the default ContentView.swift template.
//  Ported from (tabs)/_layout.tsx.
//
//  In landscape the tabs move to a strip across the top middle — the one part
//  of a short wide screen nothing else wants, and the one part neither
//  rotation puts a notch through. The TabView itself stays and only its bar is
//  hidden, so the tabs keep their state across a rotation instead of being
//  rebuilt as a different view tree.
//

import SwiftUI
import SwiftData

private struct RootTab: Identifiable {
    let tag: Int
    let labelKey: String
    let icon: String
    var id: Int { tag }
}

private let rootTabs: [RootTab] = [
    RootTab(tag: 0, labelKey: "tab.course", icon: "flag.fill"),
    RootTab(tag: 1, labelKey: "tab.stats", icon: "chart.bar.fill"),
    RootTab(tag: 4, labelKey: "tab.coach", icon: "figure.golf"),
    RootTab(tag: 2, labelKey: "tab.games", icon: "scope"),
    RootTab(tag: 3, labelKey: "tab.settings", icon: "gearshape.fill"),
]

struct RootTabView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    /// Lives outside the .id()'d TabView below, so switching language or
    /// appearance (which rebuilds that subtree) doesn't reset the active tab.
    @State private var selectedTab = 0
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool { verticalSizeClass == .compact }

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        VStack(spacing: 0) {
            // A strip along the top rather than a rail down the side: rotate
            // the other way and a side rail ends up under the island.
            if isLandscape { tabStrip }
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            OnCourseListView()
                .tabItem { Label(L("tab.course"), systemImage: "flag.fill") }
                .tag(0)
                .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)

            StatisticsView()
                .tabItem { Label(L("tab.stats"), systemImage: "chart.bar.fill") }
                .tag(1)
                .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)

            CoachView()
                .tabItem { Label(L("tab.coach"), systemImage: "figure.golf") }
                .tag(4)
                .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)

            GamesHomeView()
                .tabItem { Label(L("tab.games"), systemImage: "scope") }
                .tag(2)
                .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)

            SettingsView()
                .tabItem { Label(L("tab.settings"), systemImage: "gearshape.fill") }
                .tag(3)
                .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
        }
        .tint(Theme.primary)
        .id("\(localization.languageCode)-\(themeManager.appearance.rawValue)")
        .preferredColorScheme(themeManager.colorScheme)
    }

    /// The tab bar laid across the top: centred, only as wide as its buttons,
    /// and short enough to cost the layout almost nothing.
    private var tabStrip: some View {
        HStack(spacing: 2) {
            ForEach(rootTabs) { tab in
                Button {
                    selectedTab = tab.tag
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(L(tab.labelKey))
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedTab == tab.tag ? Theme.primary : Theme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(selectedTab == tab.tag ? Theme.primary.opacity(0.14) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .padding(.top, 2)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Putter.self, Round.self, Putt.self, GameSession.self, GameAttempt.self], inMemory: true)
}
