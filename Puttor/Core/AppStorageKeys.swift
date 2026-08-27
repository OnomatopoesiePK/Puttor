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
    static let statsSelectedRoundIDs = "statsSelectedRoundIDs"  // Comma-joined round UUIDs for the Statistics "Choose rounds" filter
    static let statsRangeStart = "statsRangeStart"              // Double, start of the Statistics date window (timeIntervalSince1970)
    static let statsRangeEnd = "statsRangeEnd"                  // Double, end of that window
    static let statsRoundSort = "statsRoundSort"                // RoundSort rawValue for the round list and grid

    /// Whether one section of the Statistics tab is unfolded — one Bool per
    /// section id, so the tab reopens exactly as the user left it.
    static func statsSection(_ id: String) -> String { "statsSection.\(id)" }
}
