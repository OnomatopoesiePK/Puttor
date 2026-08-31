//
//  SplitInsight.swift
//  Puttor
//
//  Reads every condition a round can be played in — the pace of the greens,
//  the rain, the wind, the break in front of the ball — against its opposite,
//  and reports where the same player putts measurably differently. These are
//  the findings worth carrying into the next round: not "you miss short", but
//  "you miss short when it rains".
//
//  The engine is deliberately generic. Every dimension is one closure and
//  every measure is two, so a new condition costs a line rather than a file.
//  What is not generic is the guard around it: comparing this many splits
//  against this many measures produces differences by chance alone, and an
//  advisor that cries wolf every round is one nobody reads. So each comparison
//  has to survive a sample floor, a check that the two sides were putting from
//  comparable distances, a two-proportion test, and a correction for how many
//  tests were run to find it.
//

import Foundation

/// One condition measurably different from its opposite.
struct SplitFinding: Identifiable {
    enum Display { case percent, perRound }

    /// Localisation key taking, in order: the condition, its number, the
    /// opposite condition, its number.
    let key: String
    let conditionKey: String
    let otherKey: String
    let high: Double
    let low: Double
    let display: Display
    /// Putts (or holes) the condition was read from.
    let sample: Int
    /// How much this is worth saying first: roughly the strokes or putts the
    /// difference accounts for over the window read.
    let weight: Double

    var id: String { "\(key)-\(conditionKey)" }

    var highText: String { text(high) }
    var lowText: String { text(low) }

    private func text(_ value: Double) -> String {
        switch display {
        case .percent: return "\(Int(value.rounded()))"
        case .perRound: return String(format: "%.1f", value)
        }
    }
}

enum SplitInsight {
    /// Each side of a comparison needs this many putts — or, for anything
    /// counted per hole, this many holes.
    static let minimumPerSide = 8
    static let minimumHolesPerSide = 12
    /// Below these the difference is real but not worth a sentence.
    static let minimumGapPct = 10.0
    static let minimumThreePuttGap = 0.4
    /// Two sides putting from different distances would differ whatever the
    /// condition did, so a comparison is only read when the distances match to
    /// within this.
    static let distanceToleranceM = 1.0
    /// Every comparison's p-value is multiplied by the number of comparisons
    /// made before it is judged. Hunting through forty splits turns up
    /// "findings" in random data; this is what stops them reaching the player.
    static let maximumAdjustedP = 0.2
    static let maximumFindings = 3
    /// At most this many from any one condition, so a single wet week cannot
    /// fill the whole card.
    static let maximumPerDimension = 2
    /// Anything counted per hole is reported per round at this many holes.
    static let holesPerRound = 18.0

    // MARK: - What gets compared

    /// One condition and its opposite. `side` answers which of the two a putt
    /// belongs to, or nil when it belongs to neither — the middle of a scale
    /// is not a condition.
    struct Dimension {
        let id: String
        let highKey: String
        let lowKey: String
        let side: (Putt, Round) -> Bool?
    }

    /// One thing to count, over the putts that can be counted for it.
    struct Measure {
        let id: String
        /// Names the side doing more of it.
        let key: String
        /// Names the other side doing more of the opposite, when that reads
        /// better: "short when it rains" beats "long when it is dry".
        let mirrorKey: String?
        let importance: Double
        let pool: (Putt) -> Bool
        let hit: (Putt) -> Bool
    }

    static let dimensions: [Dimension] = [
        Dimension(id: "greenSpeed", highKey: "split.cond.fastGreens", lowKey: "split.cond.slowGreens") { _, round in
            round.stimp >= 10 ? true : (round.stimp <= 8.5 ? false : nil)
        },
        Dimension(id: "rain", highKey: "split.cond.rain", lowKey: "split.cond.dry") { _, round in
            round.precipitation == .rain
        },
        Dimension(id: "wind", highKey: "split.cond.wind", lowKey: "split.cond.calm") { _, round in
            switch round.wind {
            case .high: return true
            case .none: return false
            case .medium: return nil
            }
        },
        Dimension(id: "cold", highKey: "split.cond.cold", lowKey: "split.cond.warm") { _, round in
            round.weather == .cold
        },
        Dimension(id: "grain", highKey: "split.cond.grain", lowKey: "split.cond.noGrain") { _, round in
            round.grainyGreens
        },
        Dimension(id: "break", highKey: "split.cond.strongBreak", lowKey: "split.cond.flat") { putt, _ in
            let slope = abs(putt.sideSlopePct)
            return slope >= 2 ? true : (slope <= 0.5 ? false : nil)
        },
        Dimension(id: "slope", highKey: "split.cond.downhill", lowKey: "split.cond.uphill") { putt, _ in
            putt.hillSlopePct <= -1 ? true : (putt.hillSlopePct >= 1 ? false : nil)
        },
        Dimension(id: "doubleBreak", highKey: "split.cond.doubleBreak", lowKey: "split.cond.singleBreak") { putt, _ in
            putt.doubleBreak != nil
        },
    ]

    static let measures: [Measure] = [
        // Pace, over the misses that had a length to them.
        Measure(
            id: "length",
            key: "split.missLong",
            mirrorKey: "split.missShort",
            importance: 1,
            pool: { !$0.result.isHoled && $0.result.lengthBias != 0 },
            hit: { $0.result.lengthBias > 0 }
        ),
        // The side of the break the miss went, over the putts that broke.
        Measure(
            id: "breakSide",
            key: "split.missHighSide",
            mirrorKey: "split.missLowSide",
            importance: 1.2,
            pool: { !$0.result.isHoled && abs($0.sideSlopePct) >= 1 && $0.result.lateralBias != 0 },
            hit: { putt in
                // High side: the ball held above the line the green was
                // falling away on.
                !((putt.sideSlopePct < 0 && putt.result.lateralBias < 0)
                    || (putt.sideSlopePct > 0 && putt.result.lateralBias > 0))
            }
        ),
        // How often a miss was put down to the line rather than the stroke.
        Measure(
            id: "missRead",
            key: "split.missRead",
            mirrorKey: nil,
            importance: 1,
            pool: { !$0.result.isHoled },
            hit: { $0.missRead }
        ),
        // And whether they simply go in less often.
        Measure(
            id: "holed",
            key: "split.holedMore",
            mirrorKey: "split.holedLess",
            importance: 3,
            pool: { _ in true },
            hit: { $0.result.isHoled }
        ),
    ]

    // MARK: - Reading

    static func findings(in rounds: [Round]) -> [SplitFinding] {
        var tested = 0
        var candidates: [(finding: SplitFinding, p: Double)] = []

        for dimension in dimensions {
            var high: [Putt] = []
            var low: [Putt] = []
            for round in rounds {
                for putt in round.putts where putt.puttNumber > 0 {
                    switch dimension.side(putt, round) {
                    case .some(true): high.append(putt)
                    case .some(false): low.append(putt)
                    case nil: break
                    }
                }
            }

            for measure in measures {
                guard let candidate = compare(measure, dimension: dimension, high: high, low: low) else { continue }
                tested += 1
                candidates.append(candidate)
            }

            if let candidate = compareThreePutts(dimension: dimension, rounds: rounds) {
                tested += 1
                candidates.append(candidate)
            }
        }

        // Every test makes a fluke likelier, so the bar rises with the number
        // of them.
        let comparisons = Double(max(tested, 1))
        var perDimension: [String: Int] = [:]
        var kept: [SplitFinding] = []

        for candidate in candidates.sorted(by: { $0.finding.weight > $1.finding.weight }) {
            guard min(1, candidate.p * comparisons) <= maximumAdjustedP else { continue }
            guard isWorthSaying(candidate.finding) else { continue }
            let dimension = candidate.finding.conditionKey
            let group = dimensionID(forConditionKey: dimension)
            guard perDimension[group, default: 0] < maximumPerDimension else { continue }
            perDimension[group, default: 0] += 1
            kept.append(candidate.finding)
            if kept.count == maximumFindings { break }
        }

        return kept
    }

    /// Which condition a finding came from, so one dimension cannot take the
    /// whole card.
    private static func dimensionID(forConditionKey key: String) -> String {
        dimensions.first { $0.highKey == key || $0.lowKey == key }?.id ?? key
    }

    // MARK: - One comparison

    private static func compare(
        _ measure: Measure,
        dimension: Dimension,
        high: [Putt],
        low: [Putt]
    ) -> (finding: SplitFinding, p: Double)? {
        let poolHigh = high.filter(measure.pool)
        let poolLow = low.filter(measure.pool)
        guard poolHigh.count >= minimumPerSide, poolLow.count >= minimumPerSide else { return nil }
        // Distance decides most of what a putt does; two sides putting from
        // different ranges would differ with no condition involved.
        guard comparable(poolHigh, poolLow) else { return nil }

        let hitsHigh = poolHigh.filter(measure.hit).count
        let hitsLow = poolLow.filter(measure.hit).count
        let shareHigh = Double(hitsHigh) / Double(poolHigh.count) * 100
        let shareLow = Double(hitsLow) / Double(poolLow.count) * 100
        let p = twoProportionP(hitsHigh, poolHigh.count, hitsLow, poolLow.count)

        // Say it from the side with the stronger tendency: the same fact, in
        // the sentence that carries more of it.
        var conditionIsHigh = shareHigh >= shareLow
        var key = measure.key
        var top = max(shareHigh, shareLow)
        var bottom = min(shareHigh, shareLow)
        if let mirrorKey = measure.mirrorKey, 100 - bottom > top {
            key = mirrorKey
            conditionIsHigh.toggle()
            (top, bottom) = (100 - bottom, 100 - top)
        }
        let conditionKey = conditionIsHigh ? dimension.highKey : dimension.lowKey
        let otherKey = conditionIsHigh ? dimension.lowKey : dimension.highKey

        let sample = conditionIsHigh ? poolHigh.count : poolLow.count
        let extra = Double(sample) * (top - bottom) / 100

        return (
            SplitFinding(
                key: key,
                conditionKey: conditionKey,
                otherKey: otherKey,
                high: top,
                low: bottom,
                display: .percent,
                sample: sample,
                weight: extra * measure.importance
            ),
            p
        )
    }

    /// Three-putts, counted per hole and reported per round. Distance is the
    /// whole story here — three-putting from 20 m is ordinary — so the two
    /// sides are only compared when their first putts came from the same sort
    /// of range.
    private static func compareThreePutts(
        dimension: Dimension,
        rounds: [Round]
    ) -> (finding: SplitFinding, p: Double)? {
        var high: [(putts: Int, distance: Double)] = []
        var low: [(putts: Int, distance: Double)] = []

        for round in rounds {
            let holes = Set(round.putts.map(\.holeNumber))
            for hole in holes {
                let onHole = round.putts
                    .filter { $0.holeNumber == hole && $0.puttNumber > 0 }
                    .sorted { $0.puttNumber < $1.puttNumber }
                guard let first = onHole.first else { continue }
                switch dimension.side(first, round) {
                case .some(true): high.append((onHole.count, first.distanceM))
                case .some(false): low.append((onHole.count, first.distanceM))
                case nil: break
                }
            }
        }

        guard high.count >= minimumHolesPerSide, low.count >= minimumHolesPerSide else { return nil }
        let meanHigh = high.reduce(0.0) { $0 + $1.distance } / Double(high.count)
        let meanLow = low.reduce(0.0) { $0 + $1.distance } / Double(low.count)
        guard abs(meanHigh - meanLow) <= distanceToleranceM else { return nil }

        let threeHigh = high.filter { $0.putts >= 3 }.count
        let threeLow = low.filter { $0.putts >= 3 }.count
        let perRoundHigh = Double(threeHigh) / Double(high.count) * holesPerRound
        let perRoundLow = Double(threeLow) / Double(low.count) * holesPerRound
        let p = twoProportionP(threeHigh, high.count, threeLow, low.count)

        let leading = perRoundHigh >= perRoundLow
        let sample = leading ? high.count : low.count
        let extra = Double(sample) / holesPerRound * abs(perRoundHigh - perRoundLow)

        return (
            SplitFinding(
                key: "split.threePutts",
                conditionKey: leading ? dimension.highKey : dimension.lowKey,
                otherKey: leading ? dimension.lowKey : dimension.highKey,
                high: max(perRoundHigh, perRoundLow),
                low: min(perRoundHigh, perRoundLow),
                display: .perRound,
                sample: sample,
                // A three-putt is a stroke, not a tendency: worth saying
                // ahead of anything measured in shares.
                weight: extra * 4
            ),
            p
        )
    }

    // MARK: - The guards

    /// Whether two pools were putting from close enough to the same range for
    /// the difference between them to be about anything else.
    private static func comparable(_ lhs: [Putt], _ rhs: [Putt]) -> Bool {
        let left = lhs.reduce(0.0) { $0 + $1.distanceM } / Double(lhs.count)
        let right = rhs.reduce(0.0) { $0 + $1.distanceM } / Double(rhs.count)
        return abs(left - right) <= distanceToleranceM
    }

    /// Two-sided p-value for two shares being the same share. Normal
    /// approximation — the sample floors above keep it honest enough for this.
    static func twoProportionP(_ hitsA: Int, _ totalA: Int, _ hitsB: Int, _ totalB: Int) -> Double {
        guard totalA > 0, totalB > 0 else { return 1 }
        let shareA = Double(hitsA) / Double(totalA)
        let shareB = Double(hitsB) / Double(totalB)
        let pooled = Double(hitsA + hitsB) / Double(totalA + totalB)
        let variance = pooled * (1 - pooled) * (1 / Double(totalA) + 1 / Double(totalB))
        guard variance > 0 else { return 1 }
        let z = abs(shareA - shareB) / variance.squareRoot()
        return erfc(z / 2.0.squareRoot())
    }

    /// Whether a finding clears the size it needs to be worth reading, once it
    /// has cleared the statistics.
    static func isWorthSaying(_ finding: SplitFinding) -> Bool {
        switch finding.display {
        case .percent: return finding.high - finding.low >= minimumGapPct
        case .perRound: return finding.high - finding.low >= minimumThreePuttGap
        }
    }
}
