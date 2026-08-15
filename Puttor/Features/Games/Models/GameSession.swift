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
