//
//  StrokesGained.swift
//  Puttor
//
//  PGA Tour strokes-gained putting baseline (Mark Broadie methodology).
//  The calculation follows the PuttTrack prototype's sgCalculator.ts. The
//  baseline itself was first recalibrated against published Tour figures and
//  then replaced by two fitted curves, so the app no longer interpolates
//  between table rows — see StrokesGained.baseline(at:).
//

import Foundation

struct SGBaseline {
    let distanceM: Double
    let makeProbability: Double // 0...1
    let expectedPutts: Double   // average putts to hole out from this distance
}

enum StrokesGained {
    /// PGA Tour putting baseline as a pair of closed-form curves.
    ///
    /// Both are functions of `x = ln(distance in metres)`, fitted by least
    /// squares to 25 anchor points calibrated against published Tour
    /// make-percentage and putts-to-hole-out figures:
    ///
    ///     make probability  p(d) = 1 / (1 + e^-f(x))
    ///     expected putts    E(d) = 1 + e^g(x)
    ///
    /// The logistic keeps p inside 0…1 and the exponential keeps E above 1,
    /// whatever the polynomials do, and both curves come out monotonic across
    /// the modelled range. The fit sits within 0.016 of the anchors on make
    /// probability and within 0.01 of a stroke on expected putts — closer than
    /// the anchors themselves are known.
    ///
    /// `expectedPutts` passes 2 at about 9 m: from that range three-putts are
    /// common enough that the average is no longer two, and capping it there
    /// would treat every long lag as a guaranteed two-putt.
    private static let makeCoefficients: [Double] = [
        0.020498, -0.143461, 0.216629, 0.544835, -3.466532, 2.659407,
    ]
    private static let expectedPuttsCoefficients: [Double] = [
        -0.048471, 0.495248, -1.874888, 3.421815, -2.596229,
    ]

    /// Outside this range the polynomials leave the data they were fitted to,
    /// so the distance is clamped before they see it.
    static let shortestModelledDistanceM = 0.3
    static let longestModelledDistanceM = 30.0

    static func baseline(at distanceM: Double) -> SGBaseline {
        let clamped = min(max(distanceM, shortestModelledDistanceM), longestModelledDistanceM)
        let x = log(clamped)
        let make = 1 / (1 + exp(-polynomial(makeCoefficients, x)))
        return SGBaseline(
            distanceM: distanceM,
            // A tap-in is never a certainty and a 30m putt is never hopeless.
            makeProbability: min(0.999, max(0.001, make)),
            expectedPutts: 1 + exp(polynomial(expectedPuttsCoefficients, x))
        )
    }

    /// Horner's method: c₀xⁿ + c₁xⁿ⁻¹ + … + cₙ, highest power first.
    private static func polynomial(_ coefficients: [Double], _ x: Double) -> Double {
        coefficients.reduce(0) { $0 * x + $1 }
    }

    /// The distances the reference table lists — the same anchors the curves
    /// were fitted to, now read off the curves themselves.
    static let referenceDistancesM: [Double] = [
        0.3, 0.5, 0.6, 0.8, 1.0, 1.2, 1.5, 1.8, 2.0, 2.5, 3.0, 3.5, 4.0,
        4.5, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 15.0, 20.0, 25.0, 30.0,
    ]

    static let tourBaseline: [SGBaseline] = referenceDistancesM.map { baseline(at: $0) }

    /// Typical leave distance after a miss, used only while the follow-up putt
    /// hasn't been recorded yet — once it exists, its real distance is used.
    static func typicalLeave(_ distanceM: Double) -> Double {
        if distanceM <= 1.5 { return 0.3 }
        if distanceM <= 3.0 { return 0.5 }
        if distanceM <= 6.0 { return 0.7 }
        if distanceM <= 10.0 { return 0.9 }
        return 1.2
    }

    /// Strokes gained for a single putt: the expected putts you faced, less the
    /// one you used, less the expected putts you left behind.
    ///
    /// `nextDistanceM` is the distance of the following putt on the hole, or nil
    /// if this one went in. Chaining putts on their real distances is what makes
    /// a hole add up: the terms cancel, so the whole hole comes to
    /// `expectedPutts(first distance) - number of putts`. Guessing the leave
    /// instead breaks that — a three-putt from 30m came out slightly positive,
    /// because the guess credited a tidy lag that never happened.
    static func calculateSG(distanceM: Double, nextDistanceM: Double?) -> Double {
        let faced = baseline(at: distanceM).expectedPutts
        let left = nextDistanceM.map { baseline(at: $0).expectedPutts } ?? 0
        return faced - 1 - left
    }

    /// Provisional value for a putt whose follow-up hasn't been entered yet, so
    /// the save confirmation can show something immediately. Replaced with the
    /// chained value as soon as the next putt is recorded.
    static func calculateSG(distanceM: Double, holed: Bool) -> Double {
        calculateSG(distanceM: distanceM, nextDistanceM: holed ? nil : typicalLeave(distanceM))
    }
}
