//
//  LadderPlan.swift
//  Puttor
//
//  The ladder: from one spot, a series of target distances the ball has to
//  finish at, each with a window either side of it. Nothing has to go in —
//  the drill is about the length of the stroke and nothing else, which is why
//  it is the one drill where holing out never comes into it.
//

import Foundation

enum LadderMode: String, CaseIterable, Identifiable {
    /// The long ladder: whole metres, from lag range down to mid range.
    case large
    /// The close ladder: half metres, where the differences are small enough
    /// that the feet have to do the work rather than the arms.
    case fine

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .large: return "game.ladder.mode.large"
        case .fine: return "game.ladder.mode.fine"
        }
    }

    var stepM: Double {
        switch self {
        case .large: return 1
        case .fine: return 0.5
        }
    }

    var shortestM: Double { 5 }

    var longestM: Double {
        switch self {
        case .large: return 20
        case .fine: return 10
        }
    }
}

enum LadderPlan {
    /// The window around each rung: 30 cm short of it or 30 cm past it still
    /// counts, anything else is a rung to play again.
    static let toleranceM = 0.3

    /// The rungs of a ladder, near end first.
    static func distances(mode: LadderMode, fromM: Double, toM: Double) -> [Double] {
        let step = mode.stepM
        let start = clamp(fromM, mode: mode)
        let end = clamp(toM, mode: mode)
        guard end >= start else { return [start] }

        var result: [Double] = []
        var distance = start
        // Rounded at every rung: repeated addition of 0.5 drifts, and a rung
        // labelled 7.499 m would be a bug the player can see.
        while distance <= end + 1e-9 {
            result.append((distance * 10).rounded() / 10)
            distance += step
        }
        return result
    }

    /// Snaps a distance onto the mode's own ladder, inside its range.
    static func clamp(_ distance: Double, mode: LadderMode) -> Double {
        let bounded = min(max(distance, mode.shortestM), mode.longestM)
        let steps = ((bounded - mode.shortestM) / mode.stepM).rounded()
        return ((mode.shortestM + steps * mode.stepM) * 10).rounded() / 10
    }

    /// The middle of the ladder, which is the distance the session is filed
    /// under and what the coach reads when it looks for a drill by range.
    static func middleDistanceM(mode: LadderMode, fromM: Double, toM: Double) -> Double {
        let rungs = distances(mode: mode, fromM: fromM, toM: toM)
        guard !rungs.isEmpty else { return fromM }
        return rungs[rungs.count / 2]
    }
}
