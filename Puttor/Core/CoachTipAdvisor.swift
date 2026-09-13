//
//  CoachTipAdvisor.swift
//  Puttor
//
//  Turns what keeps happening into what to do about it. The statistics tab is
//  for diagnosing; the coach is for instructions. Every finding the coach
//  reads — a miss pattern, a break read, a reason tied to a kind of putt, a
//  condition — belongs to a topic ("play more break", "stop the pull"), each
//  topic has one instruction, and the few topics costing the most putts are
//  the ones handed to the player.
//

import Foundation

/// One thing to do differently on the course, and the finding it comes from.
struct CoachTip: Identifiable {
    enum Topic: String, CaseIterable {
        case moreBreak, lessBreak, phantomBreak
        case uphillPace, downhillPace, slopeOverRead, greenSpeed
        case dieAtHole, softerPace
        case startLineLeft, startLineRight
        case pull, push, contact, badStroke
        case readTime, aim
        case holedLess, lag, lagDistance
    }

    enum Evidence {
        case pattern(MissPattern)
        case read(BreakReadFinding)
        case link(MissReasonLink)
        case condition(SplitFinding)
    }

    let topic: Topic
    /// Where the habit shows, as a `tip.where.` key: "strong", "band3to6".
    let whereID: String
    /// Set instead for a condition, whose own label names where.
    var conditionKey: String?
    let evidence: Evidence
    /// Roughly the putts the habit costs over the rounds read.
    let weight: Double

    var id: String { topic.rawValue }

    var title: String { L("tip.\(topic.rawValue).title") }

    var body: String { String(format: L("tip.\(topic.rawValue).body"), whereText) }

    /// "On strong breaks", "In rain": the sentence opening the instruction.
    var whereText: String {
        if let conditionKey {
            return String(format: L("tip.where.condition"), L(conditionKey))
        }
        return L("tip.where.\(whereID)")
    }

    var evidenceText: String {
        switch evidence {
        case .pattern(let pattern):
            return String(format: L(pattern.key), pattern.count, pattern.total, pattern.percent)
        case .read(let read):
            return read.text
        case .link(let link):
            return link.text
        case .condition(let finding):
            return String(format: L(finding.key), L(finding.conditionKey), finding.highText, L(finding.otherKey), finding.lowText)
        }
    }
}

enum CoachTipAdvisor {
    static let maximumTips = 3
    /// A miss leaning one way under a condition is not a putt lost outright;
    /// about a third of one is what fixing it is worth.
    static let conditionMissWorth = 0.3

    static func tips(
        patterns: [MissPattern],
        reads: [BreakReadFinding],
        links: [MissReasonLink],
        conditions: [SplitFinding]
    ) -> [CoachTip] {
        let candidates = patterns.compactMap(tip(for:))
            + reads.map(tip(for:))
            + links.map(tip(for:))
            + conditions.compactMap(tip(for:))

        // One tip per topic: the costliest finding behind it says where.
        var byTopic: [CoachTip.Topic: CoachTip] = [:]
        for candidate in candidates {
            if let kept = byTopic[candidate.topic], kept.weight >= candidate.weight { continue }
            byTopic[candidate.topic] = candidate
        }
        return byTopic.values
            .sorted { ($0.weight, $0.topic.rawValue) > ($1.weight, $1.topic.rawValue) }
            .prefix(maximumTips)
            .map { $0 }
    }

    // MARK: - Cost

    /// The putts the misses behind a finding would have holed at tour odds,
    /// scaled by how much of it is the habit rather than chance: `excess` is
    /// the share beyond an even split, 0 to 1.
    static func cost(of distances: [Double], excess: Double) -> Double {
        let odds = distances.reduce(0) { $0 + StrokesGained.baseline(at: $1).makeProbability }
        return odds * min(1, max(0, excess))
    }

    // MARK: - Findings to topics

    static func tip(for pattern: MissPattern) -> CoachTip? {
        let key = String(pattern.key.dropFirst("pattern.".count))
        let fixed: [String: (CoachTip.Topic, String)] = [
            "missLeft": (.startLineLeft, "all"),
            "missRight": (.startLineRight, "all"),
            "missShort": (.dieAtHole, "all"),
            "missLong": (.softerPace, "all"),
            "missLowSide": (.moreBreak, "breaking"),
            "missHighSide": (.lessBreak, "breaking"),
            "longPuttsShort": (.dieAtHole, "longPutts"),
            "longPuttsLong": (.softerPace, "longPutts"),
            "shortPuttsLeft": (.startLineLeft, "shortPutts"),
            "shortPuttsRight": (.startLineRight, "shortPutts"),
            "shortInside3m": (.dieAtHole, "under3m"),
            "lagOutsideMetre": (.lagDistance, "from8m"),
        ]

        let topic: CoachTip.Topic
        let whereID: String
        if let hit = fixed[key] {
            (topic, whereID) = hit
        } else {
            // "rightToLeft.left": a slice and the way its misses lean.
            let pieces = key.split(separator: ".").map(String.init)
            guard pieces.count == 2 else { return nil }
            whereID = pieces[0]
            switch (pieces[0], pieces[1]) {
            // Left of a right-to-left putt is below it; right of it, above.
            case ("rightToLeft", "left"), ("leftToRight", "right"): topic = .moreBreak
            case ("rightToLeft", "right"), ("leftToRight", "left"): topic = .lessBreak
            case ("uphill", "short"): topic = .uphillPace
            case ("downhill", "long"): topic = .downhillPace
            case ("uphill", "long"), ("downhill", "short"): topic = .slopeOverRead
            case (_, "left"): topic = .startLineLeft
            case (_, "right"): topic = .startLineRight
            case (_, "short"): topic = .dieAtHole
            case (_, "long"): topic = .softerPace
            default: return nil
            }
        }

        // The same cost the statistics rank their findings by.
        return CoachTip(
            topic: topic,
            whereID: whereID,
            evidence: .pattern(pattern),
            weight: pattern.strokesLost
        )
    }

    static func tip(for read: BreakReadFinding) -> CoachTip {
        let topic: CoachTip.Topic
        if read.reason == .wrongAim {
            // The read was right and the aim was not.
            topic = .aim
        } else {
            switch read.outcome {
            case .under: topic = .moreBreak
            case .over: topic = .lessBreak
            case .sawRightToLeft, .sawLeftToRight: topic = .phantomBreak
            case .uphillUnder: topic = .uphillPace
            case .downhillUnder: topic = .downhillPace
            case .uphillOver, .downhillOver: topic = .slopeOverRead
            case .slower, .faster: topic = .greenSpeed
            }
        }
        let share = read.total > 0 ? Double(read.count) / Double(read.total) : 0
        return CoachTip(
            topic: topic,
            whereID: read.cellID,
            evidence: .read(read),
            weight: cost(of: read.distances, excess: 2 * share - 1)
        )
    }

    static func tip(for link: MissReasonLink) -> CoachTip {
        let topic: CoachTip.Topic
        switch link.cause {
        case .pull: topic = .pull
        case .push: topic = .push
        case .misshit: topic = .contact
        case .badStroke: topic = .badStroke
        case .wrongAim: topic = .aim
        case .missRead: topic = link.groupID.hasPrefix("straight") ? .phantomBreak : .readTime
        }

        // A direction of miss is not a place on the course: the reason goes
        // for every putt. A strength group shares its break read's name.
        let whereID: String
        switch link.groupID {
        case "left", "right", "short", "long", "lowSide", "highSide": whereID = "all"
        case "gentleBreak": whereID = "gentle"
        case "mediumBreak": whereID = "medium"
        case "strongBreak": whereID = "strong"
        default: whereID = link.groupID
        }

        return CoachTip(
            topic: topic,
            whereID: whereID,
            evidence: .link(link),
            weight: cost(of: link.distances, excess: Double(link.percent - link.restPercent) / 100)
        )
    }

    /// Nil for a condition that helps rather than hurts.
    static func tip(for finding: SplitFinding) -> CoachTip? {
        let topic: CoachTip.Topic
        let weight: Double
        switch finding.key {
        case "split.missLong": topic = .softerPace; weight = finding.weight * conditionMissWorth
        case "split.missShort": topic = .dieAtHole; weight = finding.weight * conditionMissWorth
        case "split.missHighSide": topic = .lessBreak; weight = finding.weight * conditionMissWorth
        case "split.missLowSide": topic = .moreBreak; weight = finding.weight * conditionMissWorth
        case "split.missRead": topic = .readTime; weight = finding.weight * conditionMissWorth
        // Its weight carries the holed measure's importance; take it back out
        // to leave the putts that stayed out.
        case "split.holedLess": topic = .holedLess; weight = finding.weight / 3
        case "split.threePutts": topic = .lag; weight = finding.weight
        default: return nil
        }
        return CoachTip(
            topic: topic,
            whereID: "condition",
            conditionKey: finding.conditionKey,
            evidence: .condition(finding),
            weight: weight
        )
    }
}
