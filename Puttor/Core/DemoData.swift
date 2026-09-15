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
    /// Custom mode as it is played now — slope typed on the keypad, the result
    /// on the dial, the intention asked — and three rounds entered with it.
    /// Adds to the rounds already there, replacing only those simulated before;
    /// with `-PuttorNoRounds` as well, the three are all there is.
    static let simulatedRoundsArgument = "-PuttorSimulatedRounds"
    static let simulatedCourse = "Simulated"
    /// The tutorial as a first launch has it. Any other launch argument means
    /// a test that is not about the tutorial, so it stays out of the way.
    static let tutorialArgument = "-PuttorTutorial"
    static let roundCount = 12

    static func seedIfRequested(_ container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(tutorialArgument) {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.tutorialFinished)
        } else if arguments.contains(where: { $0.hasPrefix("-Puttor") }) {
            UserDefaults.standard.set(true, forKey: AppStorageKeys.tutorialFinished)
        }
        if arguments.contains(slopeNumbersArgument) {
            var config = CustomModeConfig.defaultConfig
            config.fields = [CustomField(kind: .puttForCategory), CustomField(kind: .slope, complexity: .numbers)]
            config.save()
        }
        if arguments.contains(intentionArgument) {
            var config = CustomModeConfig.defaultConfig
            config.fields = [CustomField(kind: .puttForCategory), CustomField(kind: .intention)]
            config.save()
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
