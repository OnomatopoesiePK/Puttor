//
//  RoundFilter.swift
//  Puttor
//
//  What a round was played in, as a filter. The statistics tab used to pick
//  either a stretch of rounds or a single condition; this is the other half of
//  that, so a stretch and a condition can be asked for together: the last five
//  rounds on quick greens, the last ten in competition, every round with that
//  putter in the rain.
//
//  Kept apart from the count presets on purpose. The presets say how far back
//  to look; this says which of those rounds count.
//

import Foundation

/// One condition a round was played in. Wind, warmth and rain live on the
/// round as three separate fields; for filtering they read better as one list
/// of "what was it like out there".
enum WeatherFilter: String, CaseIterable, Identifiable {
    case sun, rain, windNone, windMedium, windHigh, cold, warm, hot
    var id: String { rawValue }

    var label: String {
        switch self {
        case .sun: return "\(Precipitation.sun.emoji) \(L(Precipitation.sun.labelKey))"
        case .rain: return "\(Precipitation.rain.emoji) \(L(Precipitation.rain.labelKey))"
        case .windNone: return "\(WindLevel.none.emoji) \(L(WindLevel.none.labelKey))"
        case .windMedium: return "\(WindLevel.medium.emoji) \(L(WindLevel.medium.labelKey))"
        case .windHigh: return "\(WindLevel.high.emoji) \(L(WindLevel.high.labelKey))"
        case .cold: return "\(WeatherTemp.cold.emoji) \(L(WeatherTemp.cold.labelKey))"
        case .warm: return "\(WeatherTemp.warm.emoji) \(L(WeatherTemp.warm.labelKey))"
        case .hot: return "\(WeatherTemp.hot.emoji) \(L(WeatherTemp.hot.labelKey))"
        }
    }

    func matches(_ round: Round) -> Bool {
        switch self {
        case .sun: return round.precipitation == .sun
        case .rain: return round.precipitation == .rain
        case .windNone: return round.wind == .none
        case .windMedium: return round.wind == .medium
        case .windHigh: return round.wind == .high
        case .cold: return round.weather == .cold
        case .warm: return round.weather == .warm
        case .hot: return round.weather == .hot
        }
    }
}

/// Yes, no, or don't care — the shape of every filter that asks about a switch.
enum FilterTriState: String, CaseIterable, Identifiable {
    case any, yes, no
    var id: String { rawValue }

    func matches(_ value: Bool) -> Bool {
        switch self {
        case .any: return true
        case .yes: return value
        case .no: return !value
        }
    }
}

struct RoundFilter: Equatable {
    /// Putter.id as a string; nil for any putter.
    var putterID: String?
    var grain: FilterTriState = .any
    var tournament: FilterTriState = .any
    /// nil for any weather.
    var weather: WeatherFilter?
    /// nil for either format.
    var format: PlayFormat?
    /// Whether the green-speed range is being asked about at all. Its two
    /// bounds are separately open, so "enabled with both ends open" is a
    /// perfectly good state — it just filters nothing yet.
    var stimpEnabled = false
    var stimpMin: Double?
    var stimpMax: Double?

    /// The readings the round setup itself offers, which is what there is to
    /// filter by.
    static let stimpSteps: [Double] = Array(stride(from: 6.5, through: 12.5, by: 0.5))

    var isActive: Bool {
        putterID != nil || grain != .any || tournament != .any || weather != nil || format != nil
            || (stimpEnabled && (stimpMin != nil || stimpMax != nil))
    }

    func matches(_ round: Round) -> Bool {
        if let putterID, round.putter?.id.uuidString != putterID { return false }
        guard grain.matches(round.grainyGreens) else { return false }
        guard tournament.matches(round.isTournament) else { return false }
        if let weather, !weather.matches(round) { return false }
        if let format, round.playFormat != format { return false }
        if stimpEnabled {
            if let stimpMin, round.stimp < stimpMin - 0.001 { return false }
            if let stimpMax, round.stimp > stimpMax + 0.001 { return false }
        }
        return true
    }

    // MARK: - Storage

    /// Flat enough to live in AppStorage: the pane remembers its filter the
    /// way it remembers its preset.
    var encoded: String {
        var parts: [String] = []
        if let putterID { parts.append("putter=\(putterID)") }
        if grain != .any { parts.append("grain=\(grain.rawValue)") }
        if tournament != .any { parts.append("tr=\(tournament.rawValue)") }
        if let weather { parts.append("weather=\(weather.rawValue)") }
        if let format { parts.append("format=\(format.rawValue)") }
        if stimpEnabled {
            parts.append("stimp=1")
            if let stimpMin { parts.append("smin=\(stimpMin)") }
            if let stimpMax { parts.append("smax=\(stimpMax)") }
        }
        return parts.joined(separator: ";")
    }

    static func decode(_ raw: String) -> RoundFilter {
        var filter = RoundFilter()
        for part in raw.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            let value = String(pair[1])
            switch pair[0] {
            case "putter": filter.putterID = value
            case "grain": filter.grain = FilterTriState(rawValue: value) ?? .any
            case "tr": filter.tournament = FilterTriState(rawValue: value) ?? .any
            case "weather": filter.weather = WeatherFilter(rawValue: value)
            case "format": filter.format = PlayFormat(rawValue: value)
            case "stimp": filter.stimpEnabled = value == "1"
            case "smin": filter.stimpMin = Double(value)
            case "smax": filter.stimpMax = Double(value)
            default: break
            }
        }
        return filter
    }
}
