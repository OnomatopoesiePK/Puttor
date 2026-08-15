//
//  GameScoring.swift
//  Puttor
//

import Foundation

enum GameScoring {
    static func bestSession(for gameType: GameType, in sessions: [GameSession]) -> GameSession? {
        let matching = sessions.filter { $0.gameType == gameType && $0.isComplete }
        guard !matching.isEmpty else { return nil }
        if gameType.lowerScoreIsBetter {
            return matching.min { $0.score < $1.score }
        } else {
            return matching.max { $0.score < $1.score }
        }
    }

    static func isNewBest(_ session: GameSession, among sessions: [GameSession]) -> Bool {
        let others = sessions.filter { $0.isComplete && $0.id != session.id && $0.gameType == session.gameType }
        guard let best = bestSession(for: session.gameType, in: others) else { return true }
        return session.gameType.lowerScoreIsBetter ? session.score <= best.score : session.score >= best.score
    }
}
