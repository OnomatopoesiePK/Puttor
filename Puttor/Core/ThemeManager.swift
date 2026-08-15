//
//  ThemeManager.swift
//  Puttor
//
//  App-wide light/dark appearance switch, independent of the system setting
//  (default dark, matching the original design) — mirrors LocalizationManager.
//

import SwiftUI
import Combine

enum AppAppearance: String, CaseIterable {
    case dark, light
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let storageKey = "appColorScheme"

    @Published private(set) var appearance: AppAppearance

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppAppearance.dark.rawValue
        self.appearance = AppAppearance(rawValue: saved) ?? .dark
    }

    func setAppearance(_ appearance: AppAppearance) {
        UserDefaults.standard.set(appearance.rawValue, forKey: Self.storageKey)
        self.appearance = appearance
    }

    var isDark: Bool { appearance == .dark }
    var colorScheme: ColorScheme { isDark ? .dark : .light }
}
