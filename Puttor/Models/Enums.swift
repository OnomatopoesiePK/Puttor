//
//  Enums.swift
//  Puttor
//

import Foundation

enum PuttResult: String, Codable, CaseIterable {
    case holed
    case short
    case long
    case left
    case right
    case shortLeft
    case shortRight
    case longLeft
    case longRight
    case holeHigh
    /// Quick mode: missed, direction not tracked.
    case missedGeneric

    var isHoled: Bool { self == .holed }

    var labelKey: String {
        switch self {
        case .holed: return "result.holed"
        case .short: return "result.short"
        case .long: return "result.long"
        case .left: return "result.left"
        case .right: return "result.right"
        case .shortLeft: return "result.shortLeft"
        case .shortRight: return "result.shortRight"
        case .longLeft: return "result.longLeft"
        case .longRight: return "result.longRight"
        case .holeHigh: return "result.holeHigh"
        case .missedGeneric: return "result.missedGeneric"
        }
    }

    var emoji: String {
        switch self {
        case .holed: return "✅"
        case .short: return "⬇"
        case .long: return "⬆"
        case .left: return "⬅"
        case .right: return "➡"
        case .shortLeft: return "↙"
        case .shortRight: return "↘"
        case .longLeft: return "↖"
        case .longRight: return "↗"
        case .holeHigh: return "🕳️"
        case .missedGeneric: return "❌"
        }
    }
}

/// What went wrong in a bad stroke — offered as a follow-up once "bad stroke"
/// is selected, since "bad stroke" alone doesn't say which way it went.
enum BadStrokeType: String, Codable, CaseIterable, Identifiable {
    case pull
    case misshit
    case push

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .pull: return "input.badStroke.pull"
        case .misshit: return "input.badStroke.misshit"
        case .push: return "input.badStroke.push"
        }
    }
}

enum DoubleBreakType: String, Codable, CaseIterable {
    case rlThenLr // right-to-left, then left-to-right
    case lrThenRl // left-to-right, then right-to-left

    var labelKey: String {
        switch self {
        case .rlThenLr: return "doubleBreak.rlLr"
        case .lrThenRl: return "doubleBreak.lrRl"
        }
    }
}

enum WindLevel: String, Codable, CaseIterable {
    case none, medium, high

    var labelKey: String {
        switch self {
        case .none: return "wind.none"
        case .medium: return "wind.medium"
        case .high: return "wind.high"
        }
    }

    var emoji: String {
        switch self {
        case .none: return "🌤"
        case .medium: return "💨"
        case .high: return "🌬"
        }
    }
}

enum WeatherTemp: String, Codable, CaseIterable {
    case cold, warm, hot

    var labelKey: String {
        switch self {
        case .cold: return "weather.cold"
        case .warm: return "weather.warm"
        case .hot: return "weather.hot"
        }
    }

    var emoji: String {
        switch self {
        case .cold: return "🥶"
        case .warm: return "😊"
        case .hot: return "🥵"
        }
    }
}

enum Precipitation: String, Codable, CaseIterable {
    case sun, rain

    var labelKey: String {
        switch self {
        case .sun: return "precipitation.sun"
        case .rain: return "precipitation.rain"
        }
    }

    var emoji: String {
        switch self {
        case .sun: return "☀️"
        case .rain: return "🌧️"
        }
    }
}

enum InputMode: String, Codable, CaseIterable {
    case pro, quick, custom

    var labelKey: String {
        switch self {
        case .pro: return "inputMode.pro"
        case .quick: return "inputMode.quick"
        case .custom: return "inputMode.custom"
        }
    }

    var descriptionKey: String {
        switch self {
        case .pro: return "inputMode.pro.desc"
        case .quick: return "inputMode.quick.desc"
        case .custom: return "inputMode.custom.desc"
        }
    }
}
