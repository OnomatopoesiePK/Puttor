//
//  GameScoreFormat.swift
//  Puttor
//
//  One place that turns a raw game score into display text, since the meaning
//  of `GameSession.score` depends on the game (make %, cycles, strokes).
//

import Foundation

enum GameScoreFormat {
    /// Full label, e.g. "72%" or "14".
    static func text(_ score: Double, for gameType: GameType) -> String {
        switch gameType.scoreUnitKey {
        case "game.unit.cycles", "game.unit.strokes":
            return String(format: "%.0f", score)
        default:
            return "\(Int(score.rounded()))%"
        }
    }

    /// Same, but keeping one decimal — used for averages, where rounding to a
    /// whole number would hide the difference between runs.
    static func preciseText(_ score: Double, for gameType: GameType) -> String {
        switch gameType.scoreUnitKey {
        case "game.unit.cycles", "game.unit.strokes":
            return String(format: "%.1f", score)
        default:
            return String(format: "%.1f%%", score)
        }
    }
}
