//
//  CoachAdvisor.swift
//  Puttor
//
//  Reads everything the app knows about a player and says three things: how
//  the putting is going, what keeps going wrong, and what to practise. The
//  drills it names are the ones already in the app, picked for the distance
//  the numbers are worst at rather than at random.
//

import Foundation

/// A number worth putting in front of the player, with a verdict attached.
struct CoachMetric: Identifiable {
    enum Tone { case good, neutral, bad }

    let id: String
    let labelKey: String
    let value: String
    let tone: Tone
}

/// One sentence about the data. `count` and `total` fill a "%1$ld of %2$ld"
/// key; without them the key stands on its own.
struct CoachFinding: Identifiable {
    let key: String
    var count: Int?
    var total: Int?

    var id: String { key }
}

/// A drill to go and do, the reason it was chosen, and how much of it.
struct CoachRecommendation: Identifiable {
    let gameType: GameType
    let reasonKey: String
    /// Filled when the reason is a distance the player is weak from.
    var distanceM: Double?
    /// Sessions to aim for before the next read.
    var targetSessions: Int = 1
    /// Days since it was last played, where that is the point of the entry.
    var idleDays: Int?

    var id: String { "\(gameType.rawValue)-\(reasonKey)" }
}

/// Which way the putting is going, over the rounds being read.
enum CoachTrend {
    case improving, steady, slipping

    var key: String {
        switch self {
        case .improving: return "coach.trend.improving"
        case .steady: return "coach.trend.steady"
        case .slipping: return "coach.trend.slipping"
        }
    }
}

/// What the drills say, kept apart from what the course says: one is practice
/// under no pressure, the other is a scorecard.
struct CoachPractice {
    var sessions: Int = 0
    var attempts: Int = 0
    var made: Int = 0
    /// PCG over the attempts that recorded a distance; nil when the drills
    /// played don't log one.
    var pcgPerAttempt: Double?
    var makePercent: Double { attempts > 0 ? Double(made) / Double(attempts) * 100 : 0 }
    /// The drill the player converts worst in, by PCG per attempt.
    var weakestDrill: GameType?
}

struct CoachReport {
    var hasEnoughData: Bool
    var roundCount: Int
    var puttCount: Int
    var metrics: [CoachMetric] = []
    var findings: [CoachFinding] = []
    var recommendations: [CoachRecommendation] = []
    /// The bracket the player is furthest below the tour in, if there is one.
    var weakestBracketLabel: String?
    /// Which way it is going, and by how many strokes a round.
    var trend: CoachTrend?
    var trendDelta: Double = 0
    /// The drills, counted separately from the rounds.
    var practice = CoachPractice()
}

enum CoachAdvisor {
    /// Below this there is nothing to read: the advice would be about noise.
    static let minimumRounds = 2
    static let minimumPutts = 40
    /// A bracket needs this many attempts before being called a weakness.
    static let minimumBracketAttempts = 5
    static let maximumRecommendations = 3
    /// Half a stroke a round either way is a direction; less is the same
    /// putting on different days.
    static let trendThreshold = 0.5
    /// A drill left this long deserves a turn again.
    static let idleDaysBeforeRepeat = 14
    /// Below this many rounds there are not two halves to compare.
    static let minimumRoundsForTrend = 4
    /// A drill needs this many logged attempts before its PCG means anything.
    static let minimumDrillAttempts = 10

    static func report(
        rounds: [Round],
        stats: RoundStats,
        putts: [Putt],
        sessions: [GameSession]
    ) -> CoachReport {
        let realPutts = putts.filter { $0.puttNumber > 0 }
        var report = CoachReport(
            hasEnoughData: rounds.count >= minimumRounds && realPutts.count >= minimumPutts,
            roundCount: rounds.count,
            puttCount: realPutts.count
        )

        guard report.hasEnoughData else {
            report.practice = practice(in: sessions)
            report.recommendations = startingPoints()
            return report
        }

        report.practice = practice(in: sessions)
        report.metrics = metrics(from: stats, rounds: rounds.count)
        report.findings = MissPatternFinder.findings(in: putts).map {
            CoachFinding(key: $0.key, count: $0.count, total: $0.total)
        }

        let (trend, delta) = self.trend(in: rounds)
        report.trend = trend
        report.trendDelta = delta

        let weakest = weakestBracket(in: stats.makeByDistance)
        report.weakestBracketLabel = weakest?.label
        report.recommendations = plan(
            stats: stats,
            weakest: weakest,
            patterns: report.findings,
            sessions: sessions,
            trend: trend,
            practice: report.practice
        )
        return report
    }

    // MARK: - Numbers

    private static func metrics(from stats: RoundStats, rounds: Int) -> [CoachMetric] {
        let sgPerRound = rounds > 0 ? stats.sgTotal / Double(rounds) : 0
        let pcgPerRound = rounds > 0 ? stats.pcgTotal / Double(rounds) : 0

        return [
            CoachMetric(
                id: "sg",
                labelKey: "summary.sg",
                value: "\(sgPerRound > 0 ? "+" : "")\(String(format: "%.2f", sgPerRound))",
                tone: sgPerRound >= 0.5 ? .good : (sgPerRound <= -0.5 ? .bad : .neutral)
            ),
            CoachMetric(
                id: "pcg",
                labelKey: "stats.pcg",
                value: "\(pcgPerRound > 0 ? "+" : "")\(String(format: "%.2f", pcgPerRound))",
                tone: pcgPerRound >= 1 ? .good : (pcgPerRound <= -1 ? .bad : .neutral)
            ),
            CoachMetric(
                id: "perHole",
                labelKey: "summary.avgPerHole",
                value: String(format: "%.2f", stats.avgPuttsPerHole),
                tone: stats.avgPuttsPerHole < 1.7 ? .good : (stats.avgPuttsPerHole > 2 ? .bad : .neutral)
            ),
            CoachMetric(
                id: "threePutts",
                labelKey: "coach.threePuttRate",
                value: "\(Int((threePuttRate(stats) * 100).rounded()))%",
                tone: threePuttRate(stats) <= 0.05 ? .good : (threePuttRate(stats) >= 0.15 ? .bad : .neutral)
            ),
        ]
    }

    static func threePuttRate(_ stats: RoundStats) -> Double {
        guard stats.holes > 0 else { return 0 }
        return Double(stats.threePuttHoles) / Double(stats.holes)
    }

    /// The distance the player is furthest below the tour from — the honest
    /// answer to "where am I losing it", rather than simply where they miss
    /// most, which is always the long putts.
    static func weakestBracket(in brackets: [DistanceBracket]) -> DistanceBracket? {
        brackets
            .filter { $0.total >= minimumBracketAttempts }
            .max { a, b in gapToTour(a) < gapToTour(b) }
            .flatMap { gapToTour($0) > 0 ? $0 : nil }
    }

    private static func gapToTour(_ bracket: DistanceBracket) -> Double {
        let mine = bracket.total > 0 ? Double(bracket.made) / Double(bracket.total) * 100 : 0
        return bracket.tourMakePct - mine
    }

    // MARK: - The drills

    /// Reads the drill history the way the course numbers are read: how much
    /// was played, how much of it dropped, and — where a drill logs the
    /// distance of each attempt — how that compares with the tour's odds.
    static func practice(in sessions: [GameSession]) -> CoachPractice {
        let complete = sessions.filter { $0.isComplete }
        guard !complete.isEmpty else { return CoachPractice() }

        var practice = CoachPractice(
            sessions: complete.count,
            attempts: complete.reduce(0) { $0 + $1.attemptsTotal },
            made: complete.reduce(0) { $0 + $1.madeTotal }
        )

        // Attempt-level PCG, per drill, over the attempts that carry a
        // distance. Drills counted on the green rather than in the app record
        // none, and are simply absent here.
        var pcgByDrill: [GameType: (total: Double, count: Int)] = [:]
        for session in complete {
            for attempt in session.attempts where attempt.distanceM > 0 {
                let make = StrokesGained.baseline(at: attempt.distanceM).makeProbability
                let pcg = attempt.success ? 1 - make : -make
                var entry = pcgByDrill[session.gameType] ?? (0, 0)
                entry.total += pcg
                entry.count += 1
                pcgByDrill[session.gameType] = entry
            }
        }

        let counted = pcgByDrill.values.reduce(into: (total: 0.0, count: 0)) {
            $0.total += $1.total
            $0.count += $1.count
        }
        if counted.count > 0 {
            practice.pcgPerAttempt = counted.total / Double(counted.count)
        }

        // The worst drill is the one converting furthest below the odds, over
        // enough attempts to mean it.
        practice.weakestDrill = pcgByDrill
            .filter { $0.value.count >= minimumDrillAttempts }
            .min { lhs, rhs in
                lhs.value.total / Double(lhs.value.count) < rhs.value.total / Double(rhs.value.count)
            }?
            .key

        return practice
    }

    // MARK: - What to practise

    /// The drill that trains a given distance. Short putts are a start-line
    /// problem, mid-range is where holing out is trained, and from range it is
    /// pace — so each band has its own drill.
    static func drill(forDistanceM distance: Double) -> GameType {
        if distance <= 1.2 { return .gate }
        if distance <= 3 { return .aroundTheHole }
        if distance <= 6 { return .clock }
        return .ninePutt
    }

    /// Strokes gained a round over the recent half of the rounds against the
    /// earlier half. Rounds arrive newest first.
    static func trend(in rounds: [Round]) -> (CoachTrend?, Double) {
        let scored = rounds
            .filter { !$0.putts.isEmpty }
            .sorted { $0.date < $1.date }
        guard scored.count >= minimumRoundsForTrend else { return (nil, 0) }

        let split = scored.count / 2
        func average(_ slice: ArraySlice<Round>) -> Double {
            guard !slice.isEmpty else { return 0 }
            return slice.reduce(0.0) { $0 + roundStrokesGained($1) } / Double(slice.count)
        }
        let delta = average(scored.suffix(scored.count - split)) - average(scored.prefix(split))

        if delta >= trendThreshold { return (.improving, delta) }
        if delta <= -trendThreshold { return (.slipping, delta) }
        return (.steady, delta)
    }

    private static func roundStrokesGained(_ round: Round) -> Double {
        Set(round.putts.map(\.holeNumber)).compactMap { hole in
            RoundStats.holeStrokesGained(round.putts.filter { $0.holeNumber == hole })
        }.reduce(0, +)
    }

    /// The week's work, in order: the thing that is costing strokes, the habit
    /// behind it, and whatever has been left alone too long.
    private static func plan(
        stats: RoundStats,
        weakest: DistanceBracket?,
        patterns: [CoachFinding],
        sessions: [GameSession],
        trend: CoachTrend?,
        practice: CoachPractice
    ) -> [CoachRecommendation] {
        var result: [CoachRecommendation] = []

        // Ground being lost gets more repetitions than ground being made.
        let focusSessions = trend == .slipping ? 3 : (trend == .improving ? 1 : 2)

        // 1. The distance the numbers are worst at.
        if let weakest {
            let middle = (weakest.min + min(weakest.max, weakest.min + 6)) / 2
            result.append(CoachRecommendation(
                gameType: drill(forDistanceM: middle),
                reasonKey: "coach.reason.weakDistance",
                distanceM: middle,
                targetSessions: focusSessions
            ))
        }

        // 2. What the misses keep doing, where a drill answers it.
        for pattern in patterns {
            guard let recommendation = drillForPattern(pattern.key) else { continue }
            guard !result.contains(where: { $0.gameType == recommendation.gameType }) else { continue }
            result.append(recommendation)
        }

        // 3. The drill the player converts worst in — practice has its own
        // scoreboard, and it is worth a place beside the course's.
        if let weakestDrill = practice.weakestDrill,
           !result.contains(where: { $0.gameType == weakestDrill }) {
            result.append(CoachRecommendation(gameType: weakestDrill, reasonKey: "coach.reason.weakestDrill"))
        }

        // 4. Three-putts are a pace problem before they are anything else.
        if threePuttRate(stats) >= 0.12, !result.contains(where: { $0.gameType == .ninePutt }) {
            result.append(CoachRecommendation(gameType: .ninePutt, reasonKey: "coach.reason.threePutts"))
        }

        // 5. Whatever has been sitting untouched — a plan that only ever names
        // the current weakness quietly loses everything else.
        if let idle = idleDrill(sessions: sessions, excluding: result.map(\.gameType)) {
            result.append(idle)
        }

        return Array(result.prefix(maximumRecommendations))
    }

    /// The drill left longest, whether that is a fortnight or forever.
    static func idleDrill(
        sessions: [GameSession],
        excluding: [GameType],
        now: Date = Date()
    ) -> CoachRecommendation? {
        let complete = sessions.filter { $0.isComplete }
        var candidates: [(GameType, Int?)] = []

        for type in GameType.allCases where !excluding.contains(type) {
            guard let last = complete.filter({ $0.gameType == type }).map(\.date).max() else {
                candidates.append((type, nil))
                continue
            }
            let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
            if days >= idleDaysBeforeRepeat { candidates.append((type, days)) }
        }

        // Never played comes first, then the longest wait.
        let pick = candidates.sorted { lhs, rhs in
            switch (lhs.1, rhs.1) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            case let (l?, r?): return l > r
            }
        }.first

        guard let pick else { return nil }
        return CoachRecommendation(
            gameType: pick.0,
            reasonKey: pick.1 == nil ? "coach.reason.neverPlayed" : "coach.reason.idle",
            idleDays: pick.1
        )
    }

    private static func drillForPattern(_ key: String) -> CoachRecommendation? {
        switch key {
        case "pattern.missLowSide":
            return CoachRecommendation(gameType: .aroundTheHole, reasonKey: "coach.reason.lowSide")
        case "pattern.shortPuttsLeft", "pattern.shortPuttsRight":
            return CoachRecommendation(gameType: .gate, reasonKey: "coach.reason.startLine")
        case "pattern.longPuttsShort", "pattern.longPuttsLong", "pattern.missShort", "pattern.missLong":
            return CoachRecommendation(gameType: .ninePutt, reasonKey: "coach.reason.pace")
        default:
            return nil
        }
    }

    /// Before there is data: the drills that teach the two things every putter
    /// needs — a square start line and pace from range.
    static func startingPoints() -> [CoachRecommendation] {
        [
            CoachRecommendation(gameType: .gate, reasonKey: "coach.reason.startHere"),
            CoachRecommendation(gameType: .aroundTheHole, reasonKey: "coach.reason.startHere"),
            CoachRecommendation(gameType: .ninePutt, reasonKey: "coach.reason.startHere"),
        ]
    }
}
