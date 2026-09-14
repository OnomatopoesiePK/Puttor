//
//  MissGrid.swift
//  Puttor
//
//  Where the missed putts finished, as shares of a grid: left, centre and
//  right against long, just past, just short and short. Just past is anything
//  level with the hole or beyond it up to two feet — a ball that had its
//  chance; just short is anything up to a foot short, tap-ins included. There is no centre
//  column past the hole: a putt straight past it counts half left, half right.
//

import Foundation

enum MissGridCell: String, CaseIterable {
    case leftLong, leftJustPast, leftJustShort, leftShort
    case centreJustShort, centreShort
    case rightLong, rightJustPast, rightJustShort, rightShort
}

struct MissGrid {
    /// Up to this short is just short, a tap-in of exactly a foot included.
    static let justShortM = UnitConverter.feetToMetres(1)
    /// Up to this past is just past.
    static let justPastM = UnitConverter.feetToMetres(2)

    private(set) var weights: [MissGridCell: Double] = [:]
    private(set) var total: Double = 0

    /// Every miss with a putt after it on the same hole — the leave is how far
    /// that putt was — narrowed the way the dispersion plot beside it is.
    init(putts: [Putt], filter: DispersionFilter = .all, distanceRange: ClosedRange<Double>? = nil) {
        let leaves = MissLeave(putts)
        for putt in putts where putt.puttNumber > 0 && !putt.result.isHoled {
            guard includeByFilter(putt, filter) else { continue }
            if let distanceRange, !distanceRange.contains(putt.distanceM) { continue }
            guard let leave = leaves.leave(after: putt) else { continue }
            for (cell, weight) in Self.cells(for: putt.result, leave: leave) {
                weights[cell, default: 0] += weight
                total += weight
            }
        }
    }

    /// The share of the misses in a cell, 0 to 100; all of them add up to 100.
    func percent(_ cell: MissGridCell) -> Double {
        total > 0 ? (weights[cell] ?? 0) / total * 100 : 0
    }

    /// The cells a miss counts in, and how much of it each gets.
    static func cells(for result: PuttResult, leave: Double) -> [(MissGridCell, Double)] {
        let side: Int
        let short: Bool
        switch result {
        case .holed, .missedGeneric: return []
        case .short: side = 0; short = true
        case .shortLeft: side = -1; short = true
        case .shortRight: side = 1; short = true
        case .long, .holeHigh: side = 0; short = false
        case .left, .longLeft: side = -1; short = false
        case .right, .longRight: side = 1; short = false
        }

        if short {
            let justShort = leave <= justShortM + 0.0001
            switch side {
            case ..<0: return [(justShort ? .leftJustShort : .leftShort, 1)]
            case 0: return [(justShort ? .centreJustShort : .centreShort, 1)]
            default: return [(justShort ? .rightJustShort : .rightShort, 1)]
            }
        }

        // Level with the hole or past it: it had its chance.
        let justPast = leave <= justPastM + 0.0001
        let left: MissGridCell = justPast ? .leftJustPast : .leftLong
        let right: MissGridCell = justPast ? .rightJustPast : .rightLong
        switch side {
        case ..<0: return [(left, 1)]
        case 0: return [(left, 0.5), (right, 0.5)]
        default: return [(right, 1)]
        }
    }
}
