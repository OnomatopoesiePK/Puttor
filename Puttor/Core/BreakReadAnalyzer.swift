//
//  BreakReadAnalyzer.swift
//  Puttor
//
//  Reads the misses put down to the read or the aim against the break they
//  were struck on. The side a misread breaking putt missed on says whether
//  too little or too much break was played; the side a misread straight putt
//  missed on says which break was seen that was not there; the length of a
//  misread putt up or down a hill says whether the slope was under- or
//  overestimated. Each is read by break direction, by strength and by hill,
//  and a narrower reading only earns a sentence when it says more than the
//  broader one it sits inside.
//

import Foundation

/// How hard a putt breaks, in the steps of the slope grid.
enum BreakStrength: String, CaseIterable {
    case gentle, medium, strong

    static let mediumFromPct = 2.0
    static let strongFromPct = 3.0

    /// Nil for a putt that does not break.
    init?(sideSlopePct: Double) {
        let slope = abs(sideSlopePct)
        guard slope >= MissPatternFinder.breakingSlopePct else { return nil }
        if slope >= Self.strongFromPct {
            self = .strong
        } else if slope >= Self.mediumFromPct {
            self = .medium
        } else {
            self = .gentle
        }
    }
}

/// How the putts missed through one reason read on one kind of break.
struct BreakReadFinding: Identifiable {
    enum Reason: String, CaseIterable {
        case missRead, wrongAim
    }

    enum Outcome: String {
        /// Breaking putt, low side: too little break played.
        case under
        /// Breaking putt, high side: too much break played.
        case over
        /// Straight putt missed right: played as breaking right to left.
        case sawRightToLeft
        /// Straight putt missed left: played as breaking left to right.
        case sawLeftToRight
        case uphillUnder, uphillOver, downhillUnder, downhillOver
        /// Flat putt short or long: the pace was misjudged.
        case slower, faster
    }

    let reason: Reason
    let cellID: String
    let outcome: Outcome
    let count: Int
    let total: Int
    /// How far the putts behind the finding were struck from.
    var distances: [Double] = []

    /// The share of those putts the distance band has to hold.
    static let coreShare = 0.8

    var id: String { "\(reason.rawValue)-\(cellID)-\(outcome.rawValue)" }
    var percent: Int { MissReasonLinker.percent(count, of: total) }

    var text: String {
        String(
            format: L("read.sentence"),
            L("read.reason.\(reason.rawValue)"),
            L("read.cell.\(cellID)"),
            count, total, percent,
            L("read.outcome.\(reason.rawValue).\(outcome.rawValue)")
        )
    }

    /// The narrowest band of distances holding 80% of the putts behind the
    /// finding, rounded to whole putts: where the habit actually lives.
    var coreBand: (count: Int, from: Double, to: Double)? {
        let sorted = distances.sorted()
        guard !sorted.isEmpty else { return nil }
        let size = max(1, Int((Double(sorted.count) * Self.coreShare).rounded()))
        var best = (from: sorted[0], to: sorted[size - 1])
        for start in 0...(sorted.count - size) {
            let from = sorted[start]
            let to = sorted[start + size - 1]
            if to - from < best.to - best.from { best = (from, to) }
        }
        return (size, best.from, best.to)
    }

    func bandText(useFeet: Bool) -> String? {
        guard let band = coreBand else { return nil }
        let from = UnitConverter.formatDistance(band.from, useFeet: useFeet)
        let to = UnitConverter.formatDistance(band.to, useFeet: useFeet)
        return from == to
            ? String(format: L("read.bandSingle"), band.count, from)
            : String(format: L("read.band"), band.count, from, to)
    }
}

enum BreakReadAnalyzer {
    static let minimumSample = MissPatternFinder.minimumSubsetSample
    static let maximumFindings = 5

    private enum Axis { case side, length }

    /// One kind of putt, and how a miss on it reads.
    private struct Cell {
        let id: String
        let axis: Axis
        /// The broader cells this one sits inside.
        var parents: [String] = []
        let includes: (Putt) -> Bool
        let outcome: (Putt) -> BreakReadFinding.Outcome?
    }

    private static func sideOfBreak(_ putt: Putt) -> BreakReadFinding.Outcome? {
        guard putt.result.lateralBias != 0 else { return nil }
        let lowSide = (putt.sideSlopePct < 0 && putt.result.lateralBias < 0)
            || (putt.sideSlopePct > 0 && putt.result.lateralBias > 0)
        return lowSide ? .under : .over
    }

    /// Aimed right of a straight putt is aiming for a right-to-left break.
    private static func breakSeen(_ putt: Putt) -> BreakReadFinding.Outcome? {
        switch putt.result.lateralBias {
        case ..<0: return .sawLeftToRight
        case 1...: return .sawRightToLeft
        default: return nil
        }
    }

    private static func isStraight(_ putt: Putt) -> Bool {
        abs(putt.sideSlopePct) < MissPatternFinder.breakingSlopePct
    }

    /// Broader cells come before the ones inside them.
    private static let cells: [Cell] = {
        var cells = [
            Cell(id: "breaking", axis: .side, includes: { !isStraight($0) }, outcome: sideOfBreak),
        ]
        for strength in BreakStrength.allCases {
            cells.append(Cell(
                id: strength.rawValue, axis: .side, parents: ["breaking"],
                includes: { BreakStrength(sideSlopePct: $0.sideSlopePct) == strength },
                outcome: sideOfBreak
            ))
        }

        let directions: [(id: String, includes: (Putt) -> Bool)] = [
            ("rightToLeft", { $0.sideSlopePct <= -MissPatternFinder.breakingSlopePct }),
            ("leftToRight", { $0.sideSlopePct >= MissPatternFinder.breakingSlopePct }),
        ]
        for direction in directions {
            cells.append(Cell(id: direction.id, axis: .side, parents: ["breaking"], includes: direction.includes, outcome: sideOfBreak))
            for strength in BreakStrength.allCases {
                cells.append(Cell(
                    id: direction.id + strength.rawValue.capitalized, axis: .side,
                    parents: [direction.id, strength.rawValue],
                    includes: { direction.includes($0) && BreakStrength(sideSlopePct: $0.sideSlopePct) == strength },
                    outcome: sideOfBreak
                ))
            }
        }

        cells += [
            Cell(id: "straight", axis: .side, includes: isStraight, outcome: breakSeen),
            Cell(id: "straightUphill", axis: .side, parents: ["straight"], includes: { isStraight($0) && $0.hillSlopePct > 0 }, outcome: breakSeen),
            Cell(id: "straightDownhill", axis: .side, parents: ["straight"], includes: { isStraight($0) && $0.hillSlopePct < 0 }, outcome: breakSeen),
            Cell(id: "straightFlat", axis: .side, parents: ["straight"], includes: { isStraight($0) && $0.hillSlopePct == 0 }, outcome: breakSeen),
            Cell(id: "uphill", axis: .length, includes: { $0.hillSlopePct > 0 }, outcome: {
                switch $0.result.lengthBias {
                case ..<0: return .uphillUnder
                case 1...: return .uphillOver
                default: return nil
                }
            }),
            Cell(id: "downhill", axis: .length, includes: { $0.hillSlopePct < 0 }, outcome: {
                switch $0.result.lengthBias {
                case 1...: return .downhillUnder
                case ..<0: return .downhillOver
                default: return nil
                }
            }),
            Cell(id: "flat", axis: .length, includes: { $0.hillSlopePct == 0 }, outcome: {
                switch $0.result.lengthBias {
                case ..<0: return .slower
                case 1...: return .faster
                default: return nil
                }
            }),
        ]
        return cells
    }()

    // MARK: - Reading

    static func findings(in putts: [Putt]) -> [BreakReadFinding] {
        let misses = putts.filter { $0.puttNumber > 0 && !$0.result.isHoled }
        var found: [BreakReadFinding] = []

        for reason in BreakReadFinding.Reason.allCases {
            let reasoned = misses.filter { reason == .missRead ? $0.missRead : $0.wrongAim }
            guard reasoned.count >= minimumSample else { continue }

            // Every lean found, shown or not, so a narrower cell is always
            // measured against the broader one around it.
            var byCell: [String: BreakReadFinding] = [:]
            for cell in cells {
                // An aim is a line; how long the miss ran says nothing about it.
                if cell.axis == .length && reason == .wrongAim { continue }

                let read = reasoned.filter(cell.includes).compactMap { putt in
                    cell.outcome(putt).map { (outcome: $0, distance: putt.distanceM) }
                }
                guard read.count >= minimumSample else { continue }
                let counts = Dictionary(grouping: read, by: \.outcome).mapValues(\.count)
                guard let leading = counts.max(by: { $0.value < $1.value }) else { continue }

                let finding = BreakReadFinding(
                    reason: reason, cellID: cell.id, outcome: leading.key,
                    count: leading.value, total: read.count,
                    distances: read.filter { $0.outcome == leading.key }.map(\.distance)
                )
                guard finding.percent > MissPatternFinder.thresholdPercent else { continue }
                byCell[cell.id] = finding

                let repeatsParent = cell.parents.contains { parentID in
                    guard let parent = byCell[parentID] else { return false }
                    return parent.outcome == finding.outcome
                        && finding.percent < parent.percent + MissPatternFinder.standOutPoints
                }
                if !repeatsParent { found.append(finding) }
            }
        }

        // The best-evidenced are kept, then shown from the highest share down.
        return found
            .sorted {
                (MissReasonLinker.confidenceFloor($0.count, of: $0.total), $0.count)
                    > (MissReasonLinker.confidenceFloor($1.count, of: $1.total), $1.count)
            }
            .prefix(maximumFindings)
            .sorted { ($0.percent, $0.count) > ($1.percent, $1.count) }
    }
}
