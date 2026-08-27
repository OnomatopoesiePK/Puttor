//
//  GameScoring.swift
//  Puttor
//

import Foundation

enum GameScoring {
    static func bestSession(for gameType: GameType, in sessions: [GameSession]) -> GameSession? {
        let matching = sessions.filter { $0.gameType == gameType && $0.isComplete && hasComparableScore($0) }
        guard !matching.isEmpty else { return nil }
        if gameType.lowerScoreIsBetter {
            return matching.min { $0.score < $1.score }
        } else {
            return matching.max { $0.score < $1.score }
        }
    }

    /// Completed sessions for a game, newest first.
    static func history(for gameType: GameType, in sessions: [GameSession]) -> [GameSession] {
        sessions
            .filter { $0.gameType == gameType && $0.isComplete }
            .sorted { $0.date > $1.date }
    }

    /// A timed drill's score is the clock, so sessions recorded before it was
    /// timed — cycles, back when the drill was tapped through — have nothing
    /// to compare. They stay in the history and on the activity board, but
    /// they are not a time to beat.
    private static func hasComparableScore(_ session: GameSession) -> Bool {
        session.gameType.isTrainingDrill ? session.durationSeconds > 0 : true
    }

    /// Mean score over the most recent `count` sessions — the counterpart to the
    /// all-time best, showing where the player currently sits rather than how
    /// good their single luckiest round was. Nil when nothing has been played.
    static func recentAverage(for gameType: GameType, in sessions: [GameSession], count: Int = 5) -> Double? {
        let recent = history(for: gameType, in: sessions).filter(hasComparableScore).prefix(count)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0) { $0 + $1.score } / Double(recent.count)
    }

    static func isNewBest(_ session: GameSession, among sessions: [GameSession]) -> Bool {
        let others = sessions.filter { $0.isComplete && $0.id != session.id && $0.gameType == session.gameType }
        guard let best = bestSession(for: session.gameType, in: others) else { return true }
        return session.gameType.lowerScoreIsBetter ? session.score <= best.score : session.score >= best.score
    }
}
