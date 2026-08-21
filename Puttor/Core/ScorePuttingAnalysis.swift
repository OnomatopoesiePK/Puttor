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
        /// Strokes over par, scaled to 18 holes.
        let score: Double
        /// Strokes gained putting, scaled to 18 holes.
        let sg: Double
        /// The score without the putting result: `score + sg`. Gaining strokes
        /// on the greens made the card better, so removing putting adds them
        /// back on.
        var scoreWithoutPutting: Double { score + sg }
    }

    let rounds: [Round]

    var avgScore: Double { mean(rounds.map(\.score)) }
    var avgScoreWithoutPutting: Double { mean(rounds.map(\.scoreWithoutPutting)) }
    var avgSG: Double { mean(rounds.map(\.sg)) }

    var sdScore: Double { standardDeviation(rounds.map(\.score)) }
    var sdScoreWithoutPutting: Double { standardDeviation(rounds.map(\.scoreWithoutPutting)) }

    /// How much of the swing between good and bad rounds putting accounts for.
    ///
    /// A score is its non-putting half minus what putting gained, so the two
    /// covariances with the score add up to the score's own variance. Dividing
    /// through gives two shares that sum to exactly 1 — no leftover term to
    /// explain away. Nil when every round scored the same, which leaves no
    /// swing to attribute.
    var puttingShareOfVariance: Double? {
        let scores = rounds.map(\.score)
        let variance = covariance(scores, scores)
        guard variance > 1e-9 else { return nil }
        return covariance(scores, rounds.map { -$0.sg }) / variance
    }

    /// Squeezed into 0…1 for drawing: a share can overshoot when putting and
    /// the long game pull against each other, and a bar can't show that.
    var puttingShareForDisplay: Double? {
        puttingShareOfVariance.map { min(1, max(0, $0)) }
    }

    enum Verdict { case putting, mixed, rest }

    var verdict: Verdict? {
        guard let share = puttingShareOfVariance else { return nil }
        if share >= 0.6 { return .putting }
        if share <= 0.4 { return .rest }
        return .mixed
    }

    /// How far a round typically strays from the average, in strokes. Plain
    /// average distance rather than a standard deviation: it answers "how far
    /// off is a normal round" without asking the reader to know what sigma is.
    var typicalDeviation: Double { meanAbsoluteDeviation(rounds.map(\.score)) }

    /// The band most rounds land in — the average give or take that deviation.
    var typicalRange: (low: Double, high: Double) {
        let m = avgScore
        let d = typicalDeviation
        return (m - d, m + d)
    }

    enum StabilityTrend { case settling, steady, spreading }

    /// Whether the recent half of the rounds sits closer together than the
    /// earlier half. Needs enough rounds that each half is more than a pair.
    var stabilityTrend: StabilityTrend? {
        guard rounds.count >= Self.minimumRoundsForTrend else { return nil }
        let scores = rounds.map(\.score)
        let split = scores.count / 2
        let earlier = Array(scores.prefix(split))
        let recent = Array(scores.suffix(scores.count - split))

        let earlierSpread = meanAbsoluteDeviation(earlier)
        let recentSpread = meanAbsoluteDeviation(recent)

        // Both halves flat means the score is as settled as it gets.
        if earlierSpread < 0.25 && recentSpread < 0.25 { return .steady }
        guard earlierSpread > 0.0001 else { return .spreading }

        let ratio = recentSpread / earlierSpread
        if ratio <= 0.7 { return .settling }
        if ratio >= 1.4 { return .spreading }
        return .steady
    }

    /// Below this there is no spread worth decomposing.
    static let minimumRounds = 3
    /// Below this, splitting the rounds in half leaves too little on each side
    /// to compare.
    static let minimumRoundsForTrend = 6

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

        // 9- and 18-hole rounds have to be put on one scale before their
        // scores can be averaged together.
        let mapped = usable.enumerated().map { index, r in
            Round(
                id: index,
                date: r.date,
                courseName: r.courseName,
                score: Double(r.stats.scoreRelativeToPar) * 18 / Double(r.stats.scoredHoles),
                sg: r.stats.sgTotal * 18 / Double(r.stats.holes)
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

/// Average distance from the mean — the readable cousin of a standard
/// deviation, and less thrown off by one blow-up round.
private func meanAbsoluteDeviation(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let m = mean(values)
    return mean(values.map { abs($0 - m) })
}

private func covariance(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, a.count > 1 else { return 0 }
    let ma = mean(a), mb = mean(b)
    let sum = zip(a, b).reduce(0.0) { $0 + ($1.0 - ma) * ($1.1 - mb) }
    return sum / Double(a.count - 1)
}
