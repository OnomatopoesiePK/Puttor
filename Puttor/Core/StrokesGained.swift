//
//  StrokesGained.swift
//  Puttor
//
//  PGA Tour strokes-gained putting baseline (Mark Broadie methodology).
//  Ported 1:1 from the PuttTrack prototype's data/strokesGained.ts + utils/sgCalculator.ts.
//

import Foundation

struct SGBaseline {
    let distanceM: Double
    let makeProbability: Double // 0...1
    let expectedPutts: Double   // average putts to hole out from this distance
}

enum StrokesGained {
    static let tourBaseline: [SGBaseline] = [
        SGBaseline(distanceM: 0.3, makeProbability: 0.990, expectedPutts: 1.010),
        SGBaseline(distanceM: 0.5, makeProbability: 0.985, expectedPutts: 1.015),
        SGBaseline(distanceM: 0.6, makeProbability: 0.975, expectedPutts: 1.025),
        SGBaseline(distanceM: 0.9, makeProbability: 0.950, expectedPutts: 1.050),
        SGBaseline(distanceM: 1.0, makeProbability: 0.930, expectedPutts: 1.075),
        SGBaseline(distanceM: 1.2, makeProbability: 0.900, expectedPutts: 1.105),
        SGBaseline(distanceM: 1.5, makeProbability: 0.840, expectedPutts: 1.170),
        SGBaseline(distanceM: 1.8, makeProbability: 0.760, expectedPutts: 1.248),
        SGBaseline(distanceM: 2.0, makeProbability: 0.700, expectedPutts: 1.310),
        SGBaseline(distanceM: 2.5, makeProbability: 0.580, expectedPutts: 1.432),
        SGBaseline(distanceM: 3.0, makeProbability: 0.470, expectedPutts: 1.545),
        SGBaseline(distanceM: 3.5, makeProbability: 0.380, expectedPutts: 1.635),
        SGBaseline(distanceM: 4.0, makeProbability: 0.310, expectedPutts: 1.705),
        SGBaseline(distanceM: 4.5, makeProbability: 0.260, expectedPutts: 1.755),
        SGBaseline(distanceM: 5.0, makeProbability: 0.220, expectedPutts: 1.795),
        SGBaseline(distanceM: 6.0, makeProbability: 0.165, expectedPutts: 1.847),
        SGBaseline(distanceM: 7.0, makeProbability: 0.125, expectedPutts: 1.884),
        SGBaseline(distanceM: 8.0, makeProbability: 0.095, expectedPutts: 1.912),
        SGBaseline(distanceM: 9.0, makeProbability: 0.075, expectedPutts: 1.930),
        SGBaseline(distanceM: 10.0, makeProbability: 0.060, expectedPutts: 1.944),
        SGBaseline(distanceM: 12.0, makeProbability: 0.045, expectedPutts: 1.957),
        SGBaseline(distanceM: 15.0, makeProbability: 0.032, expectedPutts: 1.970),
        SGBaseline(distanceM: 20.0, makeProbability: 0.022, expectedPutts: 1.980),
        SGBaseline(distanceM: 25.0, makeProbability: 0.016, expectedPutts: 1.985),
        SGBaseline(distanceM: 30.0, makeProbability: 0.012, expectedPutts: 1.990),
    ]

    static func baseline(at distanceM: Double) -> SGBaseline {
        guard let first = tourBaseline.first, let last = tourBaseline.last else {
            return SGBaseline(distanceM: distanceM, makeProbability: 0, expectedPutts: 2)
        }
        if distanceM <= first.distanceM { return first }
        if distanceM >= last.distanceM { return last }

        for i in 0..<(tourBaseline.count - 1) {
            let a = tourBaseline[i]
            let b = tourBaseline[i + 1]
            if distanceM >= a.distanceM && distanceM <= b.distanceM {
                let t = (distanceM - a.distanceM) / (b.distanceM - a.distanceM)
                return SGBaseline(
                    distanceM: distanceM,
                    makeProbability: a.makeProbability + t * (b.makeProbability - a.makeProbability),
                    expectedPutts: a.expectedPutts + t * (b.expectedPutts - a.expectedPutts)
                )
            }
        }
        return last
    }

    /// Typical leave distance after a miss (the remaining putt you're left with).
    private static func typicalLeave(_ distanceM: Double) -> Double {
        if distanceM <= 1.5 { return 0.3 }
        if distanceM <= 3.0 { return 0.5 }
        if distanceM <= 6.0 { return 0.7 }
        if distanceM <= 10.0 { return 0.9 }
        return 1.2
    }

    static func calculateSG(distanceM: Double, holed: Bool) -> Double {
        let base = baseline(at: distanceM)
        if holed {
            // SG = expected_putts_from_here - actual_putts_taken (1). Positive = gained vs tour average.
            return base.expectedPutts - 1
        } else {
            let leave = typicalLeave(distanceM)
            let leaveBaseline = baseline(at: leave)
            // SG = starting_expected - (1 putt used + remaining expected)
            return base.expectedPutts - (1 + leaveBaseline.expectedPutts)
        }
    }
}
