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
//  Both measures are carried, strokes gained and conversion gain, because they
//  answer different questions: one is what the hole cost, the other is what
//  each putt was worth against the odds of holing it.
//

import Foundation

/// One number over a set of rounds: where it sits and how far it moves.
struct MetricSummary {
    var mean: Double = 0
    /// Population standard deviation — how far a round typically sits from the
    /// average, which is the difference between a player who is reliable and
    /// one who is merely good on their day.
    var standardDeviation: Double = 0
}

/// One set of rounds, summarised.
struct RoundGroupSummary {
    var count: Int = 0
    var sg = MetricSummary()
    var pcg = MetricSummary()
    var best: RoundPoint?
    var worst: RoundPoint?

    var hasEnoughForSpread: Bool { count >= TournamentInsight.minimumForSpread }
}

/// A single round, kept with what it scored.
struct RoundPoint: Identifiable {
    let id: UUID
    let date: Date
    let courseName: String
    let strokesGained: Double
    let pcg: Double
    let isTournament: Bool
}

/// A round sitting far enough from its own set's average to be worth naming —
/// in either direction.
struct RoundOutlier: Identifiable {
    let point: RoundPoint
    /// Standard deviations from the mean of its own set, signed.
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
    var meanDelta: Double { tournament.sg.mean - casual.sg.mean }
    /// Positive when competition rounds are the steadier ones.
    var spreadDelta: Double { casual.sg.standardDeviation - tournament.sg.standardDeviation }
}

enum TournamentInsight {
    /// Beyond this many standard deviations from its own set's average, a
    /// round is an outlier rather than a normal bad or good day.
    static let outlierSigma = 1.8
    /// A spread needs this many rounds behind it before it is quoted.
    static let minimumForSpread = 3
    static let maximumOutliers = 3
    /// The most recent five of each kind. Enough for an average to settle,
    /// recent enough to be about the player they are now.
    static let roundsPerSide = 5

    static func compare(rounds: [Round]) -> TournamentComparison {
        let points = rounds
            .filter { !$0.putts.isEmpty }
            .sorted { $0.date > $1.date }
            .map { round in
                RoundPoint(
                    id: round.id,
                    date: round.date,
                    courseName: round.courseName,
                    strokesGained: CoachAdvisor.roundStrokesGained(round),
                    pcg: CoachAdvisor.roundPCG(round),
                    isTournament: round.isTournament
                )
            }

        let tournament = Array(points.filter(\.isTournament).prefix(roundsPerSide))
        let casual = Array(points.filter { !$0.isTournament }.prefix(roundsPerSide))

        var comparison = TournamentComparison()
        comparison.tournament = summarise(tournament)
        comparison.casual = summarise(casual)

        // Each set is measured against its own average — a round that counted
        // is unusual next to the other rounds that counted, not next to a
        // practice round.
        comparison.outliers = (outliers(in: tournament, summary: comparison.tournament)
            + outliers(in: casual, summary: comparison.casual))
            .sorted { abs($0.sigma) > abs($1.sigma) }
            .prefix(maximumOutliers)
            .map { $0 }

        return comparison
    }

    private static func summarise(_ points: [RoundPoint]) -> RoundGroupSummary {
        guard !points.isEmpty else { return RoundGroupSummary() }

        return RoundGroupSummary(
            count: points.count,
            sg: summarise(points.map(\.strokesGained)),
            pcg: summarise(points.map(\.pcg)),
            best: points.max { $0.strokesGained < $1.strokesGained },
            worst: points.min { $0.strokesGained < $1.strokesGained }
        )
    }

    private static func summarise(_ values: [Double]) -> MetricSummary {
        guard !values.isEmpty else { return MetricSummary() }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return MetricSummary(mean: mean, standardDeviation: variance.squareRoot())
    }

    private static func outliers(in points: [RoundPoint], summary: RoundGroupSummary) -> [RoundOutlier] {
        guard summary.count >= minimumForSpread, summary.sg.standardDeviation > 0.01 else { return [] }
        return points.compactMap { point in
            let sigma = (point.strokesGained - summary.sg.mean) / summary.sg.standardDeviation
            guard abs(sigma) >= outlierSigma else { return nil }
            return RoundOutlier(point: point, sigma: sigma)
        }
    }
}
