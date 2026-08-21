//
//  ScorePuttingAnalysis.swift
//  Puttor
//
//  Ties the scorecard to the putter. A round's score is what putting did to it
//  plus everything else, so taking the putting result back out leaves the score
//  the rest of the game produced — and comparing how much the two swing from
//  round to round says which half decides your good and bad days.
//

import Foundation

struct ScorePuttingAnalysis {
    struct Round: Identifiable {
        let id: Int
        let date: Date
        let courseName: String
        /// Strokes over par for the round as it was played.
        let score: Double
        /// Strokes gained putting over that same round.
        let sg: Double
        /// The score without the putting result: `score + sg`. Gaining strokes
        /// on the greens made the card better, so removing putting adds them
        /// back on.
        var scoreWithoutPutting: Double { score + sg }
    }

    let rounds: [Round]

    var avgScore: Double { mean(rounds.map(\.score)) }
    var avgScoreWithoutPutting: Double { mean(rounds.map(\.scoreWithoutPutting)) }

    var sdScore: Double { standardDeviation(rounds.map(\.score)) }
    var sdScoreWithoutPutting: Double { standardDeviation(rounds.map(\.scoreWithoutPutting)) }

    /// How the round-to-round swing would change with tour-average putting, in
    /// percent of the swing actually played. Negative means the scores would
    /// sit closer together — the putter is what makes the rounds differ.
    var spreadChangePercent: Double? {
        guard sdScore > 0.0001 else { return nil }
        return (sdScoreWithoutPutting - sdScore) / sdScore * 100
    }

    /// Below this there is no spread worth decomposing.
    static let minimumRounds = 3

    /// Grid values for the chart's scale: a round step that lands on whole
    /// strokes and leaves four or five lines, however wide the spread is. Par
    /// is always among them, since it's the line every score is read against.
    static func scaleTicks(low: Double, high: Double) -> [Double] {
        guard high > low else { return [0] }
        let candidates: [Double] = [1, 2, 3, 4, 5, 10, 15, 20, 25, 50]
        let rough = (high - low) / 4
        let step = candidates.first { $0 >= rough } ?? candidates.last!
        var ticks: [Double] = []
        var value = (low / step).rounded(.up) * step
        while value <= high, ticks.count < 12 {
            ticks.append(value)
            value += step
        }
        if low <= 0, high >= 0, !ticks.contains(where: { abs($0) < 0.0001 }) {
            ticks.append(0)
        }
        return ticks.sorted()
    }

    /// Rounds arrive newest-first; the chart reads left to right in time.
    static func make(rounds: [(date: Date, courseName: String, stats: RoundStats)]) -> ScorePuttingAnalysis? {
        let usable = rounds
            .filter { $0.stats.scoredHoles > 0 && $0.stats.holes > 0 }
            .sorted { $0.date < $1.date }
        guard usable.count >= minimumRounds else { return nil }

        // Rounds count as played — a 9-hole card is the 9 holes it was, not
        // half of an imagined 18.
        let mapped = usable.enumerated().map { index, r in
            Round(
                id: index,
                date: r.date,
                courseName: r.courseName,
                score: Double(r.stats.scoreRelativeToPar),
                sg: r.stats.sgTotal
            )
        }
        return ScorePuttingAnalysis(rounds: mapped)
    }
}

private func mean(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

/// Sample standard deviation — these are a handful of rounds out of many that
/// could have been played, not the whole population.
private func standardDeviation(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let m = mean(values)
    let sumSquares = values.reduce(0) { $0 + ($1 - m) * ($1 - m) }
    return (sumSquares / Double(values.count - 1)).squareRoot()
}
