//
//  GameType.swift
//  Puttor
//

import Foundation

enum GameType: String, Codable, CaseIterable, Identifiable {
    case gate
    case clock
    case ninePutt
    case routine
    case aroundTheWorld

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gate: return "🥅"
        case .clock: return "🕐"
        case .ninePutt: return "🔢"
        case .routine: return "📋"
        case .aroundTheWorld: return "🌍"
        }
    }

    var titleKey: String {
        switch self {
        case .gate: return "game.gate.title"
        case .clock: return "game.clock.title"
        case .ninePutt: return "game.ninePutt.title"
        case .routine: return "game.routine.title"
        case .aroundTheWorld: return "game.aroundTheWorld.title"
        }
    }

    var goalKey: String {
        switch self {
        case .gate: return "game.gate.goal"
        case .clock: return "game.clock.goal"
        case .ninePutt: return "game.ninePutt.goal"
        case .routine: return "game.routine.goal"
        case .aroundTheWorld: return "game.aroundTheWorld.goal"
        }
    }

    var explanationKey: String {
        switch self {
        case .gate: return "game.gate.explanation"
        case .clock: return "game.clock.explanation"
        case .ninePutt: return "game.ninePutt.explanation"
        case .routine: return "game.routine.explanation"
        case .aroundTheWorld: return "game.aroundTheWorld.explanation"
        }
    }

    /// True for games scored in strokes/cycles, where a smaller number is the better result.
    var lowerScoreIsBetter: Bool {
        switch self {
        case .ninePutt, .aroundTheWorld: return true
        default: return false
        }
    }

    var scoreUnitKey: String {
        switch self {
        case .ninePutt: return "game.unit.cycles"
        case .aroundTheWorld: return "game.unit.strokes"
        default: return "game.unit.percent"
        }
    }
}
