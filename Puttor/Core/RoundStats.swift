//
//  RoundStats.swift
//  Puttor
//
//  Ported from the PuttTrack prototype's db/queries.ts#getRoundStats and
//  statistics.tsx#mergeStats. Miss-reason counting is extended from 2 flags
//  (missRead/badStrike) to 3 (missRead/badStroke/wrongAim).
//

import Foundation

struct DistanceBracket: Identifiable {
    let id: String
    let label: String
    let min: Double
    let max: Double
    let made: Int
    let total: Int
    let tourMakePct: Double
    let pcgTotal: Double
}

struct MissReasonCounts {
    var missRead: Int = 0
    var badStroke: Int = 0
    var wrongAim: Int = 0
    var multiple: Int = 0

    var total: Int { missRead + badStroke + wrongAim + multiple }

    static func + (lhs: MissReasonCounts, rhs: MissReasonCounts) -> MissReasonCounts {
        MissReasonCounts(
            missRead: lhs.missRead + rhs.missRead,
            badStroke: lhs.badStroke + rhs.badStroke,
            wrongAim: lhs.wrongAim + rhs.wrongAim,
            multiple: lhs.multiple + rhs.multiple
        )
    }
}

struct LeaveInfo {
    var count: Int
    var avgLeaveM: Double
}

struct RoundStats {
    var totalPutts: Int = 0
    var holes: Int = 0
    var avgPuttsPerHole: Double = 0
    var sgTotal: Double = 0
    /// Gained shots per distance, summed over every putt — the make-rate view of
    /// the round, alongside but separate from strokes gained.
    var pcgTotal: Double = 0
    var makeByDistance: [DistanceBracket] = []
    /// Make % by distance bracket, filtered to putts taken "for" a given score (birdie/par/bogey).
    var makeByCategory: [ScoreCategory: [DistanceBracket]] = [:]
    var missCounts: [PuttResult: Int] = [:]
    var puttsByHole: [Int: Int] = [:]
    var leaveByMissDirection: [PuttResult: LeaveInfo] = [:]
    var missReasonCounts: MissReasonCounts = MissReasonCounts()
    /// Putts that caught the lip and stayed out — misses that were nearly in.
    var lipOutCount: Int = 0

    /// Holes reached with a putt for eagle or birdie — the green was hit in
    /// regulation. A hole-out for one of those counts too.
    var girCount: Int = 0
    /// Holes played for par with the green missed — up-and-down attempts.
    var scrambleAttempts: Int = 0
    /// Of those, how many were saved (one putt, or holed out from off the green).
    var scrambleSuccesses: Int = 0

    /// Greens hit in regulation that were turned into a birdie or better —
    /// the chance taken rather than the chance had.
    var girConversions: Int = 0
    var girConversionPercent: Double { girCount > 0 ? Double(girConversions) / Double(girCount) * 100 : 0 }

    /// Putts taken on holes reached in regulation, and on the ones that
    /// weren't — counted only over holes that were actually putted, since a
    /// hole-out says nothing about putting.
    var girPutts: Int = 0
    var girPuttedHoles: Int = 0
    var nonGirPutts: Int = 0
    var nonGirPuttedHoles: Int = 0
    /// First-putt distances on greens hit in regulation: how close the
    /// approach left the ball.
    var girProximitySumM: Double = 0
    var girProximityCount: Int = 0

    var avgPuttsOnGir: Double? { girPuttedHoles > 0 ? Double(girPutts) / Double(girPuttedHoles) : nil }
    var avgPuttsOffGir: Double? { nonGirPuttedHoles > 0 ? Double(nonGirPutts) / Double(nonGirPuttedHoles) : nil }
    var avgGirProximityM: Double? { girProximityCount > 0 ? girProximitySumM / Double(girProximityCount) : nil }

    /// Total strokes over/under par across the scored holes.
    var scoreRelativeToPar: Int = 0
    /// Holes the score could be derived for — the divisor behind any average.
    var scoredHoles: Int = 0

    var girPercent: Double { holes > 0 ? Double(girCount) / Double(holes) * 100 : 0 }
    var scramblePercent: Double { scrambleAttempts > 0 ? Double(scrambleSuccesses) / Double(scrambleAttempts) * 100 : 0 }

    /// "+3", "-2", "E" — the usual golf shorthand.
    var scoreRelativeToParText: String {
        if scoreRelativeToPar == 0 { return "E" }
        return scoreRelativeToPar > 0 ? "+\(scoreRelativeToPar)" : "\(scoreRelativeToPar)"
    }

    /// Strokes over/under par for one hole.
    ///
    /// A putt is labelled with the score it would earn if holed, so the first
    /// putt's category sets the baseline and every putt after it adds a stroke:
    /// a birdie putt holed is -1, two-putted is level, three-putted is +1. A
    /// hole-out has no putts, so its own category is the score outright.
    static func holeScoreRelativeToPar(_ holePutts: [Putt]) -> Int? {
        let realPutts = holePutts.filter { $0.puttNumber > 0 }.sorted { $0.puttNumber < $1.puttNumber }
        if let first = realPutts.first {
            return first.puttFor.strokesRelativeToPar + (realPutts.count - 1)
        }
        guard let sentinel = holePutts.first(where: { $0.puttNumber == 0 }) else { return nil }
        return sentinel.puttFor.strokesRelativeToPar
    }

    /// Strokes gained for a whole hole: the putts the tour would expect from
    /// where you first stood, less the putts you actually took. Holing a 2.0
    /// expected-putts green in one is +1.0.
    ///
    /// Only holes that were putted have one — holing out from off the green
    /// isn't a putting result, so it has no putting strokes gained.
    static func holeStrokesGained(_ holePutts: [Putt]) -> Double? {
        let realPutts = holePutts.filter { $0.puttNumber > 0 }.sorted { $0.puttNumber < $1.puttNumber }
        guard let first = realPutts.first else { return nil }
        return StrokesGained.baseline(at: first.distanceM).expectedPutts - Double(realPutts.count)
    }

    /// The category a hole was played for: the first putt's, or the hole-out's.
    static func holeCategory(_ holePutts: [Putt]) -> ScoreCategory? {
        let realPutts = holePutts.filter { $0.puttNumber > 0 }.sorted { $0.puttNumber < $1.puttNumber }
        if let first = realPutts.first { return first.puttFor }
        return holePutts.first(where: { $0.puttNumber == 0 })?.puttFor
    }

    static let situationCategories: [ScoreCategory] = [.birdie, .par, .bogey]

    static let bracketsMetric: [(label: String, min: Double, max: Double)] = [
        ("0–1m", 0, 1), ("1–2m", 1, 2), ("2–3m", 2, 3), ("3–4m", 3, 4),
        ("4–5m", 4, 5), ("5–6m", 5, 6), ("6–7m", 6, 7), ("7–9m", 7, 9),
        ("9–12m", 9, 12), ("12–15m", 12, 15), ("15–20m", 15, 20), ("20+m", 20, 999),
    ]

    /// Always in fixed 3 ft steps, per the user's preference — a straight
    /// conversion of the metric brackets would produce uneven, non-round
    /// foot boundaries.
    static let bracketsFeet: [(label: String, min: Double, max: Double)] = {
        var result: [(String, Double, Double)] = []
        var ft = 0
        while ft < 30 {
            let next = ft + 3
            result.append(("\(ft)–\(next)ft", UnitConverter.feetToMetres(Double(ft)), UnitConverter.feetToMetres(Double(next))))
            ft = next
        }
        result.append(("30+ft", UnitConverter.feetToMetres(30), 999))
        return result
    }()

    static func brackets(useFeet: Bool) -> [(label: String, min: Double, max: Double)] {
        useFeet ? bracketsFeet : bracketsMetric
    }

    /// The tour's make % for a bracket depends only on the bracket, so it is
    /// worked out once per table rather than for every round on every redraw.
    private static let metricTourMakePct: [Double] = bracketsMetric.map {
        computeAverageTourMakePct(min: $0.min, max: $0.max)
    }
    private static let feetTourMakePct: [Double] = bracketsFeet.map {
        computeAverageTourMakePct(min: $0.min, max: $0.max)
    }

    private static func tourMakePct(index: Int, useFeet: Bool) -> Double {
        let table = useFeet ? feetTourMakePct : metricTourMakePct
        return index < table.count ? table[index] : 0
    }

    private static func computeAverageTourMakePct(min: Double, max: Double) -> Double {
        let baselineMax = StrokesGained.tourBaseline.last?.distanceM ?? 30
        let effectiveMax = max >= 999 ? baselineMax : max
        var samples: [Double] = []
        var d = min
        while d <= effectiveMax + 1e-9 {
            samples.append(StrokesGained.baseline(at: (d * 10).rounded() / 10).makeProbability * 100)
            d += 0.5
        }
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }

    static func compute(putts: [Putt], useFeet: Bool = false) -> RoundStats {
        var stats = RoundStats()

        // puttNumber == 0 is a sentinel for "holed out from off the green, 0 putts" —
        // it marks the hole as played but isn't itself a putt for counting/SG/category purposes.
        let realPutts = putts.filter { $0.puttNumber > 0 }
        stats.totalPutts = realPutts.count

        let holeSet = Set(putts.map { $0.holeNumber })
        stats.holes = holeSet.count
        stats.avgPuttsPerHole = stats.holes > 0 ? Double(stats.totalPutts) / Double(stats.holes) : 0
        // Summed per hole rather than per putt — see holeStrokesGained.
        stats.sgTotal = holeSet.compactMap { hole in
            holeStrokesGained(putts.filter { $0.holeNumber == hole })
        }.reduce(0, +)

        for hole in holeSet { stats.puttsByHole[hole] = 0 }
        for p in realPutts {
            stats.puttsByHole[p.holeNumber, default: 0] += 1
            stats.missCounts[p.result, default: 0] += 1
            if p.lipOut && !p.result.isHoled { stats.lipOutCount += 1 }
        }

        stats.pcgTotal = realPutts.reduce(0.0) { $0 + $1.pcg }
        stats.makeByDistance = computeDistanceBrackets(realPutts, useFeet: useFeet)

        for category in situationCategories {
            let categoryPutts = realPutts.filter { $0.puttFor == category }
            stats.makeByCategory[category] = computeDistanceBrackets(categoryPutts, useFeet: useFeet)
        }

        stats.missReasonCounts = computeMissReasonCounts(realPutts)
        stats.leaveByMissDirection = computeLeaveByMissDirection(realPutts)

        // Scoring, GIR and scramble are per hole rather than per putt, so that a
        // hole holed out from off the green counts under the category it was
        // holed out for instead of being skipped for having no putts.
        for hole in holeSet {
            let holePutts = putts.filter { $0.holeNumber == hole }
            guard let category = holeCategory(holePutts) else { continue }
            let realOnHole = holePutts.filter { $0.puttNumber > 0 }
            let isHoleOut = realOnHole.isEmpty

            if let score = holeScoreRelativeToPar(holePutts) {
                stats.scoreRelativeToPar += score
                stats.scoredHoles += 1
            }

            if category.isGreenInRegulation {
                stats.girCount += 1
                // Converted means the hole actually came in under par, however
                // many putts it took to get there.
                if let score = holeScoreRelativeToPar(holePutts), score < 0 {
                    stats.girConversions += 1
                }
                if !realOnHole.isEmpty {
                    stats.girPutts += realOnHole.count
                    stats.girPuttedHoles += 1
                    if let first = realOnHole.min(by: { $0.puttNumber < $1.puttNumber }) {
                        stats.girProximitySumM += first.distanceM
                        stats.girProximityCount += 1
                    }
                }
            } else {
                if !realOnHole.isEmpty {
                    stats.nonGirPutts += realOnHole.count
                    stats.nonGirPuttedHoles += 1
                }
            }

            if !category.isGreenInRegulation, category.isScrambleAttempt {
                stats.scrambleAttempts += 1
                // Holing out from off the green is the up-and-down; with putts
                // it takes exactly one to count as saved.
                if isHoleOut || (realOnHole.count == 1 && realOnHole[0].result == .holed) {
                    stats.scrambleSuccesses += 1
                }
            }
        }

        return stats
    }

    private static func computeDistanceBrackets(_ putts: [Putt], useFeet: Bool) -> [DistanceBracket] {
        brackets(useFeet: useFeet).enumerated().map { index, b in
            let dm = putts.filter { p in
                let d = p.distanceM < 0.5 ? 0.3 : p.distanceM
                return d >= b.min && d < b.max
            }
            let made = dm.filter { $0.result == .holed }.count
            let pcg = dm.reduce(0.0) { $0 + $1.pcg }
            return DistanceBracket(
                id: b.label, label: b.label, min: b.min, max: b.max,
                made: made, total: dm.count,
                tourMakePct: tourMakePct(index: index, useFeet: useFeet),
                pcgTotal: pcg
            )
        }
    }

    static func computeMissReasonCounts(_ putts: [Putt]) -> MissReasonCounts {
        var result = MissReasonCounts()
        for p in putts {
            let flags = [p.missRead, p.badStroke, p.wrongAim]
            let count = flags.filter { $0 }.count
            if count == 0 { continue }
            if count >= 2 { result.multiple += 1; continue }
            if p.missRead { result.missRead += 1 }
            else if p.badStroke { result.badStroke += 1 }
            else if p.wrongAim { result.wrongAim += 1 }
        }
        return result
    }

    static func computeLeaveByMissDirection(_ putts: [Putt]) -> [PuttResult: LeaveInfo] {
        var byHole: [String: [Putt]] = [:]
        for p in putts {
            let key = "\(p.round?.id.uuidString ?? "-")-\(p.holeNumber)"
            byHole[key, default: []].append(p)
        }

        var leaveSamples: [PuttResult: [Double]] = [:]
        for holePutts in byHole.values {
            var byPuttNumber: [Int: Putt] = [:]
            for p in holePutts {
                if let existing = byPuttNumber[p.puttNumber] {
                    if p.createdAt > existing.createdAt { byPuttNumber[p.puttNumber] = p }
                } else {
                    byPuttNumber[p.puttNumber] = p
                }
            }
            let sorted = byPuttNumber.values.sorted {
                $0.puttNumber != $1.puttNumber ? $0.puttNumber < $1.puttNumber : $0.createdAt < $1.createdAt
            }
            guard sorted.count > 1 else { continue }
            for i in 0..<(sorted.count - 1) {
                let p = sorted[i]
                if p.result == .holed { continue }
                let next = sorted[i + 1]
                leaveSamples[p.result, default: []].append(Swift.max(0.3, next.distanceM))
            }
        }

        var out: [PuttResult: LeaveInfo] = [:]
        for (dir, samples) in leaveSamples where !samples.isEmpty {
            let avg = samples.reduce(0, +) / Double(samples.count)
            out[dir] = LeaveInfo(count: samples.count, avgLeaveM: avg)
        }
        return out
    }

    /// Combine several rounds' stats into one aggregate (statistics tab filters).
    static func merge(_ list: [RoundStats], useFeet: Bool = false) -> RoundStats {
        guard !list.isEmpty else { return RoundStats() }

        var merged = RoundStats()
        merged.totalPutts = list.reduce(0) { $0 + $1.totalPutts }
        merged.holes = list.reduce(0) { $0 + $1.holes }
        merged.sgTotal = list.reduce(0) { $0 + $1.sgTotal }
        merged.avgPuttsPerHole = merged.holes > 0 ? Double(merged.totalPutts) / Double(merged.holes) : 0

        merged.makeByDistance = mergeBracketLists(list.map { $0.makeByDistance }, useFeet: useFeet)

        for category in situationCategories {
            merged.makeByCategory[category] = mergeBracketLists(list.map { $0.makeByCategory[category] ?? [] }, useFeet: useFeet)
        }

        for r in list {
            for (k, v) in r.missCounts { merged.missCounts[k, default: 0] += v }
            merged.missReasonCounts = merged.missReasonCounts + r.missReasonCounts
        }

        merged.lipOutCount = list.reduce(0) { $0 + $1.lipOutCount }
        merged.girCount = list.reduce(0) { $0 + $1.girCount }
        merged.girConversions = list.reduce(0) { $0 + $1.girConversions }
        merged.girPutts = list.reduce(0) { $0 + $1.girPutts }
        merged.girPuttedHoles = list.reduce(0) { $0 + $1.girPuttedHoles }
        merged.nonGirPutts = list.reduce(0) { $0 + $1.nonGirPutts }
        merged.nonGirPuttedHoles = list.reduce(0) { $0 + $1.nonGirPuttedHoles }
        merged.girProximitySumM = list.reduce(0) { $0 + $1.girProximitySumM }
        merged.girProximityCount = list.reduce(0) { $0 + $1.girProximityCount }
        merged.scrambleAttempts = list.reduce(0) { $0 + $1.scrambleAttempts }
        merged.scrambleSuccesses = list.reduce(0) { $0 + $1.scrambleSuccesses }
        merged.scoreRelativeToPar = list.reduce(0) { $0 + $1.scoreRelativeToPar }
        merged.scoredHoles = list.reduce(0) { $0 + $1.scoredHoles }

        var leaveAcc: [PuttResult: (totalDist: Double, count: Int)] = [:]
        for r in list {
            for (dir, info) in r.leaveByMissDirection {
                var acc = leaveAcc[dir] ?? (0, 0)
                acc.totalDist += info.avgLeaveM * Double(info.count)
                acc.count += info.count
                leaveAcc[dir] = acc
            }
        }
        for (dir, acc) in leaveAcc where acc.count > 0 {
            merged.leaveByMissDirection[dir] = LeaveInfo(count: acc.count, avgLeaveM: acc.totalDist / Double(acc.count))
        }

        return merged
    }

    private static func mergeBracketLists(_ lists: [[DistanceBracket]], useFeet: Bool) -> [DistanceBracket] {
        brackets(useFeet: useFeet).enumerated().map { idx, b in
            let made = lists.reduce(0) { $0 + (idx < $1.count ? $1[idx].made : 0) }
            let total = lists.reduce(0) { $0 + (idx < $1.count ? $1[idx].total : 0) }
            let pcg = lists.reduce(0.0) { $0 + (idx < $1.count ? $1[idx].pcgTotal : 0) }
            let tourPct = lists.first?[safe: idx]?.tourMakePct ?? tourMakePct(index: idx, useFeet: useFeet)
            return DistanceBracket(id: b.label, label: b.label, min: b.min, max: b.max, made: made, total: total, tourMakePct: tourPct, pcgTotal: pcg)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
