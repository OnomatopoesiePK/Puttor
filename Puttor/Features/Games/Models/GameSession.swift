//
//  GameSession.swift
//  Puttor
//

import Foundation
import SwiftData

@Model
final class GameSession {
    var id: UUID = UUID()
    var gameTypeRaw: String = GameType.gate.rawValue
    var date: Date = Date()
    var isComplete: Bool = false

    /// Headline result. Meaning depends on gameType.scoreUnitKey:
    /// percent games -> make % (0-100, higher better); ninePutt -> cycles
    /// needed to clear (lower better); aroundTheWorld -> total strokes (lower better).
    var score: Double = 0
    var attemptsTotal: Int = 0
    var madeTotal: Int = 0
    /// Human-readable setup recap, e.g. "4 Tees · 1.2 m · 3 Runden".
    var configSummary: String = ""

    // Training drills (Around The Hole) carry a little more: how long it took,
    // how hard it felt afterwards, and the setup it was played at — the last
    // two are what the next setup's suggestion is built from.
    var durationSeconds: Double = 0
    var difficultyRaw: String?
    var configDistanceM: Double = 0
    var targetRounds: Int = 0

    var difficulty: DrillDifficulty? {
        get { difficultyRaw.flatMap(DrillDifficulty.init(rawValue:)) }
        set { difficultyRaw = newValue?.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \GameAttempt.session)
    var attempts: [GameAttempt] = []

    var gameType: GameType {
        get { GameType(rawValue: gameTypeRaw) ?? .gate }
        set { gameTypeRaw = newValue.rawValue }
    }

    init(gameType: GameType) {
        self.id = UUID()
        self.gameTypeRaw = gameType.rawValue
        self.date = Date()
        self.isComplete = false
    }
}
