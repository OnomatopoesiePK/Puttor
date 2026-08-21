//
//  AppStorageKeys.swift
//  Puttor
//

import Foundation

enum AppStorageKeys {
    static let units = "unitsPreference"                       // "metric" | "imperial"
    static let haptics = "hapticsEnabled"                       // Bool, default true
    static let defaultFirstPuttDistance = "defaultFirstPuttDistanceM" // Double, default 6.0
    static let appLanguage = "appLanguage"                      // "en" | "de"
    static let customModeConfig = "customModeConfigJSON"        // JSON-encoded CustomModeConfig
    static let lastInputMode = "lastInputMode"                  // InputMode rawValue, preselected for the next round
    static let statsCustomRoundCount = "statsCustomRoundCount"  // Int, rounds included by the Statistics "Custom" filter
    static let sgBaselineVersion = "sgBaselineVersion"          // Int, which baseline table stored SG values were computed against
}
