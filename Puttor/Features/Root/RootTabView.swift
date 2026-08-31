//
//  RootTabView.swift
//  Puttor
//
//  4-tab root, replacing the default ContentView.swift template.
//  Ported from (tabs)/_layout.tsx.
//
//  In landscape the tabs move to a rail down the left edge, where a short wide
//  screen has room to spare. The TabView itself stays — only its bar is
//  hidden — so the four tabs keep their state across a rotation instead of
//  being rebuilt as a different view tree.
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
        TabView(selection: $selectedTab) {
            OnCourseListView()
                .tabItem { Label(L("tab.course"), systemImage: "flag.fill") }
                .tag(0)
                .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)

            StatisticsView()
                .tabItem { Label(L("tab.stats"), systemImage: "chart.bar.fill") }
                .tag(1)
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
        .safeAreaInset(edge: .leading, spacing: 0) {
            if isLandscape { tabRail }
        }
        .id("\(localization.languageCode)-\(themeManager.appearance.rawValue)")
        .preferredColorScheme(themeManager.colorScheme)
    }

    /// The tab bar stood on its end: a floating strip rather than a wall, kept
    /// narrow and centred so it takes as little of a short screen as it can.
    private var tabRail: some View {
        VStack(spacing: 2) {
            ForEach(rootTabs) { tab in
                Button {
                    selectedTab = tab.tag
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(L(tab.labelKey))
                            .font(.system(size: 8, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(selectedTab == tab.tag ? Theme.primary : Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(selectedTab == tab.tag ? Theme.primary.opacity(0.14) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 3)
        .frame(width: 48)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
        .padding(.leading, 4)
        // Centred on the screen's height rather than stretched down it.
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Putter.self, Round.self, Putt.self, GameSession.self, GameAttempt.self], inMemory: true)
}
