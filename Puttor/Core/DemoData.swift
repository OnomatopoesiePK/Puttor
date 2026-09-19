//
//  DemoData.swift
//  Puttor
//
//  Launch with `-PuttorDemoData` to replace every round with a dozen made-up
//  ones — enough to fill each statistics section in the simulator without
//  entering a season by hand. Debug builds only; a release build carries none
//  of it.
//

#if DEBUG
import Foundation
import SwiftData

enum DemoData {
    static let launchArgument = "-PuttorDemoData"
    /// Every round gone, for a look at the empty list.
    static let emptyArgument = "-PuttorNoRounds"
    /// Custom mode set to type the slope in numbers.
    static let slopeNumbersArgument = "-PuttorSlopeNumbers"
    /// Custom mode asking for the intention.
    static let intentionArgument = "-PuttorIntention"
    /// Custom mode with the simplified slope grid rather than the big one.
    static let simpleSlopeArgument = "-PuttorSimpleSlope"
    /// Custom mode as it is played now — slope typed on the keypad, the result
    /// on the dial, the intention asked — and three rounds entered with it.
    /// Adds to the rounds already there, replacing only those simulated before;
    /// with `-PuttorNoRounds` as well, the three are all there is.
    static let simulatedRoundsArgument = "-PuttorSimulatedRounds"
    static let simulatedCourse = "Simulated"
    /// One eighteen-hole round in Custom mode with putt 0: par and GIR
    /// opportunity asked, intentions, the result on the dial — and about a
    /// stroke gained on the greens. A green is only hit where there was a
    /// chance to hit it.
    static let puttZeroRoundArgument = "-PuttorPuttZeroRound"
    static let puttZeroCourse = "Seeblick Links"
    /// A par 72 card.
    static let puttZeroPars = [4, 5, 3, 4, 4, 3, 4, 5, 4, 4, 3, 5, 4, 4, 3, 4, 5, 4]
    /// The tutorial as a first launch has it. Any other launch argument means
    /// a test that is not about the tutorial, so it stays out of the way.
    static let tutorialArgument = "-PuttorTutorial"
    static let roundCount = 12

    static func seedIfRequested(_ container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(tutorialArgument) {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.tutorialFinished)
            // Units never chosen, so the tutorial asks for them first.
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.units)
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.defaultFirstPuttDistance)
        } else if arguments.contains(where: { $0.hasPrefix("-Puttor") }) {
            UserDefaults.standard.set(true, forKey: AppStorageKeys.tutorialFinished)
        }
        if arguments.contains(slopeNumbersArgument) {
            var config = CustomModeConfig.defaultConfig
            config.fields = [CustomField(kind: .puttForCategory), CustomField(kind: .slope, complexity: .numbers)]
            config.save()
        }
        if arguments.contains(where: { $0.hasPrefix("-Puttor") }) {
            // A test starts from a clean slate: nothing carries a heart, and
            // no way of reading is named yet.
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.favouritePutter)
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.favouriteReadingMethod)
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.customReadingMethods)
        }
        if arguments.contains(simpleSlopeArgument) {
            var config = CustomModeConfig.defaultConfig
            config.fields = [CustomField(kind: .puttForCategory), CustomField(kind: .slope, complexity: .simple)]
            config.save()
        }
        if arguments.contains(intentionArgument) {
            var config = CustomModeConfig.defaultConfig
            config.fields = [CustomField(kind: .puttForCategory), CustomField(kind: .intention)]
            config.save()
        }
        if arguments.contains(shareRoundsArgument) {
            var config = CustomModeConfig.defaultConfig
            config.fields = [
                CustomField(kind: .puttForCategory),
                CustomField(kind: .holePar),
                CustomField(kind: .girOpportunity),
                CustomField(kind: .intention),
            ]
            config.resultStyle = .angle
            config.save()
            simulateShareRounds(into: ModelContext(container))
            return
        }
        if arguments.contains(puttZeroRoundArgument) {
            var config = CustomModeConfig.defaultConfig
            config.fields = [
                CustomField(kind: .puttForCategory),
                CustomField(kind: .holePar),
                CustomField(kind: .girOpportunity),
                CustomField(kind: .intention),
            ]
            config.resultStyle = .angle
            config.save()
            simulatePuttZeroRound(into: ModelContext(container))
            return
        }
        if arguments.contains(emptyArgument) {
            let context = ModelContext(container)
            try? context.delete(model: Putt.self)
            try? context.delete(model: Round.self)
            try? context.save()
            guard arguments.contains(simulatedRoundsArgument) else { return }
        }
        if arguments.contains(simulatedRoundsArgument) {
            var config = CustomModeConfig.defaultConfig
            config.fields = [
                CustomField(kind: .puttForCategory),
                CustomField(kind: .slope, complexity: .numbers),
                CustomField(kind: .intention),
            ]
            config.resultStyle = .angle
            config.save()
            UserDefaults.standard.removeObject(forKey: "stats.sectionLayout")
            simulateRounds(into: ModelContext(container))
            return
        }
        guard arguments.contains(launchArgument) else { return }
        // The arrangements back to where they start, so every launch shows the
        // default stack.
        UserDefaults.standard.removeObject(forKey: "stats.sectionLayout")
        UserDefaults.standard.removeObject(forKey: "evolution.chartLayout")
        seed(into: ModelContext(container))
    }

    /// The demo season, into any context. `nineHoleRound` is the round played
    /// over nine holes; nil plays every one over eighteen. The tenth, so the
    /// rounds before it draw the same numbers as they did before there was a
    /// nine-hole round, and the last ten read as they always have.
    static func seed(into context: ModelContext, nineHoleRound: Int? = 9) {
        try? context.delete(model: Putt.self)
        try? context.delete(model: Round.self)

        // The same season every launch, so a screenshot can be compared with
        // the last one.
        var rng = SeededGenerator(seed: 7)
        var intentions = SeededGenerator(seed: 11)
        for index in 0..<roundCount {
            let round = Round(
                courseName: "Demo \(index + 1)",
                date: Date().addingTimeInterval(-Double(index) * 4 * 86_400),
                stimp: [8.0, 9, 10, 11].randomElement(using: &rng)!,
                isTournament: index % 4 == 0
            )
            round.isComplete = true
            // Every fifth without a score reference, so the notes that only
            // appear for mixed selections show up too.
            round.tracksScoreCategory = index % 5 != 2
            // One round over nine holes, so its asterisk shows up too.
            round.holeCount = index == nineHoleRound ? 9 : 18
            context.insert(round)
            for hole in 1...round.holeCount {
                addHole(hole, to: round, in: context, rng: &rng, intentions: &intentions)
            }
        }
        try? context.save()
    }

    private static func addHole(_ hole: Int, to round: Round, in context: ModelContext, rng: inout SeededGenerator, intentions: inout SeededGenerator) {
        var category: ScoreCategory = [.birdie, .par, .par, .par, .bogey].randomElement(using: &rng)!
        var distance = Double.random(in: 0.8...14, using: &rng)
        let side = [-3.0, -2, -1, 0, 0, 1, 2, 3].randomElement(using: &rng)!
        let hill = [-2.0, -1, 0, 1, 2].randomElement(using: &rng)!
        let misses: [PuttResult] = [.short, .long, .left, .right, .shortLeft, .shortRight, .longLeft, .longRight]

        for number in 1...4 {
            let odds = StrokesGained.baseline(at: distance).makeProbability
            let holed = number == 4 || Double.random(in: 0...1, using: &rng) < odds
            let result: PuttResult = holed ? .holed : misses.randomElement(using: &rng)!
            let badStroke = !holed && Double.random(in: 0...1, using: &rng) < 0.25
            let putt = Putt(
                holeNumber: hole,
                puttNumber: number,
                distanceM: (distance * 10).rounded() / 10,
                sideSlopePct: number == 1 ? side : 0,
                hillSlopePct: number == 1 ? hill : 0,
                puttFor: category,
                result: result,
                lipOut: !holed && Double.random(in: 0...1, using: &rng) < 0.12,
                missRead: !holed && Double.random(in: 0...1, using: &rng) < 0.35,
                badStroke: badStroke,
                badStrokeType: badStroke ? BadStrokeType.allCases.randomElement(using: &rng) : nil,
                wrongAim: !holed && Double.random(in: 0...1, using: &rng) < 0.15
            )
            if number == 1 && distance >= 1.5 {
                putt.intention = intention(at: distance, holed: holed, rng: &intentions)
            }
            putt.round = round
            round.putts.append(putt)
            context.insert(putt)

            if holed { return }
            category = steppedDown(category)
            // Like real misses: well long or short, seldom far to the side.
            let furthest = result.lengthBias == 0 ? 1.2 : (result.lateralBias == 0 ? 2.5 : 2.0)
            distance = Double.random(in: 0.3...furthest, using: &rng)
        }
    }

    /// Long ones dying at the hole, the rest mostly at a normal pace; played
    /// as meant more often when they drop.
    private static func intention(at distance: Double, holed: Bool, rng: inout SeededGenerator) -> PuttIntention {
        let speed: PuttSpeed = distance > 9 ? .dieIn : [.dieIn, .normal, .normal, .firm].randomElement(using: &rng)!
        let line = PuttLine.allCases.randomElement(using: &rng)!
        let executed = Double.random(in: 0...1, using: &rng) < (holed ? 0.85 : 0.55)
        return PuttIntention(speed: speed, line: line, executed: executed)
    }

    // MARK: - Simulated rounds

    /// Three rounds as the custom mode enters them now: every putt's slope to a
    /// tenth of a percent, every miss where it finished on the dial, every putt
    /// with an intention — the second round in match play, so the situation is
    /// asked too. Earlier simulated rounds make way; nothing else is touched.
    static func simulateRounds(into context: ModelContext) {
        let rounds = (try? context.fetch(FetchDescriptor<Round>())) ?? []
        for round in rounds where round.courseName.hasPrefix(simulatedCourse) {
            context.delete(round)
        }

        var rng = SeededGenerator(seed: 23)
        for index in 0..<3 {
            let round = Round(
                courseName: "\(simulatedCourse) \(index + 1)",
                date: Date().addingTimeInterval(-Double(index) * 86_400),
                stimp: [9.5, 10.5, 11][index],
                isTournament: index == 2,
                playFormat: index == 1 ? .matchPlay : .strokePlay,
                inputMode: .custom
            )
            round.readingMethod = [ReadingMethod(.aimPoint), ReadingMethod(.hybrid), ReadingMethod(custom: "Plumb bob")][index]
            round.tracksScoreCategory = true
            round.isComplete = true
            context.insert(round)
            for hole in 1...18 {
                simulateHole(hole, of: round, in: context, rng: &rng)
            }
        }
        try? context.save()
    }

    private static func simulateHole(_ hole: Int, of round: Round, in context: ModelContext, rng: inout SeededGenerator) {
        let matchPlay = round.playFormat == .matchPlay
        var category: ScoreCategory = [.birdie, .par, .par, .par, .bogey].randomElement(using: &rng)!
        var distance = tenth(Double.random(in: 1...13, using: &rng))

        for number in 1...4 {
            // Follow-ups are short, so their slope reads gentler.
            let reach = number == 1 ? 1.0 : 0.6
            let side = tenth(Double.random(in: -4.5...4.5, using: &rng) * reach)
            let hill = tenth(Double.random(in: -3...3, using: &rng) * reach)
            let intention = simulatedIntention(distance: distance, side: side, matchPlay: matchPlay, rng: &rng)
            // Played as meant, a putt drops more often.
            let odds = StrokesGained.baseline(at: distance).makeProbability * (intention.executed == true ? 1.15 : 0.7)
            let holed = number == 4 || Double.random(in: 0...1, using: &rng) < min(0.98, odds)
            let angle = holed ? nil : simulatedMissAngle(side: side, speed: intention.speed, rng: &rng)

            let putt = Putt(
                holeNumber: hole,
                puttNumber: number,
                distanceM: distance,
                sideSlopePct: side,
                hillSlopePct: hill,
                puttFor: category,
                result: angle.map(MissAngle.result(for:)) ?? .holed,
                lipOut: !holed && Double.random(in: 0...1, using: &rng) < 0.1,
                missAngleDeg: angle
            )
            putt.intention = intention
            putt.round = round
            round.putts.append(putt)
            context.insert(putt)

            guard let angle else { return }
            category = steppedDown(category)
            distance = simulatedLeave(angle: angle, intention: intention, from: distance, rng: &rng)
        }
    }

    /// One putt of a planned hole, before it becomes a Putt.
    private struct PlannedPutt {
        var distance: Double
        var side: Double
        var hill: Double
        var category: ScoreCategory
        var intention: PuttIntention
        var angle: Double?
        var lipOut: Bool
    }

    private struct PlannedHole {
        var par: Int
        var girOpportunity: Bool
        var putts: [PlannedPutt]
    }

    /// The round of `puttZeroRoundArgument`. Seeds are tried in turn until
    /// the putting comes to about one stroke gained, so the round is the same
    /// on every launch.
    static func simulatePuttZeroRound(into context: ModelContext) {
        let rounds = (try? context.fetch(FetchDescriptor<Round>())) ?? []
        for round in rounds where round.courseName == puttZeroCourse {
            context.delete(round)
        }
        simulateRound(named: puttZeroCourse, on: Date(), holes: 18, withHoleDetails: true, gaining: 1, everyScore: false, into: context)
        try? context.save()
    }

    /// Four rounds to share: eighteen holes and nine, each once with putt 0
    /// asking the par and the GIR opportunity and once without it, every
    /// score from eagle to double bogey in each, and two strokes gained in
    /// one of each pair and two lost in the other.
    static let shareRoundsArgument = "-PuttorShareRounds"
    static let shareRoundsOtherCourse = "Au Park"

    static func simulateShareRounds(into context: ModelContext) {
        let rounds = (try? context.fetch(FetchDescriptor<Round>())) ?? []
        for round in rounds where round.courseName == puttZeroCourse || round.courseName == shareRoundsOtherCourse {
            context.delete(round)
        }
        let day: TimeInterval = 86_400
        simulateRound(named: puttZeroCourse, on: Date().addingTimeInterval(-day), holes: 18, withHoleDetails: true, gaining: 2, everyScore: true, into: context)
        simulateRound(named: shareRoundsOtherCourse, on: Date().addingTimeInterval(-2 * day), holes: 18, withHoleDetails: false, gaining: -2, everyScore: true, into: context)
        simulateRound(named: puttZeroCourse, on: Date().addingTimeInterval(-3 * day), holes: 9, withHoleDetails: true, gaining: -2, everyScore: true, into: context)
        simulateRound(named: shareRoundsOtherCourse, on: Date().addingTimeInterval(-4 * day), holes: 9, withHoleDetails: false, gaining: 2, everyScore: true, into: context)
        try? context.save()
    }

    /// A round in Custom mode on the par 72 card, with intentions and the
    /// dial. Seeds are tried in turn until the putting gains about `gaining`
    /// strokes and — where `everyScore` — an eagle, a birdie, a par, a bogey
    /// and a double or worse are all on the card, so the same round comes
    /// back on every launch. With the hole details the par and GIR
    /// opportunity of each hole are kept; a green is only hit where there
    /// was a chance to hit it either way.
    @discardableResult
    static func simulateRound(named name: String, on date: Date, holes: Int, withHoleDetails: Bool,
                              gaining target: Double, everyScore: Bool, into context: ModelContext) -> Round {
        let pars = Array(puttZeroPars.prefix(holes))
        var plan: [PlannedHole] = []
        var best = Double.infinity
        for seed in UInt64(1)...400_000 {
            var rng = SeededGenerator(seed: seed &* 7919 &+ UInt64(holes))
            let candidate = pars.map { planHole(par: $0, rng: &rng) }
            let gained = candidate.reduce(0.0) { total, hole in
                total + StrokesGained.baseline(at: hole.putts[0].distance).expectedPutts - Double(hole.putts.count)
            }
            let scores = Set(candidate.map { hole in min(2, max(-2, hole.putts[0].category.strokesRelativeToPar + hole.putts.count - 1)) })
            let covers = !everyScore || scores.isSuperset(of: [-2, -1, 0, 1, 2])
            guard covers else { continue }
            let miss = abs(gained - target)
            if miss < best {
                best = miss
                plan = candidate
            }
            if miss < 0.12 { break }
        }

        let round = Round(courseName: name, date: date, stimp: 10, inputMode: .custom)
        round.holeCount = holes
        round.readingMethod = ReadingMethod(.aimPoint)
        round.tracksScoreCategory = true
        round.isComplete = true
        context.insert(round)
        var details: [Int: HoleDetails] = [:]
        for (index, hole) in plan.enumerated() {
            let number = index + 1
            if withHoleDetails {
                details[number] = HoleDetails(par: hole.par, girOpportunity: hole.girOpportunity)
            }
            for (puttIndex, planned) in hole.putts.enumerated() {
                let putt = Putt(
                    holeNumber: number,
                    puttNumber: puttIndex + 1,
                    distanceM: planned.distance,
                    sideSlopePct: planned.side,
                    hillSlopePct: planned.hill,
                    puttFor: planned.category,
                    result: planned.angle.map(MissAngle.result(for:)) ?? .holed,
                    lipOut: planned.lipOut,
                    missAngleDeg: planned.angle
                )
                putt.intention = planned.intention
                putt.createdAt = date.addingTimeInterval(Double(number * 10 + puttIndex) - 400)
                putt.round = round
                round.putts.append(putt)
                context.insert(putt)
            }
        }
        round.holeDetails = details
        return round
    }

    /// A hole: a chance at the green about two times in three, the green hit
    /// on most of those and never without one, then putted out.
    private static func planHole(par: Int, rng: inout SeededGenerator) -> PlannedHole {
        let opportunity = Double.random(in: 0...1, using: &rng) < 0.65
        let greenHit = opportunity && Double.random(in: 0...1, using: &rng) < 0.7
        var category: ScoreCategory
        var distance: Double
        if greenHit {
            // In regulation: for birdie, or for eagle on a par 5 reached in two.
            category = par == 5 && Double.random(in: 0...1, using: &rng) < 0.25 ? .eagle : .birdie
            distance = tenth(Double.random(in: 3...14, using: &rng))
        } else {
            // Up and down to save par, or a bogey putt after a worse miss.
            category = Double.random(in: 0...1, using: &rng) < 0.75 ? .par : .bogey
            distance = tenth(Double.random(in: 0.8...5, using: &rng))
        }

        var putts: [PlannedPutt] = []
        for number in 1...4 {
            let reach = number == 1 ? 1.0 : 0.6
            let side = tenth(Double.random(in: -4...4, using: &rng) * reach)
            let hill = tenth(Double.random(in: -3...3, using: &rng) * reach)
            let intention = simulatedIntention(distance: distance, side: side, matchPlay: false, rng: &rng)
            let odds = StrokesGained.baseline(at: distance).makeProbability * (intention.executed == true ? 1.2 : 0.75)
            let holed = number == 4 || Double.random(in: 0...1, using: &rng) < min(0.99, odds)
            let angle = holed ? nil : simulatedMissAngle(side: side, speed: intention.speed, rng: &rng)
            putts.append(PlannedPutt(
                distance: distance, side: side, hill: hill, category: category, intention: intention,
                angle: angle, lipOut: !holed && Double.random(in: 0...1, using: &rng) < 0.1
            ))
            guard let angle else { break }
            category = steppedDown(category)
            distance = simulatedLeave(angle: angle, intention: intention, from: distance, rng: &rng)
        }
        return PlannedHole(par: par, girOpportunity: opportunity, putts: putts)
    }

    /// Tap-ins firm, long ones dying at the hole, a line that allows for more
    /// the more it breaks, and in match play what the other player left.
    private static func simulatedIntention(distance: Double, side: Double, matchPlay: Bool, rng: inout SeededGenerator) -> PuttIntention {
        let speed: PuttSpeed
        switch distance {
        case ..<0.8: speed = .firm
        case ..<3.5: speed = [.dieIn, .normal, .normal, .firm].randomElement(using: &rng)!
        case ...9.0: speed = [.dieIn, .normal].randomElement(using: &rng)!
        default: speed = .dieIn
        }

        let line: PuttLine
        switch abs(side) {
        case ..<0.5: line = .centre
        case ..<1.5: line = [.centre, .insideEdge, .insideEdge].randomElement(using: &rng)!
        case ..<3: line = [.insideEdge, .outsideEdge].randomElement(using: &rng)!
        default: line = [.outsideEdge, .outsideHole].randomElement(using: &rng)!
        }

        let situation: PuttSituation? = !matchPlay ? nil
            : distance > 9 ? .secure
            : PuttSituation.allCases.randomElement(using: &rng)!
        let executed = Double.random(in: 0...1, using: &rng) < (distance < 0.8 ? 0.95 : 0.7)
        return PuttIntention(speed: speed, line: line, situation: situation, executed: executed)
    }

    /// Where a miss finished on the dial: more often below the hole than above
    /// it on a breaking putt, more often short at a dying pace and long at a
    /// firm one.
    private static func simulatedMissAngle(side: Double, speed: PuttSpeed?, rng: inout SeededGenerator) -> Double {
        let longShare = speed == .firm ? 0.7 : speed == .dieIn ? 0.3 : 0.5
        let long = Double.random(in: 0...1, using: &rng) < longShare
        let magnitude = long ? Double.random(in: 95...170, using: &rng) : Double.random(in: 10...88, using: &rng)
        // The slope falls the way its sign points: a negative side break runs
        // off to the left, so the low side is a negative angle.
        let lowSide: Double = side < 0 ? -1 : 1
        let sign: Double = abs(side) < 0.5
            ? (Bool.random(using: &rng) ? 1 : -1)
            : (Double.random(in: 0...1, using: &rng) < 0.65 ? lowSide : -lowSide)
        return MissAngle.snap(sign * magnitude)
    }

    /// How far the miss finished: close at a dying pace, further back from a
    /// firm one, and a long way off from a long way out.
    private static func simulatedLeave(angle: Double, intention: PuttIntention, from distance: Double, rng: inout SeededGenerator) -> Double {
        let long = abs(angle) > 90
        var range = long ? 0.4...1.6 : 0.3...1.2
        switch intention.speed {
        case .dieIn: range = long ? 0.3...0.8 : 0.3...1.0
        case .normal: range = long ? 0.3...0.9 : 0.3...1.0
        case .firm: range = long ? 0.8...2.2 : 0.4...1.0
        case nil: break
        }
        if distance > 9 { range = long ? 0.4...1.5 : 0.5...2.0 }
        return max(0.3, tenth(Double.random(in: range, using: &rng)))
    }

    private static func tenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private static func steppedDown(_ category: ScoreCategory) -> ScoreCategory {
        switch category {
        case .eagle: return .birdie
        case .birdie: return .par
        case .par: return .bogey
        default: return .double
        }
    }
}

/// SplitMix64: small, fast and the same on every run.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
