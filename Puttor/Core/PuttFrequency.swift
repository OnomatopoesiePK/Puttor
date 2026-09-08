//
//  PuttFrequency.swift
//  Puttor
//
//  How often a putt of a given length actually turns up in a round. Without
//  this, a drill result is a percentage with nothing behind it: holing 60%
//  from 1 m and 60% from 8 m are worth wildly different amounts over eighteen
//  holes, because one of them comes up ten times a round and the other twice.
//
//  The distribution below is an estimate of a club player's round — around 32
//  putts, most of them short — not a measurement of any one player. It is used
//  only to turn a drill's edge over the tour into strokes a round, which is an
//  order-of-magnitude answer rather than a precise one.
//

import Foundation

enum PuttFrequency {
    /// Putts per 18-hole round falling in each band.
    static let bands: [(min: Double, max: Double, putts: Double)] = [
        (0, 0.5, 6.0),
        (0.5, 1, 4.0),
        (1, 2, 4.5),
        (2, 3, 3.2),
        (3, 4, 2.4),
        (4, 5, 1.9),
        (5, 6, 1.6),
        (6, 7, 1.3),
        (7, 9, 2.0),
        (9, 12, 2.1),
        (12, 15, 1.3),
        (15, 20, 1.0),
        (20, 30, 0.6),
    ]

    /// Every putt of a round, by this estimate — near enough to the 32 a club
    /// player takes.
    static var puttsPerRound: Double { bands.reduce(0) { $0 + $1.putts } }

    /// How many putts a round land within `window` of `distance`, both sides
    /// counted. A drill at 2 m answers for everything from 1.5 m to 2.5 m,
    /// which is the range it actually trains.
    static func puttsPerRound(around distance: Double, window: Double = 0.5) -> Double {
        let lower = max(0, distance - window)
        let upper = distance + window
        guard upper > lower else { return 0 }

        return bands.reduce(0.0) { total, band in
            let overlap = min(upper, band.max) - max(lower, band.min)
            guard overlap > 0 else { return total }
            let width = band.max - band.min
            // Spread evenly inside the band: finer than that would be inventing
            // detail the estimate doesn't have.
            return total + band.putts * (overlap / width)
        }
    }
}
