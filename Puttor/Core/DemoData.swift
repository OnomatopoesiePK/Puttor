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
    static let roundCount = 12

    static func seedIfRequested(_ container: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        let context = ModelContext(container)
        try? context.delete(model: Putt.self)
        try? context.delete(model: Round.self)

        // The same season every launch, so a screenshot can be compared with
        // the last one.
        var rng = SeededGenerator(seed: 7)
        for index in 0..<roundCount {
            let round = Round(
                courseName: "Demo \(index + 1)",
                date: Date().addingTimeInterval(-Double(index) * 4 * 86_400),
                stimp: [8.0, 9, 10, 11].randomElement(using: &rng)!,
                isTournament: index % 4 == 0
            )
            round.isComplete = true
            round.tracksScoreCategory = true
            context.insert(round)
            for hole in 1...18 {
                addHole(hole, to: round, in: context, rng: &rng)
            }
        }
        try? context.save()
    }

    private static func addHole(_ hole: Int, to round: Round, in context: ModelContext, rng: inout SeededGenerator) {
        var category: ScoreCategory = [.birdie, .par, .par, .par, .bogey].randomElement(using: &rng)!
        var distance = Double.random(in: 0.8...14, using: &rng)
        let side = [-3.0, -2, -1, 0, 0, 1, 2, 3].randomElement(using: &rng)!
        let hill = [-2.0, -1, 0, 1, 2].randomElement(using: &rng)!
        let misses: [PuttResult] = [.short, .long, .left, .right, .shortLeft, .shortRight, .longLeft, .longRight]

        for number in 1...4 {
            let odds = StrokesGained.baseline(at: distance).makeProbability
            let holed = number == 4 || Double.random(in: 0...1, using: &rng) < odds
            let badStroke = !holed && Double.random(in: 0...1, using: &rng) < 0.25
            let putt = Putt(
                holeNumber: hole,
                puttNumber: number,
                distanceM: (distance * 10).rounded() / 10,
                sideSlopePct: number == 1 ? side : 0,
                hillSlopePct: number == 1 ? hill : 0,
                puttFor: category,
                result: holed ? .holed : misses.randomElement(using: &rng)!,
                lipOut: !holed && Double.random(in: 0...1, using: &rng) < 0.12,
                missRead: !holed && Double.random(in: 0...1, using: &rng) < 0.35,
                badStroke: badStroke,
                badStrokeType: badStroke ? BadStrokeType.allCases.randomElement(using: &rng) : nil,
                wrongAim: !holed && Double.random(in: 0...1, using: &rng) < 0.15
            )
            putt.round = round
            round.putts.append(putt)
            context.insert(putt)

            if holed { return }
            category = steppedDown(category)
            distance = Double.random(in: 0.3...2.5, using: &rng)
        }
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
