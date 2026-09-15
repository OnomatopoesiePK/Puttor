//
//  PuttIntention.swift
//  Puttor
//
//  What a putt was meant to do, and whether it came off. An intention has up
//  to three parts — its pace, its line, and in match play what the situation
//  asks — and each can be switched off in Settings. Whether it came off is the
//  process side: a putt played as meant that does not drop is no mistake.
//

import Foundation

/// A part of an intention the intention field asks for.
enum IntentionPart: String, Codable, CaseIterable, Identifiable {
    case speed, line, situation

    var id: String { rawValue }
    var titleKey: String { "intention.part.\(rawValue)" }
    /// For a picker of all parts, where the full title does not fit.
    var shortTitleKey: String { "intention.part.\(rawValue).short" }

    var icon: String {
        switch self {
        case .speed: return "speedometer"
        case .line: return "scope"
        case .situation: return "person.2.fill"
        }
    }
}

/// How hard the putt is meant to be struck.
enum PuttSpeed: String, Codable, CaseIterable, Identifiable {
    /// Dying at the hole: all of its width, but more break and less forgiving
    /// of a misjudged pace.
    case dieIn
    /// The player's normal pace: enough to finish a set distance past the
    /// hole, 30 cm unless changed in Settings. Stored as "pelz", the name it
    /// was first entered under.
    case normal = "pelz"
    /// Firm: less break and less of the hole, but past the bumps round the
    /// edge — at the cost of a longer one back.
    case firm

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .dieIn: return "intention.speed.dieIn"
        case .normal: return "intention.speed.normal"
        case .firm: return "intention.speed.firm"
        }
    }

    static let defaultNormalPastM = 0.3
    /// How far past the hole a normal pace can be set to finish.
    static let normalPastRange: ClosedRange<Double> = 0.2...0.8

    /// The distance past the hole in centimetres, or in inches.
    static func pastText(_ metres: Double, useFeet: Bool) -> String {
        useFeet
            ? "\(Int((metres / 0.0254).rounded())) in"
            : "\(Int((metres * 100).rounded())) cm"
    }
}

/// Where the putt is aimed at the hole.
enum PuttLine: String, Codable, CaseIterable, Identifiable {
    case centre, insideEdge, outsideEdge, outsideHole

    var id: String { rawValue }
    var labelKey: String { "intention.line.\(rawValue)" }
}

/// What the match asks of the putt.
enum PuttSituation: String, Codable, CaseIterable, Identifiable {
    /// The other player is close: this one has to go in.
    case attack
    /// The other player still has a long way: two putts are enough.
    case secure

    var id: String { rawValue }
    var labelKey: String { "intention.situation.\(rawValue)" }
}

struct PuttIntention: Equatable {
    var speed: PuttSpeed?
    var line: PuttLine?
    var situation: PuttSituation?
    /// Whether the putt was played as meant; nil when not said.
    var executed: Bool?

    var isEmpty: Bool { speed == nil && line == nil && situation == nil }

    /// The option chosen for a part, by its raw value and label, and where it
    /// stands among that part's options.
    func option(for part: IntentionPart) -> (id: String, labelKey: String, rank: Int)? {
        switch part {
        case .speed: return speed.map { ($0.rawValue, $0.labelKey, PuttSpeed.allCases.firstIndex(of: $0) ?? 0) }
        case .line: return line.map { ($0.rawValue, $0.labelKey, PuttLine.allCases.firstIndex(of: $0) ?? 0) }
        case .situation: return situation.map { ($0.rawValue, $0.labelKey, PuttSituation.allCases.firstIndex(of: $0) ?? 0) }
        }
    }
}
