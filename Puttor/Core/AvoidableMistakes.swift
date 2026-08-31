//
//  AvoidableMistakes.swift
//  Puttor
//
//  The two things that shouldn't happen: three putts from a distance the tour
//  two-putts, and a miss from where the ball goes in four times out of five.
//  Both are ordinary golf once in a while and a leak when they repeat, so they
//  are counted with what they cost.
//

import Foundation

struct AvoidableMistakes {
    /// Holes taking three putts or more from a distance where fewer than two
    /// putts are expected.
    var threePutts: Int = 0
    /// Strokes those holes cost against the tour's expectation.
    var threePuttStrokesLost: Double = 0

    /// Putts missed from where the tour holes at least four in five.
    var missedSureThings: Int = 0
    /// How many putts were faced from there at all.
    var sureThingAttempts: Int = 0
    /// The one that should have gone in most: its distance and the odds.
    var worstMissDistanceM: Double?
    var worstMissProbability: Double?

    var holes: Int = 0
    var hasAny: Bool { threePutts > 0 || missedSureThings > 0 }

    var sureThingMakePercent: Double {
        sureThingAttempts > 0
            ? Double(sureThingAttempts - missedSureThings) / Double(sureThingAttempts) * 100
            : 0
    }
}

enum AvoidableMistakeFinder {
    /// Four in five is the line: below it a miss is a putt, above it a miss is
    /// a stroke thrown away.
    static let sureThingProbability = 0.8
    /// A three-putt only counts as avoidable from where two putts is the
    /// expectation rather than the hope.
    static let expectedPuttsCeiling = 2.0

    /// Takes each round's putts separately — hole numbers repeat between
    /// rounds, and pooling them would invent three-putts that never happened.
    static func find(inRounds rounds: [[Putt]]) -> AvoidableMistakes {
        var result = AvoidableMistakes()

        for roundPutts in rounds {
            let holes = Set(roundPutts.map(\.holeNumber))
            for hole in holes {
                let onHole = roundPutts
                    .filter { $0.holeNumber == hole && $0.puttNumber > 0 }
                    .sorted { $0.puttNumber < $1.puttNumber }
                guard let first = onHole.first else { continue }
                result.holes += 1

                let expected = StrokesGained.baseline(at: first.distanceM).expectedPutts
                if onHole.count >= 3, expected < expectedPuttsCeiling {
                    result.threePutts += 1
                    result.threePuttStrokesLost += Double(onHole.count) - expected
                }
            }

            for putt in roundPutts where putt.puttNumber > 0 {
                let probability = StrokesGained.baseline(at: putt.distanceM).makeProbability
                guard probability >= sureThingProbability else { continue }
                result.sureThingAttempts += 1
                guard !putt.result.isHoled else { continue }

                result.missedSureThings += 1
                if probability > (result.worstMissProbability ?? 0) {
                    result.worstMissProbability = probability
                    result.worstMissDistanceM = putt.distanceM
                }
            }
        }

        return result
    }
}
