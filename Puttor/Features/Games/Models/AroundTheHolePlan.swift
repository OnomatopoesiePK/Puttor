//
//  AroundTheHolePlan.swift
//  Puttor
//
//  The five stations of Around The Hole, and how many clean laps the drill
//  asks for at a given distance.
//

import Foundation

/// How the drill felt afterwards. The answer steers the next setup rather than
/// being scored: too easy earns another lap, too hard gives one back.
enum DrillDifficulty: String, Codable, CaseIterable, Identifiable {
    case tooEasy, justRight, tooHard
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .tooEasy: return "game.difficulty.tooEasy"
        case .justRight: return "game.difficulty.justRight"
        case .tooHard: return "game.difficulty.tooHard"
        }
    }

    var icon: String {
        switch self {
        case .tooEasy: return "arrow.down.circle"
        case .justRight: return "checkmark.circle"
        case .tooHard: return "arrow.up.circle"
        }
    }
}

/// One tee position. The lap starts on the straight uphill putt in the middle
/// and works around the four breaking ones.
enum AroundTheHoleStation: Int, CaseIterable, Identifiable {
    case straightUphill = 0
    case rightLeftUphill
    case rightLeftDownhill
    case leftRightUphill
    case leftRightDownhill

    var id: Int { rawValue }

    var labelKey: String {
        switch self {
        case .straightUphill: return "game.ath.station.straight"
        case .rightLeftUphill: return "game.ath.station.rlUp"
        case .rightLeftDownhill: return "game.ath.station.rlDown"
        case .leftRightUphill: return "game.ath.station.lrUp"
        case .leftRightDownhill: return "game.ath.station.lrDown"
        }
    }

    /// Where the tee sits around the hole, as a compass angle in degrees with
    /// 0 straight below the hole: the uphill putts come from below, the
    /// downhill ones from above, and the break decides which side.
    var angleDegrees: Double {
        switch self {
        case .straightUphill: return 180
        case .rightLeftUphill: return 225
        case .rightLeftDownhill: return 315
        case .leftRightUphill: return 135
        case .leftRightDownhill: return 45
        }
    }
}

enum AroundTheHolePlan {
    static let stations = AroundTheHoleStation.allCases
    static let puttsPerLap = AroundTheHoleStation.allCases.count

    /// The published starting point: the shorter the putt, the more clean laps
    /// it takes to prove anything.
    static func defaultRounds(forDistance metres: Double) -> Int {
        if metres <= 1.1 { return 5 }
        if metres <= 1.6 { return 3 }
        if metres <= 2.2 { return 2 }
        return 1
    }

    /// What to offer next time at this distance, from how the last session at
    /// that distance felt: too easy adds a lap to what was asked then, too hard
    /// gives one back, and "about right" keeps it. Adding one at a time means a
    /// run of easy days climbs steadily rather than jumping; the ceiling stops
    /// it turning the drill into an afternoon.
    static func suggestedRounds(forDistance metres: Double, history: [GameSession]) -> Int {
        let base = defaultRounds(forDistance: metres)
        let latest = history
            .filter { $0.gameType == .aroundTheHole && abs($0.configDistanceM - metres) < 0.05 }
            .max { $0.date < $1.date }

        guard let latest, let difficulty = latest.difficulty else { return base }
        let asked = latest.targetRounds > 0 ? latest.targetRounds : base

        switch difficulty {
        case .tooEasy: return min(base + 5, asked + 1)
        case .justRight: return max(1, asked)
        case .tooHard: return max(1, asked - 1)
        }
    }
}
