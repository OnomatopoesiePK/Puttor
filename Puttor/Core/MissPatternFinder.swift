//
//  MissPatternFinder.swift
//  Puttor
//
//  Reads the misses for habits worth saying out loud: a side they keep going,
//  a length they keep coming up, a break they keep missing below. Every
//  finding carries the count it rests on, because "six of ten" is a habit and
//  "one of one" is a bad putt.
//

import Foundation

struct MissPattern: Identifiable {
    /// Localisation key taking the count, the total and the percent, in that
    /// order.
    let key: String
    let count: Int
    let total: Int
    /// The reason most of the putts behind the habit share, where one stands
    /// out from the rest of the misses.
    var cause: MissCauseNote? = nil
    /// How far the putts that went the leading way were struck from.
    var distances: [Double] = []
    /// For an exception worth naming from a lower share than a habit: named
    /// once it reaches this percent.
    var alertPercent: Int? = nil
    /// What the putts behind the finding left, where that is its point.
    var leaves: [Double] = []

    var id: String { key }
    var share: Double { total > 0 ? Double(count) / Double(total) : 0 }
    var percent: Int { Int((share * 100).rounded()) }
    /// Past the threshold, judged on the percent the sentence shows, so a lean
    /// printed as "60%" is never called a habit. An exception has its own,
    /// lower bar.
    var isStrong: Bool {
        if let alertPercent { return percent >= alertPercent }
        return percent > MissPatternFinder.thresholdPercent
    }

    /// The lowest share the misses plausibly lean by (Wilson, 95%). Ranks a
    /// clear lean over many putts above a perfect one over a handful.
    var confidenceFloor: Double { MissReasonLinker.confidenceFloor(count, of: total) }
}

enum MissPatternFinder {
    /// A habit has to show up in enough putts to be one. Below these counts a
    /// run of misses is just a run of misses.
    static let minimumSample = 8
    static let minimumSubsetSample = 6
    /// More than this share going the same way is a habit; anything at or
    /// below it is left unsaid.
    static let thresholdPercent = 60
    /// No more than this, however many habits there are.
    static let maximumFindings = 5
    /// A slice of the misses only earns its own sentence when it leans this
    /// many points further than all the misses together already do.
    static let standOutPoints = 10

    /// Two exceptions are named from a far lower share than a habit: a miss
    /// short from close in never had a chance to drop, and a lag left outside
    /// a metre is a three-putt waiting to happen. Both are kept on the list
    /// whatever else is on it.
    static let alertPercent = 30
    static let shortAlertDistanceM = 3.0
    static let lagDistanceM = 8.0

    /// Long putts, where distance control is the thing being tested, and short
    /// ones, where the line is.
    static let longPuttDistanceM = 6.0
    static let shortPuttDistanceM = 1.5
    /// Splits the range between them into 1.5–3 m and 3–6 m.
    static let midPuttDistanceM = 3.0
    /// Below this the green is flat enough that "high side" means nothing.
    static let breakingSlopePct = 1.0

    /// The same break directions and hills the dispersion menu offers, plus
    /// straight putts and the two middle distance bands, each read on its own.
    private static let slices: [(name: String, includes: (Putt) -> Bool)] = [
        ("rightToLeft", { $0.sideSlopePct < 0 }),
        ("leftToRight", { $0.sideSlopePct > 0 }),
        ("straight", { $0.sideSlopePct == 0 }),
        ("uphill", { $0.hillSlopePct > 0 }),
        ("downhill", { $0.hillSlopePct < 0 }),
        ("band15to3", { $0.distanceM > MissPatternFinder.shortPuttDistanceM && $0.distanceM < MissPatternFinder.midPuttDistanceM }),
        ("band3to6", { $0.distanceM >= MissPatternFinder.midPuttDistanceM && $0.distanceM < MissPatternFinder.longPuttDistanceM }),
    ]

    private enum Axis { case side, length }

    private struct Lean {
        let pattern: MissPattern
        /// Nil for a lean that has no whole-green counterpart to repeat.
        let axis: Axis?
        /// -1 left or short, +1 right or long.
        let direction: Int
        /// The misses that went the leading way.
        let putts: [Putt]
    }

    static func findings(in putts: [Putt]) -> [MissPattern] {
        let misses = putts.filter { $0.puttNumber > 0 && !$0.result.isHoled }
        guard !misses.isEmpty else { return [] }
        // Read from every putt, holed ones included: the leave of a miss is
        // the distance of whatever came next.
        let leave = MissLeave(putts)

        // Which side of the hole and which length, over everything.
        let overall = [
            sideLean(in: misses, leftKey: "pattern.missLeft", rightKey: "pattern.missRight", minimum: minimumSample),
            lengthLean(leave: leave, in:misses, shortKey: "pattern.missShort", longKey: "pattern.missLong", minimum: minimumSample),
        ].compactMap { $0 }

        var slices: [Lean?] = []

        // On a breaking putt, below the hole is the miss that never had a
        // chance; above it at least died towards the cup.
        let breaking = misses.filter {
            abs($0.sideSlopePct) >= breakingSlopePct && $0.result.lateralBias != 0
        }
        slices.append(lean(
            in: breaking,
            first: { putt in
                // Low side: the ball missed the way the green was falling.
                (putt.sideSlopePct < 0 && putt.result.lateralBias < 0)
                    || (putt.sideSlopePct > 0 && putt.result.lateralBias > 0)
            },
            firstKey: "pattern.missLowSide",
            secondKey: "pattern.missHighSide",
            minimum: minimumSubsetSample,
            axis: nil
        ))

        // Each break direction and each hill: side and length.
        for slice in Self.slices {
            let subset = misses.filter(slice.includes)
            let prefix = "pattern.\(slice.name)"
            slices.append(sideLean(in: subset, leftKey: "\(prefix).left", rightKey: "\(prefix).right", minimum: minimumSubsetSample))
            slices.append(lengthLean(leave: leave, in:subset, shortKey: "\(prefix).short", longKey: "\(prefix).long", minimum: minimumSubsetSample))
        }

        // Distance control from range, and line from close in.
        slices.append(lengthLean(
            leave: leave,
            in: misses.filter { $0.distanceM >= longPuttDistanceM },
            shortKey: "pattern.longPuttsShort",
            longKey: "pattern.longPuttsLong",
            minimum: minimumSubsetSample
        ))
        slices.append(sideLean(
            in: misses.filter { $0.distanceM <= shortPuttDistanceM },
            leftKey: "pattern.shortPuttsLeft",
            rightKey: "pattern.shortPuttsRight",
            minimum: minimumSubsetSample
        ))

        let standingOut = slices.compactMap { $0 }.filter { standsOut($0, against: overall) }
        let tracked = MissReasonLinker.trackedMisses(in: misses)

        let alerts = [shortFromClose(misses), lagOutsideAMetre(putts, leave: leave)].compactMap { $0 }
        let shortAlert = alerts.contains { $0.pattern.key == "pattern.shortInside3m" }

        // Only habits. The most certain ones are kept, so a perfect lean over a
        // handful of putts cannot push out a clear one over many; the alerts
        // keep their places ahead of them. Everything is then shown from the
        // highest share down, each with the reason behind it where one stands
        // out.
        let habits = (overall + standingOut)
            .filter { $0.pattern.isStrong }
            // Short from 1.5 to 3 m says less than the alert over the same putts.
            .filter { !(shortAlert && $0.pattern.key == "pattern.band15to3.short") }
            .sorted { ($0.pattern.confidenceFloor, $0.pattern.count) > ($1.pattern.confidenceFloor, $1.pattern.count) }
            .prefix(max(0, maximumFindings - alerts.count))

        return (alerts + habits)
            .map { lean in
                var pattern = lean.pattern
                pattern.cause = MissReasonLinker.cause(behind: lean.putts, among: tracked)
                pattern.distances = lean.putts.map(\.distanceM)
                return pattern
            }
            .sorted { ($0.percent, $0.count) > ($1.percent, $1.count) }
    }

    /// Misses from inside 3 m that finished short, over every miss from there.
    private static func shortFromClose(_ misses: [Putt]) -> Lean? {
        let close = misses.filter { $0.distanceM < shortAlertDistanceM }
        guard close.count >= minimumSubsetSample else { return nil }
        let short = close.filter { $0.result.lengthBias < 0 }
        var pattern = MissPattern(key: "pattern.shortInside3m", count: short.count, total: close.count)
        pattern.alertPercent = alertPercent
        guard pattern.isStrong else { return nil }
        return Lean(pattern: pattern, axis: nil, direction: -1, putts: short)
    }

    /// Putts from 8 m and further that left more than a metre, over every one
    /// of them whose outcome is known — holed, or followed by another putt.
    private static func lagOutsideAMetre(_ putts: [Putt], leave: MissLeave) -> Lean? {
        let lags = putts.filter {
            $0.puttNumber > 0 && $0.distanceM >= lagDistanceM
                && ($0.result.isHoled || leave.leave(after: $0) != nil)
        }
        guard lags.count >= minimumSubsetSample else { return nil }
        let outside = lags.filter { (leave.leave(after: $0) ?? 0) > MissLeave.settledLongM }
        var pattern = MissPattern(key: "pattern.lagOutsideMetre", count: outside.count, total: lags.count)
        pattern.alertPercent = alertPercent
        pattern.leaves = outside.compactMap { leave.leave(after: $0) }
        guard pattern.isStrong else { return nil }
        return Lean(pattern: pattern, axis: nil, direction: 1, putts: outside)
    }

    /// "Uphill, 80% go left" says nothing new when 80% of all misses go left.
    private static func standsOut(_ slice: Lean, against overall: [Lean]) -> Bool {
        guard let axis = slice.axis,
              let whole = overall.first(where: { $0.axis == axis && $0.direction == slice.direction && $0.pattern.isStrong })
        else { return true }
        return slice.pattern.percent >= whole.pattern.percent + standOutPoints
    }

    private static func sideLean(in putts: [Putt], leftKey: String, rightKey: String, minimum: Int) -> Lean? {
        lean(
            in: putts.filter { $0.result.lateralBias != 0 },
            first: { $0.result.lateralBias < 0 },
            firstKey: leftKey,
            secondKey: rightKey,
            minimum: minimum,
            axis: .side
        )
    }

    /// A putt that slid past but stopped within a metre had the pace, so only
    /// a longer leave counts as long.
    private static func lengthLean(leave: MissLeave, in putts: [Putt], shortKey: String, longKey: String, minimum: Int) -> Lean? {
        lean(
            in: putts.filter { leave.lengthBias($0) != 0 },
            first: { leave.lengthBias($0) < 0 },
            firstKey: shortKey,
            secondKey: longKey,
            minimum: minimum,
            axis: .length
        )
    }

    /// One two-sided test: which way does this group lean, and by how much?
    private static func lean(
        in putts: [Putt],
        first: (Putt) -> Bool,
        firstKey: String,
        secondKey: String,
        minimum: Int,
        axis: Axis?
    ) -> Lean? {
        guard putts.count >= minimum else { return nil }
        let firstPutts = putts.filter(first)
        let secondCount = putts.count - firstPutts.count
        // An even split leans nowhere.
        guard firstPutts.count != secondCount else { return nil }
        let towardsFirst = firstPutts.count > secondCount
        let leading = towardsFirst ? firstPutts : putts.filter { !first($0) }
        return Lean(
            pattern: MissPattern(
                key: towardsFirst ? firstKey : secondKey,
                count: leading.count,
                total: putts.count
            ),
            axis: axis,
            direction: towardsFirst ? -1 : 1,
            putts: leading
        )
    }
}

extension PuttResult {
    /// -1 left of the hole, +1 right of it, 0 for a miss with no side to it.
    var lateralBias: Int {
        switch self {
        case .left, .shortLeft, .longLeft: return -1
        case .right, .shortRight, .longRight: return 1
        default: return 0
        }
    }

    /// -1 short of the hole, +1 past it, 0 for hole-high and the rest.
    var lengthBias: Int {
        switch self {
        case .short, .shortLeft, .shortRight: return -1
        case .long, .longLeft, .longRight: return 1
        default: return 0
        }
    }
}
