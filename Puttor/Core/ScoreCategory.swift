//
//  ScoreCategory.swift
//  Puttor
//
//  "Putt for eagle/birdie/par/bogey/double-or-worse" — new vs. the prototype.
//  First putt of a hole is chosen by the player (defaults to "par"); each
//  subsequent putt on the same hole automatically steps one category worse,
//  but stays user-overridable.
//

import SwiftUI

enum ScoreCategory: String, CaseIterable, Codable, Identifiable {
    case eagle
    case birdie
    case par
    case bogey
    case doubleOrWorse

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .eagle: return "score.eagle"
        case .birdie: return "score.birdie"
        case .par: return "score.par"
        case .bogey: return "score.bogey"
        case .doubleOrWorse: return "score.doubleOrWorse"
        }
    }

    var shortLabelKey: String {
        switch self {
        case .eagle: return "score.eagle.short"
        case .birdie: return "score.birdie.short"
        case .par: return "score.par.short"
        case .bogey: return "score.bogey.short"
        case .doubleOrWorse: return "score.doubleOrWorse.short"
        }
    }

    var color: Color {
        switch self {
        case .eagle: return Theme.categoryEagle
        case .birdie: return Theme.categoryBirdie
        case .par: return Theme.primary
        case .bogey: return Theme.categoryBogey
        case .doubleOrWorse: return Theme.categoryDoubleOrWorse
        }
    }

    /// One category worse than `self`, clamped at doubleOrWorse.
    var next: ScoreCategory {
        switch self {
        case .eagle: return .birdie
        case .birdie: return .par
        case .par: return .bogey
        case .bogey, .doubleOrWorse: return .doubleOrWorse
        }
    }
}
