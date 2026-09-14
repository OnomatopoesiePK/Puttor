//
//  IntentionOutcome.swift
//  Puttor
//
//  What came of each intention. Putts are grouped by one part of their
//  intention — goal, pace, line or situation — and for each option: how often
//  it dropped, how often it was played as meant and what that did for the
//  make rate, which way the misses went, how far they finished, and whether a
//  breaking miss stayed on the high side. A lag is also read by how often it
//  finished in the circle, a putt played to stay below the hole by how often
//  the next one was uphill.
//

import Foundation

struct IntentionOutcome: Identifiable {
    let id: String
    let labelKey: String
    fileprivate let rank: Int

    var putts = 0
    var made = 0
    /// Putts where it was said whether the intention came off.
    var answered = 0
    var executed = 0
    var madeWhenExecuted = 0
    var madeWhenNot = 0
    /// Misses by length and by side; a short-left miss counts in both.
    var short = 0
    var long = 0
    var left = 0
    var right = 0
    /// How far the misses finished, where a putt followed.
    var leaves: [Double] = []
    /// Misses off line on a breaking putt, and those above the hole.
    var breakingMisses = 0
    var highSide = 0
    /// Putts that were made or left a putt, and those that finished in the circle.
    var settled = 0
    var inCircle = 0
    /// Misses whose next putt had its slope entered, and those uphill.
    var slopedLeaves = 0
    var uphillLeaves = 0

    var misses: Int { putts - made }
    var notExecuted: Int { answered - executed }

    var makePercent: Double? { Self.percent(made, of: putts) }
    var executedPercent: Double? { Self.percent(executed, of: answered) }
    var makePercentWhenExecuted: Double? { Self.percent(madeWhenExecuted, of: executed) }
    var makePercentWhenNot: Double? { Self.percent(madeWhenNot, of: notExecuted) }
    var highSidePercent: Double? { Self.percent(highSide, of: breakingMisses) }
    var inCirclePercent: Double? { Self.percent(inCircle, of: settled) }
    var uphillLeavePercent: Double? { Self.percent(uphillLeaves, of: slopedLeaves) }
    var averageLeave: Double? { leaves.isEmpty ? nil : leaves.reduce(0, +) / Double(leaves.count) }

    /// A count as a share of the misses.
    func missPercent(_ count: Int) -> Double { Self.percent(count, of: misses) ?? 0 }

    fileprivate static func percent(_ count: Int, of total: Int) -> Double? {
        total > 0 ? Double(count) / Double(total) * 100 : nil
    }

    /// The circle a lag is meant to finish in: a metre, or three feet.
    static func circle(useFeet: Bool) -> Double {
        useFeet ? UnitConverter.feetToMetres(3) : 1.0
    }

    /// The parts some putt holds an option for, in the order they are asked.
    static func parts(in putts: [Putt]) -> [IntentionPart] {
        let intentions = putts.lazy.filter { $0.puttNumber > 0 }.map(\.intention)
        return IntentionPart.allCases.filter { part in
            intentions.contains { $0.option(for: part) != nil }
        }
    }

    /// One outcome per option of the part, in the order the options are offered.
    static func outcomes(in putts: [Putt], by part: IntentionPart, useFeet: Bool = false) -> [IntentionOutcome] {
        let leaves = MissLeave(putts)
        let circle = circle(useFeet: useFeet)
        var byOption: [String: IntentionOutcome] = [:]

        for putt in putts where putt.puttNumber > 0 {
            let intention = putt.intention
            guard let option = intention.option(for: part) else { continue }
            var outcome = byOption[option.id] ?? IntentionOutcome(id: option.id, labelKey: option.labelKey, rank: option.rank)
            let holed = putt.result.isHoled
            outcome.putts += 1
            if holed {
                outcome.made += 1
                outcome.settled += 1
                outcome.inCircle += 1
            }

            if let executed = intention.executed {
                outcome.answered += 1
                if executed {
                    outcome.executed += 1
                    if holed { outcome.madeWhenExecuted += 1 }
                } else if holed {
                    outcome.madeWhenNot += 1
                }
            }

            if !holed {
                let result = putt.result
                if result.lengthBias < 0 { outcome.short += 1 }
                if result.lengthBias > 0 { outcome.long += 1 }
                if result.lateralBias < 0 { outcome.left += 1 }
                if result.lateralBias > 0 { outcome.right += 1 }

                if putt.sideSlopePct != 0 && result.lateralBias != 0 {
                    outcome.breakingMisses += 1
                    // Below the hole is the side the slope runs off to.
                    let lowSide = (putt.sideSlopePct < 0) == (result.lateralBias < 0)
                    if !lowSide { outcome.highSide += 1 }
                }

                if let next = leaves.next(after: putt) {
                    outcome.leaves.append(next.distanceM)
                    outcome.settled += 1
                    if next.distanceM <= circle + 0.0001 { outcome.inCircle += 1 }
                    if next.hillSlopePct != 0 {
                        outcome.slopedLeaves += 1
                        if next.hillSlopePct > 0 { outcome.uphillLeaves += 1 }
                    }
                }
            }
            byOption[option.id] = outcome
        }
        return byOption.values.sorted { $0.rank < $1.rank }
    }
}

/// Whether putts were played as meant, against whether they dropped.
struct IntentionExecution {
    var executedMade = 0
    var executedMissed = 0
    var notExecutedMade = 0
    var notExecutedMissed = 0

    var total: Int { executedMade + executedMissed + notExecutedMade + notExecutedMissed }
    var misses: Int { executedMissed + notExecutedMissed }

    func percent(_ count: Int) -> Double { IntentionOutcome.percent(count, of: total) ?? 0 }

    /// Of the misses, the share that were played as meant.
    var executedMissPercent: Double? { IntentionOutcome.percent(executedMissed, of: misses) }

    init(_ putts: [Putt]) {
        for putt in putts where putt.puttNumber > 0 {
            let intention = putt.intention
            guard !intention.isEmpty, let executed = intention.executed else { continue }
            switch (executed, putt.result.isHoled) {
            case (true, true): executedMade += 1
            case (true, false): executedMissed += 1
            case (false, true): notExecutedMade += 1
            case (false, false): notExecutedMissed += 1
            }
        }
    }
}
