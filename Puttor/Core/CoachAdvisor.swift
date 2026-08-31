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

/// One sentence about the data. The numbers fill the key's placeholders in
/// order; a key with none stands on its own.
struct CoachFinding: Identifiable {
    let key: String
    var numbers: [Int] = []

    var id: String { key }

    init(key: String, numbers: [Int] = []) {
        self.key = key
        self.numbers = numbers
    }

    init(key: String, count: Int, total: Int) {
        self.init(key: key, numbers: [count, total])
    }
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

/// Which way the putting is going, and — when it is going nowhere — whether
/// that is a good place to be standing still in.
enum CoachTrend {
    case improving, slipping, steadyStrong, steadySolid, steadyWeak

    var key: String {
        switch self {
        case .improving: return "coach.trend.improving"
        case .slipping: return "coach.trend.slipping"
        case .steadyStrong: return "coach.trend.steadyStrong"
        case .steadySolid: return "coach.trend.steadySolid"
        case .steadyWeak: return "coach.trend.steadyWeak"
        }
    }

    var isImproving: Bool { self == .improving }
    var isSlipping: Bool { self == .slipping }
}

/// A distance band and what it is costing.
struct CoachWeakness {
    let label: String
    let strokesLost: Double
    let attempts: Int
    let midDistanceM: Double
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
    /// Differences that depend on the conditions rather than on the player:
    /// worth knowing before the next round rather than after it.
    var conditions: [SplitFinding] = []
    var recommendations: [CoachRecommendation] = []
    /// The bracket the player is furthest below the tour in, if there is one.
    var weakestBracketLabel: String?
    /// Which way it is going: the last few rounds against the whole window,
    /// in strokes a round, and the window's own level.
    var trend: CoachTrend?
    var trendDelta: Double = 0
    var trendBaseline: Double = 0
    var trendRecentRounds: Int = 0
    var trendWindowRounds: Int = 0
    /// The distance band costing the most strokes against the tour.
    var costliest: CoachWeakness?
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
    /// Below this many rounds there is nothing to compare against.
    static let minimumRoundsForTrend = 4
    /// The recent stretch, held against the whole window.
    static let recentRoundsForTrend = 3
    /// Standing still above this is standing still in a good place; below the
    /// other, a bad one.
    static let steadyStrongLevel = 0.5
    static let steadyWeakLevel = -0.5
    /// A drill needs this many logged attempts before its PCG means anything.
    static let minimumDrillAttempts = 10

    /// `conditionRounds` is read for the weather-and-green findings only, and
    /// may reach further back than the rounds the form is judged on: rain is
    /// rare, and a condition needs putts under it before it says anything.
    static func report(
        rounds: [Round],
        stats: RoundStats,
        putts: [Putt],
        sessions: [GameSession],
        conditionRounds: [Round]? = nil
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
        report.metrics = metrics(from: stats, rounds: rounds.count, costliest: costliestBracket(in: stats.makeByDistance))
        report.findings = MissPatternFinder.findings(in: putts).map {
            CoachFinding(key: $0.key, count: $0.count, total: $0.total)
        }
        report.conditions = SplitInsight.findings(in: conditionRounds ?? rounds)

        let reading = self.trend(in: rounds)
        report.trend = reading.trend
        report.trendDelta = reading.delta
        report.trendBaseline = reading.baseline
        report.trendRecentRounds = reading.recent
        report.trendWindowRounds = rounds.filter { !$0.putts.isEmpty }.count

        let costliest = costliestBracket(in: stats.makeByDistance)
        report.costliest = costliest
        report.weakestBracketLabel = costliest?.label
        report.recommendations = plan(
            stats: stats,
            costliest: costliest,
            patterns: report.findings,
            sessions: sessions,
            trend: reading.trend,
            practice: report.practice
        )
        return report
    }

    // MARK: - Numbers

    private static func metrics(from stats: RoundStats, rounds: Int, costliest: CoachWeakness?) -> [CoachMetric] {
        let threePutts = threePuttsPerRound(stats, rounds: rounds)
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
            // Per round rather than as a share of holes: nobody plays a
            // percentage of a green, and "one and a half a round" is a number
            // you can hold on to.
            CoachMetric(
                id: "threePutts",
                labelKey: "coach.threePuttRate",
                value: String(format: "%.1f", threePutts),
                tone: threePutts <= 0.9 ? .good : (threePutts >= 2.7 ? .bad : .neutral)
            ),
            // Putts per hole says nothing without the distances behind it —
            // two putts from 20 m is good work and from 2 m is a stroke gone.
            CoachMetric(
                id: "costliest",
                labelKey: "coach.costliestBand",
                value: costliest.map { "\($0.label) · −\(String(format: "%.1f", $0.strokesLost))" } ?? "—",
                tone: costliest == nil ? .neutral : ((costliest?.strokesLost ?? 0) >= 2 ? .bad : .neutral)
            ),
        ]
    }

    /// Three-putts a round, over the rounds actually read.
    static func threePuttsPerRound(_ stats: RoundStats, rounds: Int) -> Double {
        rounds > 0 ? Double(stats.threePuttHoles) / Double(rounds) : 0
    }

    static func threePuttRate(_ stats: RoundStats) -> Double {
        guard stats.holes > 0 else { return 0 }
        return Double(stats.threePuttHoles) / Double(stats.holes)
    }

    /// The distance band costing the most strokes: how many more putts the
    /// tour would have holed from there, which is what the gap actually costs
    /// — a wide gap over four putts is worth less than a narrow one over
    /// thirty.
    static func costliestBracket(in brackets: [DistanceBracket]) -> CoachWeakness? {
        brackets
            .filter { $0.total >= minimumBracketAttempts }
            .map { bracket -> CoachWeakness in
                let mine = Double(bracket.made) / Double(bracket.total) * 100
                let lost = Double(bracket.total) * (bracket.tourMakePct - mine) / 100
                return CoachWeakness(
                    label: bracket.label,
                    strokesLost: lost,
                    attempts: bracket.total,
                    midDistanceM: (bracket.min + min(bracket.max, bracket.min + 6)) / 2
                )
            }
            .filter { $0.strokesLost > 0 }
            .max { $0.strokesLost < $1.strokesLost }
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

    /// The last few rounds held against the whole window, rather than one half
    /// against the other: what matters is whether the recent putting sits
    /// above or below where the player has been, not how two arbitrary halves
    /// compare.
    static func trend(in rounds: [Round]) -> (trend: CoachTrend?, delta: Double, baseline: Double, recent: Int) {
        let scored = rounds
            .filter { !$0.putts.isEmpty }
            .sorted { $0.date > $1.date }
        guard scored.count >= minimumRoundsForTrend else { return (nil, 0, 0, 0) }

        let recent = Array(scored.prefix(recentRoundsForTrend))
        func average(_ list: [Round]) -> Double {
            guard !list.isEmpty else { return 0 }
            return list.reduce(0.0) { $0 + roundStrokesGained($1) } / Double(list.count)
        }

        let baseline = average(scored)
        let delta = average(recent) - baseline

        if delta >= trendThreshold { return (.improving, delta, baseline, recent.count) }
        if delta <= -trendThreshold { return (.slipping, delta, baseline, recent.count) }
        // Standing still is only bad news when the place itself is.
        if baseline >= steadyStrongLevel { return (.steadyStrong, delta, baseline, recent.count) }
        if baseline <= steadyWeakLevel { return (.steadyWeak, delta, baseline, recent.count) }
        return (.steadySolid, delta, baseline, recent.count)
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
        costliest: CoachWeakness?,
        patterns: [CoachFinding],
        sessions: [GameSession],
        trend: CoachTrend?,
        practice: CoachPractice
    ) -> [CoachRecommendation] {
        var result: [CoachRecommendation] = []

        // Ground being lost gets more repetitions than ground being made.
        let focusSessions = trend?.isSlipping == true ? 3 : (trend?.isImproving == true ? 1 : 2)

        // 1. The distance costing the most strokes.
        if let costliest {
            result.append(CoachRecommendation(
                gameType: drill(forDistanceM: costliest.midDistanceM),
                reasonKey: "coach.reason.weakDistance",
                distanceM: costliest.midDistanceM,
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
