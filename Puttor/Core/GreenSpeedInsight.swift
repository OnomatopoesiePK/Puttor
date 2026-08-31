//
//  GreenSpeedInsight.swift
//  Puttor
//
//  Whether the greens' pace changes how the misses go. Quick greens usually
//  punish a firm stroke and reward reading more break; slow ones do the
//  opposite. Both are only worth saying when the same player's numbers on one
//  differ from their numbers on the other.
//

import Foundation

enum GreenSpeedInsight {
    /// Stimp readings either side of these are treated as fast and slow; in
    /// between is ordinary and says nothing either way.
    static let fastStimp = 10.0
    static let slowStimp = 8.5
    /// Each side needs this many putts before a difference is a difference.
    static let minimumPerSide = 6
    /// Percentage points between the two sides before it is worth a sentence.
    static let minimumGap = 20.0

    /// One putt with the pace of the green it was struck on.
    private struct Sample {
        let putt: Putt
        let stimp: Double
    }

    static func findings(in rounds: [Round]) -> [CoachFinding] {
        let samples = rounds.flatMap { round in
            round.putts
                .filter { $0.puttNumber > 0 }
                .map { Sample(putt: $0, stimp: round.stimp) }
        }

        let fast = samples.filter { $0.stimp >= fastStimp }
        let slow = samples.filter { $0.stimp <= slowStimp }
        guard fast.count >= minimumPerSide, slow.count >= minimumPerSide else { return [] }

        var findings: [CoachFinding] = []

        // Pace: of the misses that were short or long, how many ran past.
        if let finding = compare(
            fast: fast, slow: slow,
            among: { $0.result.lengthBias != 0 && !$0.result.isHoled },
            matching: { $0.result.lengthBias > 0 },
            fastHigherKey: "coach.green.fastRunsLong",
            slowHigherKey: "coach.green.slowLeavesShort"
        ) {
            findings.append(finding)
        }

        // Read: how often a miss was put down to the line rather than the
        // stroke.
        if let finding = compare(
            fast: fast, slow: slow,
            among: { !$0.result.isHoled },
            matching: { $0.missRead },
            fastHigherKey: "coach.green.fastMissRead",
            slowHigherKey: "coach.green.slowMissRead"
        ) {
            findings.append(finding)
        }

        return findings
    }

    /// Shares of the same thing on both kinds of green, reported only when
    /// they differ by enough to mean something.
    private static func compare(
        fast: [Sample],
        slow: [Sample],
        among: (Putt) -> Bool,
        matching: (Putt) -> Bool,
        fastHigherKey: String,
        slowHigherKey: String
    ) -> CoachFinding? {
        func share(_ samples: [Sample]) -> (share: Double, count: Int)? {
            let pool = samples.map(\.putt).filter(among)
            guard pool.count >= minimumPerSide else { return nil }
            return (Double(pool.filter(matching).count) / Double(pool.count) * 100, pool.count)
        }

        guard let fastShare = share(fast), let slowShare = share(slow) else { return nil }
        let gap = fastShare.share - slowShare.share
        guard abs(gap) >= minimumGap else { return nil }

        return CoachFinding(
            key: gap > 0 ? fastHigherKey : slowHigherKey,
            numbers: [
                Int((gap > 0 ? fastShare.share : slowShare.share).rounded()),
                Int((gap > 0 ? slowShare.share : fastShare.share).rounded()),
            ]
        )
    }
}
