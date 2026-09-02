//
//  GameType.swift
//  Puttor
//

import Foundation

enum GameType: String, Codable, CaseIterable, Identifiable {
    case gate
    case clock
    case aroundTheHole
    case ninePutt
    case routine
    case aroundTheWorld
    case ladder

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gate: return "🥅"
        case .clock: return "🕐"
        case .ninePutt: return "🔢"
        case .routine: return "📋"
        case .aroundTheWorld: return "🌍"
        case .aroundTheHole: return "🎯"
        case .ladder: return "🪜"
        }
    }

    var titleKey: String {
        switch self {
        case .gate: return "game.gate.title"
        case .clock: return "game.clock.title"
        case .ninePutt: return "game.ninePutt.title"
        case .routine: return "game.routine.title"
        case .aroundTheWorld: return "game.aroundTheWorld.title"
        case .aroundTheHole: return "game.aroundTheHole.title"
        case .ladder: return "game.ladder.title"
        }
    }

    var goalKey: String {
        switch self {
        case .gate: return "game.gate.goal"
        case .clock: return "game.clock.goal"
        case .ninePutt: return "game.ninePutt.goal"
        case .routine: return "game.routine.goal"
        case .aroundTheWorld: return "game.aroundTheWorld.goal"
        case .aroundTheHole: return "game.aroundTheHole.goal"
        case .ladder: return "game.ladder.goal"
        }
    }

    var explanationKey: String {
        switch self {
        case .gate: return "game.gate.explanation"
        case .clock: return "game.clock.explanation"
        case .ninePutt: return "game.ninePutt.explanation"
        case .routine: return "game.routine.explanation"
        case .aroundTheWorld: return "game.aroundTheWorld.explanation"
        case .aroundTheHole: return "game.aroundTheHole.explanation"
        case .ladder: return "game.ladder.explanation"
        }
    }

    /// What kind of practice this is, in two words — the line under the name
    /// on the games list.
    var categoryKey: String {
        switch self {
        case .gate: return "game.category.startLine"
        case .ladder: return "game.category.speed"
        default: return "game.category.game"
        }
    }

    /// True for games scored in strokes, cycles or minutes, where a smaller
    /// number is the better result.
    var lowerScoreIsBetter: Bool {
        switch self {
        case .ninePutt, .aroundTheWorld, .aroundTheHole, .ladder: return true
        default: return false
        }
    }

    var scoreUnitKey: String {
        switch self {
        case .aroundTheWorld: return "game.unit.strokes"
        case .aroundTheHole, .ninePutt, .ladder: return "game.unit.minutes"
        default: return "game.unit.percent"
        }
    }

    /// A drill you either finish or don't, rather than one you score. Nothing
    /// is tapped while it runs, its result is the time it took, and its history
    /// is about turning up regularly — so it shows an activity board instead of
    /// a scoreboard.
    var isTrainingDrill: Bool {
        switch self {
        case .aroundTheHole, .ninePutt, .ladder: return true
        default: return false
        }
    }
}
