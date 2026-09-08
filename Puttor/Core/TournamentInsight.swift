//
//  TournamentInsight.swift
//  Puttor
//
//  Competition against practice. Unlike the conditions engine, nothing here is
//  filtered out for being too small to prove: a player wants to know what
//  their card says when it counts, whether that is better, worse or the same.
//  So this reports the average, the spread around it, and the rounds that sat
//  a long way from either — and says plainly how much is behind each number.
//

import Foundation

/// One set of rounds, summarised.
struct RoundGroupSummary {
    var count: Int = 0
    /// Strokes gained putting per round.
    var mean: Double = 0
    /// Population standard deviation of that: how far a round typically sits
    /// from the average, which is the difference between a player who is
    /// reliable and one who is merely good on their day.
    var standardDeviation: Double = 0
    var best: RoundPoint?
    var worst: RoundPoint?

    var hasEnoughForSpread: Bool { count >= 3 }
}

/// A single round, kept with what it scored.
struct RoundPoint: Identifiable {
    let id: UUID
    let date: Date
    let courseName: String
    let strokesGained: Double
    let isTournament: Bool
}

/// A round sitting far enough from its own group's average to be worth
/// naming — in either direction.
struct RoundOutlier: Identifiable {
    let point: RoundPoint
    /// Standard deviations from the mean of its own group, signed.
    let sigma: Double

    var id: UUID { point.id }
}

struct TournamentComparison {
    var tournament = RoundGroupSummary()
    var casual = RoundGroupSummary()
    var outliers: [RoundOutlier] = []

    /// Only worth showing once both kinds have been played.
    var hasBoth: Bool { tournament.count > 0 && casual.count > 0 }
    /// Tournament minus practice, in strokes a round.
    var meanDelta: Double { tournament.mean - casual.mean }
    /// Positive when competition rounds are the steadier ones.
    var spreadDelta: Double { casual.standardDeviation - tournament.standardDeviation }
}

enum TournamentInsight {
    /// Beyond this many standard deviations from its own group's average, a
    /// round is an outlier rather than a normal bad or good day.
    static let outlierSigma = 1.8
    /// A spread needs this many rounds behind it before it is quoted.
    static let minimumForSpread = 3
    static let maximumOutliers = 3

    static func compare(rounds: [Round]) -> TournamentComparison {
        let points = rounds
            .filter { !$0.putts.isEmpty }
            .map { round in
                RoundPoint(
                    id: round.id,
                    date: round.date,
                    courseName: round.courseName,
                    strokesGained: CoachAdvisor.roundStrokesGained(round),
                    isTournament: round.isTournament
                )
            }

        var comparison = TournamentComparison()
        let tournament = points.filter(\.isTournament)
        let casual = points.filter { !$0.isTournament }
        comparison.tournament = summarise(tournament)
        comparison.casual = summarise(casual)

        // Each group is measured against its own average: a tournament round
        // is only unusual next to other tournament rounds.
        comparison.outliers = (outliers(in: tournament, summary: comparison.tournament)
            + outliers(in: casual, summary: comparison.casual))
            .sorted { abs($0.sigma) > abs($1.sigma) }
            .prefix(maximumOutliers)
            .map { $0 }

        return comparison
    }

    private static func summarise(_ points: [RoundPoint]) -> RoundGroupSummary {
        guard !points.isEmpty else { return RoundGroupSummary() }

        let values = points.map(\.strokesGained)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)

        return RoundGroupSummary(
            count: points.count,
            mean: mean,
            standardDeviation: variance.squareRoot(),
            best: points.max { $0.strokesGained < $1.strokesGained },
            worst: points.min { $0.strokesGained < $1.strokesGained }
        )
    }

    private static func outliers(in points: [RoundPoint], summary: RoundGroupSummary) -> [RoundOutlier] {
        guard summary.count >= minimumForSpread, summary.standardDeviation > 0.01 else { return [] }
        return points.compactMap { point in
            let sigma = (point.strokesGained - summary.mean) / summary.standardDeviation
            guard abs(sigma) >= outlierSigma else { return nil }
            return RoundOutlier(point: point, sigma: sigma)
        }
    }
}
