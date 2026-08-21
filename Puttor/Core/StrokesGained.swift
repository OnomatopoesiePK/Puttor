//
//  StrokesGained.swift
//  Puttor
//
//  PGA Tour strokes-gained putting baseline (Mark Broadie methodology).
//  The calculation follows the PuttTrack prototype's sgCalculator.ts; the
//  baseline table itself has since been recalibrated against published Tour
//  figures, so it no longer matches the prototype's numbers.
//

import Foundation

struct SGBaseline {
    let distanceM: Double
    let makeProbability: Double // 0...1
    let expectedPutts: Double   // average putts to hole out from this distance
}

enum StrokesGained {
    /// PGA Tour putting baseline, calibrated against published make-percentage
    /// and putts-to-hole-out figures.
    ///
    /// `expectedPutts` deliberately rises past 2 beyond about 9 m: from that
    /// range three-putts are common enough that the average is no longer two,
    /// and capping it there would treat every long lag as a guaranteed
    /// two-putt — crediting good lag putting with nothing and barely
    /// penalising bad lag putting.
    static let tourBaseline: [SGBaseline] = [
        SGBaseline(distanceM: 0.3, makeProbability: 0.999, expectedPutts: 1.001),
        SGBaseline(distanceM: 0.5, makeProbability: 0.994, expectedPutts: 1.006),
        SGBaseline(distanceM: 0.6, makeProbability: 0.990, expectedPutts: 1.010),
        SGBaseline(distanceM: 0.8, makeProbability: 0.971, expectedPutts: 1.029),
        SGBaseline(distanceM: 1.0, makeProbability: 0.938, expectedPutts: 1.065),
        SGBaseline(distanceM: 1.2, makeProbability: 0.885, expectedPutts: 1.124),
        SGBaseline(distanceM: 1.5, makeProbability: 0.779, expectedPutts: 1.222),
        SGBaseline(distanceM: 1.8, makeProbability: 0.698, expectedPutts: 1.311),
        SGBaseline(distanceM: 2.0, makeProbability: 0.634, expectedPutts: 1.371),
        SGBaseline(distanceM: 2.5, makeProbability: 0.490, expectedPutts: 1.512),
        SGBaseline(distanceM: 3.0, makeProbability: 0.408, expectedPutts: 1.602),
        SGBaseline(distanceM: 3.5, makeProbability: 0.348, expectedPutts: 1.669),
        SGBaseline(distanceM: 4.0, makeProbability: 0.293, expectedPutts: 1.724),
        SGBaseline(distanceM: 4.5, makeProbability: 0.238, expectedPutts: 1.773),
        SGBaseline(distanceM: 5.0, makeProbability: 0.208, expectedPutts: 1.805),
        SGBaseline(distanceM: 6.0, makeProbability: 0.155, expectedPutts: 1.864),
        SGBaseline(distanceM: 7.0, makeProbability: 0.126, expectedPutts: 1.917),
        SGBaseline(distanceM: 8.0, makeProbability: 0.105, expectedPutts: 1.965),
        SGBaseline(distanceM: 9.0, makeProbability: 0.092, expectedPutts: 2.004),
        SGBaseline(distanceM: 10.0, makeProbability: 0.079, expectedPutts: 2.032),
        SGBaseline(distanceM: 12.0, makeProbability: 0.053, expectedPutts: 2.085),
        SGBaseline(distanceM: 15.0, makeProbability: 0.041, expectedPutts: 2.164),
        SGBaseline(distanceM: 20.0, makeProbability: 0.027, expectedPutts: 2.261),
        SGBaseline(distanceM: 25.0, makeProbability: 0.019, expectedPutts: 2.350),
        SGBaseline(distanceM: 30.0, makeProbability: 0.015, expectedPutts: 2.432),
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
