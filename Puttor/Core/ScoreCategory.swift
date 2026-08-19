//
//  ScoreCategory.swift
//  Puttor
//
//  "Putt for eagle/birdie/par/bogey/double/triple/triple-or-worse" — new vs.
//  the prototype. First putt of a hole is chosen by the player; each
//  subsequent putt on the same hole automatically steps one category worse,
//  but stays user-overridable.
//

import SwiftUI

enum ScoreCategory: String, CaseIterable, Codable, Identifiable {
    case eagle
    case birdie
    case par
    case bogey
    /// Raw value kept from when this was the catch-all "double or worse", so
    /// putts recorded before triple existed keep their meaning.
    case double = "doubleOrWorse"
    case triple
    case tripleOrWorse

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .eagle: return "score.eagle"
        case .birdie: return "score.birdie"
        case .par: return "score.par"
        case .bogey: return "score.bogey"
        case .double: return "score.double"
        case .triple: return "score.triple"
        case .tripleOrWorse: return "score.tripleOrWorse"
        }
    }

    var shortLabelKey: String {
        switch self {
        case .eagle: return "score.eagle.short"
        case .birdie: return "score.birdie.short"
        case .par: return "score.par.short"
        case .bogey: return "score.bogey.short"
        case .double: return "score.double.short"
        case .triple: return "score.triple.short"
        case .tripleOrWorse: return "score.tripleOrWorse.short"
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
        case .triple: return 3
        case .tripleOrWorse: return 4
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
        case .triple, .tripleOrWorse: return Theme.categoryTripleOrWorse
        }
    }

    /// One category worse than `self`, clamped at the open-ended worst case.
    var next: ScoreCategory {
        switch self {
        case .eagle: return .birdie
        case .birdie: return .par
        case .par: return .bogey
        case .bogey: return .double
        case .double: return .triple
        case .triple, .tripleOrWorse: return .tripleOrWorse
        }
    }
}
