//
//  MissGrid.swift
//  Puttor
//
//  Where the missed putts finished, as shares of a grid: four rows by how far
//  past or short of the hole the ball came to rest, four columns by how far to
//  the side. The two inner columns of a row reach only as far sideways as the
//  row itself does — 60 cm level with the hole and beyond it, 30 cm in front
//  of it — so they hold only the putts that still had a chance or were gimmes
//  anyway; everything further out is a far miss. A miss recorded without an
//  angle only says roughly where the ball went, so it is split evenly.
//

import Foundation

enum MissGridCell: String, CaseIterable {
    case longFarLeft, longLeft, longRight, longFarRight
    case justPastFarLeft, justPastLeft, justPastRight, justPastFarRight
    case justShortFarLeft, justShortLeft, justShortRight, justShortFarRight
    case wayShortFarLeft, wayShortLeft, wayShortRight, wayShortFarRight
}

/// How far past or short the ball finished, top row first.
enum MissGridRow: Int, CaseIterable {
    case long, justPast, justShort, wayShort

    /// How far to the side this row's inner fields reach.
    var sideLimitM: Double {
        self == .long || self == .justPast ? MissGrid.justPastM : MissGrid.justShortM
    }

    var cells: [MissGridCell] {
        [cell(side: -1, far: true), cell(side: -1, far: false), cell(side: 1, far: false), cell(side: 1, far: true)]
    }

    func cell(side: Int, far: Bool) -> MissGridCell {
        let left = side < 0
        switch self {
        case .long:
            return far ? (left ? .longFarLeft : .longFarRight) : (left ? .longLeft : .longRight)
        case .justPast:
            return far ? (left ? .justPastFarLeft : .justPastFarRight) : (left ? .justPastLeft : .justPastRight)
        case .justShort:
            return far ? (left ? .justShortFarLeft : .justShortFarRight) : (left ? .justShortLeft : .justShortRight)
        case .wayShort:
            return far ? (left ? .wayShortFarLeft : .wayShortFarRight) : (left ? .wayShortLeft : .wayShortRight)
        }
    }
}

struct MissGrid {
    /// Level with the hole or past it, up to this: just past — a ball that had
    /// its chance. Also how far to the side those rows' inner fields reach.
    static let justPastM = 0.6
    /// Up to this short: just short, near enough to be given.
    static let justShortM = 0.3
    /// A corner miss out of the eight sectors runs at 45°, so it lies this
    /// much of its leave to the side and the same again short or past.
    private static let diagonal = 0.5.squareRoot()
    private static let epsilon = 0.0001

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
            for (cell, weight) in Self.cells(for: putt.result, leave: leave, angle: putt.missAngleDeg) {
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
    static func cells(for result: PuttResult, leave: Double, angle: Double? = nil) -> [(MissGridCell, Double)] {
        if case .holed = result { return [] }

        // The dial says exactly where the ball lay: how far to the side, and
        // how far past or short, follow from the angle and the leave.
        if let angle {
            let radians = angle * .pi / 180
            return place(across: leave * sin(radians), along: -leave * cos(radians))
        }

        switch result {
        case .holed, .missedGeneric:
            // Nothing says which way this one went.
            return []
        case .short:
            return place(across: 0, along: -leave)
        case .long:
            return place(across: 0, along: leave)
        case .holeHigh:
            return place(across: 0, along: leave * 0.55)
        case .left, .right:
            // Straight beside the hole: half of it level with the hole, half
            // just in front of it, each read against its own row.
            let across = (result == .left ? -1 : 1) * leave
            return place(row: .justPast, across: across, weight: 0.5)
                + place(row: .justShort, across: across, weight: 0.5)
        case .shortLeft:
            return place(across: -leave * diagonal, along: -leave * diagonal)
        case .shortRight:
            return place(across: leave * diagonal, along: -leave * diagonal)
        case .longLeft:
            return place(across: -leave * diagonal, along: leave * diagonal)
        case .longRight:
            return place(across: leave * diagonal, along: leave * diagonal)
        }
    }

    /// The row a ball this far past (negative: short) of the hole lands in.
    /// Level with the hole counts as past — a ball that got there.
    static func row(along: Double) -> MissGridRow {
        if along > justPastM + epsilon { return .long }
        if along >= -epsilon { return .justPast }
        if along >= -(justShortM + epsilon) { return .justShort }
        return .wayShort
    }

    private static func place(across: Double, along: Double, weight: Double = 1) -> [(MissGridCell, Double)] {
        place(row: row(along: along), across: across, weight: weight)
    }

    /// One miss into its field, or — where nothing says which side it went —
    /// halved between the two sides of its row.
    private static func place(row: MissGridRow, across: Double, weight: Double = 1) -> [(MissGridCell, Double)] {
        guard abs(across) > epsilon else {
            return [(row.cell(side: -1, far: false), weight / 2), (row.cell(side: 1, far: false), weight / 2)]
        }
        let far = abs(across) > row.sideLimitM + epsilon
        return [(row.cell(side: across < 0 ? -1 : 1, far: far), weight)]
    }
}
