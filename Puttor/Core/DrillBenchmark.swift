//
//  DrillBenchmark.swift
//  Puttor
//
//  What a drill result is worth on the course. A percentage on its own says
//  nothing — the tour holes 88% from 1.2 m and 18% from 5.5 m — so every
//  scored drill is put next to the tour's rate from the same distance, and the
//  gap is turned into strokes a round using how often putts of that length
//  come up.
//

import Foundation

struct DrillBenchmark {
    /// The distance the drill was played from — averaged where its attempts
    /// were played from several.
    let distanceM: Double
    let attempts: Int
    let made: Int
    /// The tour's make rate over the same attempts.
    let tourMakePct: Double
    /// Putts a round that land within half a metre of this distance.
    let puttsPerRound: Double

    var yourMakePct: Double { attempts > 0 ? Double(made) / Double(attempts) * 100 : 0 }
    /// Percentage points clear of the tour, either way.
    var edgePct: Double { yourMakePct - tourMakePct }
    /// What that edge is worth over eighteen holes: every putt holed above the
    /// tour's rate is a stroke, and this many of them come up in a round.
    var strokesPerRound: Double { edgePct / 100 * puttsPerRound }
}

enum DrillBenchmarkCalculator {
    /// A benchmark needs this many attempts before the percentage means much.
    static let minimumAttempts = 5

    static func benchmark(for session: GameSession) -> DrillBenchmark? {
        benchmark(for: [session])
    }

    /// Over several sessions of the same drill — what the last few weeks of it
    /// are worth, rather than one afternoon.
    static func benchmark(for sessions: [GameSession]) -> DrillBenchmark? {
        // Timed drills have no make rate to compare: they are finished or not.
        guard let first = sessions.first, !first.gameType.isTrainingDrill else { return nil }

        let attempts = sessions.flatMap(\.attempts).filter { $0.distanceM > 0 }
        if attempts.count >= minimumAttempts {
            let distance = attempts.reduce(0.0) { $0 + $1.distanceM } / Double(attempts.count)
            // The tour's rate over exactly these attempts, not over their
            // average distance: the curve bends, so the two differ.
            let tour = attempts.reduce(0.0) {
                $0 + StrokesGained.baseline(at: $1.distanceM).makeProbability
            } / Double(attempts.count) * 100
            return DrillBenchmark(
                distanceM: distance,
                attempts: attempts.count,
                made: attempts.filter(\.success).count,
                tourMakePct: tour,
                puttsPerRound: PuttFrequency.puttsPerRound(around: distance)
            )
        }

        // Drills counted in bulk rather than attempt by attempt still know the
        // distance they were set at.
        let distance = sessions.first(where: { $0.configDistanceM > 0 })?.configDistanceM ?? 0
        let total = sessions.reduce(0) { $0 + $1.attemptsTotal }
        guard distance > 0, total >= minimumAttempts else { return nil }

        return DrillBenchmark(
            distanceM: distance,
            attempts: total,
            made: sessions.reduce(0) { $0 + $1.madeTotal },
            tourMakePct: StrokesGained.baseline(at: distance).makeProbability * 100,
            puttsPerRound: PuttFrequency.puttsPerRound(around: distance)
        )
    }
}
