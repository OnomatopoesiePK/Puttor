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
    /// Localisation key taking the count and the total, in that order.
    let key: String
    let count: Int
    let total: Int

    var id: String { key }
    var share: Double { total > 0 ? Double(count) / Double(total) : 0 }
}

enum MissPatternFinder {
    /// A habit has to show up in enough putts to be one. Below these counts a
    /// run of misses is just a run of misses.
    static let minimumSample = 8
    static let minimumSubsetSample = 6
    /// Three in five going the same way is a lean; less than that is noise.
    static let threshold = 0.6
    /// How many findings are worth reading at once.
    static let maximumFindings = 3

    /// Long putts, where distance control is the thing being tested, and short
    /// ones, where the line is.
    static let longPuttDistanceM = 6.0
    static let shortPuttDistanceM = 1.5
    /// Below this the green is flat enough that "high side" means nothing.
    static let breakingSlopePct = 1.0

    static func findings(in putts: [Putt]) -> [MissPattern] {
        let misses = putts.filter { $0.puttNumber > 0 && !$0.result.isHoled }
        guard !misses.isEmpty else { return [] }

        var found: [MissPattern] = []

        // Which side of the hole, over everything.
        let lateral = misses.filter { $0.result.lateralBias != 0 }
        found += lean(
            in: lateral,
            left: { $0.result.lateralBias < 0 },
            leftKey: "pattern.missLeft",
            rightKey: "pattern.missRight",
            minimum: minimumSample
        )

        // Short or long, over everything.
        let longitudinal = misses.filter { $0.result.lengthBias != 0 }
        found += lean(
            in: longitudinal,
            left: { $0.result.lengthBias < 0 },
            leftKey: "pattern.missShort",
            rightKey: "pattern.missLong",
            minimum: minimumSample
        )

        // On a breaking putt, below the hole is the miss that never had a
        // chance; above it at least died towards the cup.
        let breaking = misses.filter {
            abs($0.sideSlopePct) >= breakingSlopePct && $0.result.lateralBias != 0
        }
        found += lean(
            in: breaking,
            left: { putt in
                // Low side: the ball missed the way the green was falling.
                (putt.sideSlopePct < 0 && putt.result.lateralBias < 0)
                    || (putt.sideSlopePct > 0 && putt.result.lateralBias > 0)
            },
            leftKey: "pattern.missLowSide",
            rightKey: "pattern.missHighSide",
            minimum: minimumSubsetSample
        )

        // Distance control from range.
        let longPutts = misses.filter { $0.distanceM >= longPuttDistanceM && $0.result.lengthBias != 0 }
        found += lean(
            in: longPutts,
            left: { $0.result.lengthBias < 0 },
            leftKey: "pattern.longPuttsShort",
            rightKey: "pattern.longPuttsLong",
            minimum: minimumSubsetSample
        )

        // Line from close in.
        let shortPutts = misses.filter { $0.distanceM <= shortPuttDistanceM && $0.result.lateralBias != 0 }
        found += lean(
            in: shortPutts,
            left: { $0.result.lateralBias < 0 },
            leftKey: "pattern.shortPuttsLeft",
            rightKey: "pattern.shortPuttsRight",
            minimum: minimumSubsetSample
        )

        // The strongest habits first, and the bigger sample where two lean the
        // same amount.
        return Array(
            found
                .sorted { ($0.share, $0.count) > ($1.share, $1.count) }
                .prefix(maximumFindings)
        )
    }

    /// One two-sided test: does this group lean far enough one way to mention?
    private static func lean(
        in putts: [Putt],
        left: (Putt) -> Bool,
        leftKey: String,
        rightKey: String,
        minimum: Int
    ) -> [MissPattern] {
        guard putts.count >= minimum else { return [] }
        let leftCount = putts.filter(left).count
        let rightCount = putts.count - leftCount
        let leading = max(leftCount, rightCount)
        guard Double(leading) / Double(putts.count) >= threshold else { return [] }
        return [MissPattern(
            key: leftCount >= rightCount ? leftKey : rightKey,
            count: leading,
            total: putts.count
        )]
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
