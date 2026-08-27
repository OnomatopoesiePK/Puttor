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
        case "game.unit.minutes":
            return clockText(score * 60)
        default:
            return "\(Int(score.rounded()))%"
        }
    }

    /// Minutes and seconds, the way a stopwatch reads.
    static func clockText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Same, but keeping one decimal — used for averages, where rounding to a
    /// whole number would hide the difference between runs.
    static func preciseText(_ score: Double, for gameType: GameType) -> String {
        switch gameType.scoreUnitKey {
        case "game.unit.cycles", "game.unit.strokes":
            return String(format: "%.1f", score)
        case "game.unit.minutes":
            return clockText(score * 60)
        default:
            return String(format: "%.1f%%", score)
        }
    }
}
