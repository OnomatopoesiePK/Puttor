//
//  ScoreCategory.swift
//  Puttor
//
//  "Putt for eagle/birdie/par/bogey/DB", then +3 through +6 — new vs. the
//  prototype. First putt of a hole is chosen by the player; each subsequent
//  putt on the same hole automatically steps one category worse, but stays
//  user-overridable.
//

import SwiftUI

enum ScoreCategory: String, CaseIterable, Codable, Identifiable {
    case eagle
    case birdie
    case par
    case bogey
    /// Raw value kept from when this was the catch-all "double or worse", so
    /// putts recorded before the deeper categories existed keep their meaning.
    case double = "doubleOrWorse"
    /// Likewise: these two were briefly "triple" and "triple or worse".
    case plus3 = "triple"
    case plus4 = "tripleOrWorse"
    case plus5
    case plus6

    var id: String { rawValue }

    /// Beyond double bogey the names stop being familiar, so those read as the
    /// plain stroke count over par instead.
    var labelKey: String {
        switch self {
        case .eagle: return "score.eagle"
        case .birdie: return "score.birdie"
        case .par: return "score.par"
        case .bogey: return "score.bogey"
        case .double: return "score.double"
        case .plus3: return "score.plus3"
        case .plus4: return "score.plus4"
        case .plus5: return "score.plus5"
        case .plus6: return "score.plus6"
        }
    }

    var shortLabelKey: String {
        switch self {
        case .eagle: return "score.eagle.short"
        case .birdie: return "score.birdie.short"
        case .par: return "score.par.short"
        case .bogey: return "score.bogey.short"
        case .double: return "score.double.short"
        case .plus3: return "score.plus3"
        case .plus4: return "score.plus4"
        case .plus5: return "score.plus5"
        case .plus6: return "score.plus6"
        }
    }

    /// Strokes relative to par when a putt for this category is holed — an
    /// eagle putt made is two under, a bogey putt made is one over.
    var strokesRelativeToPar: Int {
        switch self {
        case .eagle: return -2
        case .birdie: return -1
        case .par: return 0
        case .bogey: return 1
        case .double: return 2
        case .plus3: return 3
        case .plus4: return 4
        case .plus5: return 5
        case .plus6: return 6
        }
    }

    /// Standing on the green with a putt for this means the green was hit in
    /// regulation; a par putt means the green was missed and this is a scramble.
    var isGreenInRegulation: Bool { self == .eagle || self == .birdie }
    var isScrambleAttempt: Bool { self == .par }

    var color: Color {
        switch self {
        case .eagle: return Theme.categoryEagle
        case .birdie: return Theme.categoryBirdie
        case .par: return Theme.primary
        case .bogey: return Theme.categoryBogey
        case .double: return Theme.categoryDoubleOrWorse
        case .plus3, .plus4, .plus5, .plus6: return Theme.categoryTripleOrWorse
        }
    }

    /// One category worse than `self`, clamped at the deepest one.
    var next: ScoreCategory {
        switch self {
        case .eagle: return .birdie
        case .birdie: return .par
        case .par: return .bogey
        case .bogey: return .double
        case .double: return .plus3
        case .plus3: return .plus4
        case .plus4: return .plus5
        case .plus5, .plus6: return .plus6
        }
    }
}
