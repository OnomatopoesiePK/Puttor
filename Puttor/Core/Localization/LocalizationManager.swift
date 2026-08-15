//
//  LocalizationManager.swift
//  Puttor
//
//  In-app language switch independent of the system locale (default English).
//

import Foundation
import Combine

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    static let supportedLanguages = ["en", "de"]
    private static let storageKey = "appLanguage"

    @Published private(set) var languageCode: String
    private(set) var bundle: Bundle

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey) ?? "en"
        let resolved = Self.supportedLanguages.contains(saved) ? saved : "en"
        self.languageCode = resolved
        self.bundle = Self.bundleFor(resolved)
    }

    func setLanguage(_ code: String) {
        guard Self.supportedLanguages.contains(code) else { return }
        UserDefaults.standard.set(code, forKey: Self.storageKey)
        languageCode = code
        bundle = Self.bundleFor(code)
    }

    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func bundleFor(_ code: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

/// Shorthand localized-string lookup, e.g. `L("onCourse.title")`.
func L(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}

extension String {
    var localized: String { LocalizationManager.shared.string(self) }
}
