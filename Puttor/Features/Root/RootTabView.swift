//
//  RootTabView.swift
//  Puttor
//
//  4-tab root, replacing the default ContentView.swift template.
//  Ported from (tabs)/_layout.tsx.
//
//  In landscape the tabs become a row of icons floating in the middle of
//  whatever top row the screen already has — the one strip of a short wide
//  screen nothing else wants, and the one neither rotation puts a notch
//  through. It is an overlay, so it costs no height at all. The TabView itself
//  stays and only its bar is hidden, so the tabs keep their state across a
//  rotation instead of being rebuilt as a different view tree.
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
    RootTab(tag: 4, labelKey: "tab.coach", icon: "eyeglasses"),
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
        tabs
            // Laid over the screen's own top row rather than above it: every
            // screen keeps its title at the left and its actions at the right,
            // and the middle of that line was empty anyway.
            .overlay(alignment: .top) {
                if isLandscape { tabStrip }
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
                .tabItem { Label(L("tab.coach"), systemImage: "eyeglasses") }
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

    /// Icons only: five glyphs the app uses everywhere else, small enough to
    /// sit inside a row that already has something in it.
    private var tabStrip: some View {
        HStack(spacing: 2) {
            ForEach(rootTabs) { tab in
                Button {
                    selectedTab = tab.tag
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTab == tab.tag ? Theme.primary : Theme.textMuted)
                        .frame(width: 34, height: 26)
                        .background(
                            Capsule().fill(selectedTab == tab.tag ? Theme.primary.opacity(0.16) : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .padding(.top, 4)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Putter.self, Round.self, Putt.self, GameSession.self, GameAttempt.self], inMemory: true)
}
