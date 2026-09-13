//
//  MissReasonLinker.swift
//  Puttor
//
//  Ties the reasons ticked on missed putts to where those putts went and what
//  kind of putts they were: "straight putts are mostly misread", "pulled putts
//  go left". A link is only named when the reason is common in the group and
//  clearly rarer everywhere else — a player who misreads everything has no
//  link, just a lot of misreads.
//

import Foundation

/// Why a putt was missed, as ticked on the card. The kind of bad stroke is a
/// cause of its own, because "bad stroke" alone does not say which way it went.
enum MissCause: String, CaseIterable {
    case missRead, wrongAim, badStroke, pull, push, misshit

    func applies(to putt: Putt) -> Bool {
        switch self {
        case .missRead: return putt.missRead
        case .wrongAim: return putt.wrongAim
        case .badStroke: return putt.badStroke
        case .pull: return putt.badStroke && putt.badStrokeType == .pull
        case .push: return putt.badStroke && putt.badStrokeType == .push
        case .misshit: return putt.badStroke && putt.badStrokeType == .misshit
        }
    }

    /// The broader cause this one narrows down.
    var parent: MissCause? {
        switch self {
        case .pull, .push, .misshit: return .badStroke
        default: return nil
        }
    }

    /// What the misses were: "misread", "pulled".
    var predicateKey: String { "cause.\(rawValue)" }
    /// The misses it names, as a subject: "Misread misses".
    var subjectKey: String { "cause.\(rawValue).subject" }
}

/// The cause standing behind a habit, against the rest of the misses.
struct MissCauseNote: Equatable {
    let cause: MissCause
    let count: Int
    let total: Int
    let restPercent: Int

    var percent: Int { MissReasonLinker.percent(count, of: total) }

    var text: String {
        String(format: L("cause.note"), count, total, percent, L(cause.predicateKey))
    }
}

/// A group of misses and a cause that go together.
struct MissReasonLink: Identifiable {
    enum Reading {
        /// "Straight putts: 6 of 8 misses were misread."
        case groupToCause
        /// "Pulled misses: 7 of 8 went left."
        case causeToGroup
    }

    let groupID: String
    let cause: MissCause
    let reading: Reading
    let count: Int
    let total: Int
    let restPercent: Int
    /// How far the putts in both the group and the cause were struck from.
    var distances: [Double] = []

    var id: String { "\(groupID)-\(cause.rawValue)" }
    var percent: Int { MissReasonLinker.percent(count, of: total) }

    var text: String {
        switch reading {
        case .groupToCause:
            return String(
                format: L("link.groupToCause"),
                L("link.group.\(groupID)"), count, total, percent, L(cause.predicateKey)
            )
        case .causeToGroup:
            return String(
                format: L("link.causeToGroup"),
                L(cause.subjectKey), count, total, percent, L("link.groupPhrase.\(groupID)")
            )
        }
    }
}

enum MissReasonLinker {
    /// More than this share of the group has to share the cause…
    static let thresholdPercent = 60
    /// …this many points more than the misses it is compared with…
    static let minimumGapPoints = 20
    /// …and the difference has to pass a one-sided two-proportion test at 5%.
    static let minimumZ = 1.645
    /// A group needs this many misses, the comparison this many.
    static let minimumGroup = 6
    static let minimumRest = 4
    static let maximumLinks = 5

    /// One way to split the misses. `pool` is what the group is compared
    /// within: a left miss against the right ones, a straight putt against
    /// every other miss.
    struct Group {
        let id: String
        var pool: (Putt) -> Bool = { _ in true }
        /// The broader groups this one sits inside: a strong right-to-left
        /// break inside right-to-left and inside strong.
        var parents: [String] = []
        let includes: (Putt) -> Bool
    }

    private static func isBreaking(_ putt: Putt) -> Bool {
        abs(putt.sideSlopePct) >= MissPatternFinder.breakingSlopePct && putt.result.lateralBias != 0
    }

    private static func isLowSide(_ putt: Putt) -> Bool {
        (putt.sideSlopePct < 0 && putt.result.lateralBias < 0)
            || (putt.sideSlopePct > 0 && putt.result.lateralBias > 0)
    }

    static let groups: [Group] = [
        Group(id: "left", pool: { $0.result.lateralBias != 0 }, includes: { $0.result.lateralBias < 0 }),
        Group(id: "right", pool: { $0.result.lateralBias != 0 }, includes: { $0.result.lateralBias > 0 }),
        Group(id: "short", pool: { $0.result.lengthBias != 0 }, includes: { $0.result.lengthBias < 0 }),
        Group(id: "long", pool: { $0.result.lengthBias != 0 }, includes: { $0.result.lengthBias > 0 }),
        Group(id: "lowSide", pool: isBreaking, includes: isLowSide),
        Group(id: "highSide", pool: isBreaking, includes: { !isLowSide($0) }),
        Group(id: "rightToLeft", includes: { $0.sideSlopePct < 0 }),
        Group(id: "leftToRight", includes: { $0.sideSlopePct > 0 }),
        Group(id: "straight", includes: { $0.sideSlopePct == 0 }),
        Group(id: "uphill", includes: { $0.hillSlopePct > 0 }),
        Group(id: "downhill", includes: { $0.hillSlopePct < 0 }),
        Group(id: "longPutts", includes: { $0.distanceM >= MissPatternFinder.longPuttDistanceM }),
        Group(id: "shortPutts", includes: { $0.distanceM <= MissPatternFinder.shortPuttDistanceM }),
        Group(id: "band15to3", includes: {
            $0.distanceM > MissPatternFinder.shortPuttDistanceM && $0.distanceM < MissPatternFinder.midPuttDistanceM
        }),
        Group(id: "band3to6", includes: {
            $0.distanceM >= MissPatternFinder.midPuttDistanceM && $0.distanceM < MissPatternFinder.longPuttDistanceM
        }),
        Group(id: "gentleBreak", includes: { BreakStrength(sideSlopePct: $0.sideSlopePct) == .gentle }),
        Group(id: "mediumBreak", includes: { BreakStrength(sideSlopePct: $0.sideSlopePct) == .medium }),
        Group(id: "strongBreak", includes: { BreakStrength(sideSlopePct: $0.sideSlopePct) == .strong }),
        Group(id: "rightToLeftGentle", parents: ["rightToLeft", "gentleBreak"], includes: {
            $0.sideSlopePct < 0 && BreakStrength(sideSlopePct: $0.sideSlopePct) == .gentle
        }),
        Group(id: "rightToLeftMedium", parents: ["rightToLeft", "mediumBreak"], includes: {
            $0.sideSlopePct < 0 && BreakStrength(sideSlopePct: $0.sideSlopePct) == .medium
        }),
        Group(id: "rightToLeftStrong", parents: ["rightToLeft", "strongBreak"], includes: {
            $0.sideSlopePct < 0 && BreakStrength(sideSlopePct: $0.sideSlopePct) == .strong
        }),
        Group(id: "leftToRightGentle", parents: ["leftToRight", "gentleBreak"], includes: {
            $0.sideSlopePct > 0 && BreakStrength(sideSlopePct: $0.sideSlopePct) == .gentle
        }),
        Group(id: "leftToRightMedium", parents: ["leftToRight", "mediumBreak"], includes: {
            $0.sideSlopePct > 0 && BreakStrength(sideSlopePct: $0.sideSlopePct) == .medium
        }),
        Group(id: "leftToRightStrong", parents: ["leftToRight", "strongBreak"], includes: {
            $0.sideSlopePct > 0 && BreakStrength(sideSlopePct: $0.sideSlopePct) == .strong
        }),
        Group(id: "doubleBreak", includes: { $0.doubleBreak != nil }),
    ]

    // MARK: - Reading

    /// The misses from rounds where reasons were being recorded at all. A
    /// round played without the field would otherwise read as a round of
    /// misses with no reason behind them.
    static func trackedMisses(in putts: [Putt]) -> [Putt] {
        let misses = putts.filter { $0.puttNumber > 0 && !$0.result.isHoled }
        let recording = Set(misses.filter { $0.missReasonCount > 0 }.map { roundID($0) })
        return misses.filter { recording.contains(roundID($0)) }
    }

    /// Every group against every cause, highest share first.
    static func links(in putts: [Putt]) -> [MissReasonLink] {
        let tracked = trackedMisses(in: putts)
        guard !tracked.isEmpty else { return [] }

        var found: [(link: MissReasonLink, z: Double)] = []
        for group in groups {
            let pool = tracked.filter(group.pool)
            let inGroup = pool.map(group.includes)
            for cause in MissCause.allCases {
                var both = 0, groupOnly = 0, causeOnly = 0, neither = 0
                var bothDistances: [Double] = []
                for (index, putt) in pool.enumerated() {
                    switch (inGroup[index], cause.applies(to: putt)) {
                    case (true, true):
                        both += 1
                        bothDistances.append(putt.distanceM)
                    case (true, false): groupOnly += 1
                    case (false, true): causeOnly += 1
                    case (false, false): neither += 1
                    }
                }
                // The same table read both ways; the one with the larger share
                // is the sentence worth saying.
                let readings: [(MissReasonLink.Reading, Share)] = [
                    (.groupToCause, Share(count: both, total: both + groupOnly, restCount: causeOnly, restTotal: causeOnly + neither)),
                    (.causeToGroup, Share(count: both, total: both + causeOnly, restCount: groupOnly, restTotal: groupOnly + neither)),
                ]
                guard let best = readings.filter({ $0.1.passes }).max(by: { $0.1.percent < $1.1.percent }) else { continue }
                found.append((
                    MissReasonLink(
                        groupID: group.id,
                        cause: cause,
                        reading: best.0,
                        count: best.1.count,
                        total: best.1.total,
                        restPercent: best.1.restPercent,
                        distances: bothDistances
                    ),
                    best.1.z
                ))
            }
        }

        // A pull says more than a bad stroke: the broad cause is dropped where
        // one of its kinds already links to the same group.
        let specific = found.filter { candidate in
            !found.contains { $0.link.groupID == candidate.link.groupID && $0.link.cause.parent == candidate.link.cause }
        }
        // A break direction at one strength says nothing new when the
        // direction or the strength alone already carries the same link.
        let parentsByGroup = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.parents) })
        let standing = specific.filter { candidate in
            let parents = parentsByGroup[candidate.link.groupID] ?? []
            return !specific.contains { other in
                parents.contains(other.link.groupID)
                    && other.link.cause == candidate.link.cause
                    && candidate.link.percent < other.link.percent + MissPatternFinder.standOutPoints
            }
        }

        // The best-evidenced are kept, then shown from the highest share down.
        return standing
            .sorted { ($0.z, $0.link.count) > ($1.z, $1.link.count) }
            .prefix(maximumLinks)
            .map(\.link)
            .sorted { ($0.percent, $0.count) > ($1.percent, $1.count) }
    }

    /// The cause behind a group of misses — the putts a habit rests on —
    /// measured against every other tracked miss.
    static func cause(behind group: [Putt], among tracked: [Putt]) -> MissCauseNote? {
        let members = Set(group.map { ObjectIdentifier($0) })
        let inGroup = tracked.filter { members.contains(ObjectIdentifier($0)) }
        let rest = tracked.filter { !members.contains(ObjectIdentifier($0)) }

        let found: [(note: MissCauseNote, z: Double)] = MissCause.allCases.compactMap { cause in
            let share = Share(
                count: inGroup.filter(cause.applies).count,
                total: inGroup.count,
                restCount: rest.filter(cause.applies).count,
                restTotal: rest.count
            )
            guard share.passes else { return nil }
            return (MissCauseNote(cause: cause, count: share.count, total: share.total, restPercent: share.restPercent), share.z)
        }
        return found
            .filter { candidate in !found.contains { $0.note.cause.parent == candidate.note.cause } }
            .max { ($0.z, $0.note.count) < ($1.z, $1.note.count) }?
            .note
    }

    static func percent(_ count: Int, of total: Int) -> Int {
        total > 0 ? Int((Double(count) / Double(total) * 100).rounded()) : 0
    }

    /// The lowest share `count` of `total` plausibly stands for (Wilson, 95%).
    /// Ranks a clear share over many putts above a perfect one over a handful.
    static func confidenceFloor(_ count: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        let n = Double(total)
        let share = Double(count) / n
        let z = 1.96
        let z2 = z * z
        let spread = z * ((share * (1 - share) + z2 / (4 * n)) / n).squareRoot()
        return (share + z2 / (2 * n) - spread) / (1 + z2 / n)
    }

    // MARK: - One comparison

    private struct Share {
        let count: Int
        let total: Int
        let restCount: Int
        let restTotal: Int

        var percent: Int { MissReasonLinker.percent(count, of: total) }
        var restPercent: Int { MissReasonLinker.percent(restCount, of: restTotal) }

        /// Two-proportion z, pooled. Zero where there is no spread to test.
        var z: Double {
            guard total > 0, restTotal > 0 else { return 0 }
            let pooled = Double(count + restCount) / Double(total + restTotal)
            let spread = (pooled * (1 - pooled) * (1 / Double(total) + 1 / Double(restTotal))).squareRoot()
            guard spread > 0 else { return 0 }
            return (Double(count) / Double(total) - Double(restCount) / Double(restTotal)) / spread
        }

        var passes: Bool {
            total >= MissReasonLinker.minimumGroup
                && restTotal >= MissReasonLinker.minimumRest
                && percent > MissReasonLinker.thresholdPercent
                && percent - restPercent >= MissReasonLinker.minimumGapPoints
                && z >= MissReasonLinker.minimumZ
        }
    }

    private static func roundID(_ putt: Putt) -> ObjectIdentifier? {
        putt.round.map { ObjectIdentifier($0) }
    }
}
