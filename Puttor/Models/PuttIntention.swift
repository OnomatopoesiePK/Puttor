//
//  PuttIntention.swift
//  Puttor
//
//  What a putt was meant to do, and whether it came off. An intention has up
//  to four parts — what the putt is for, its pace, its line, and in match
//  play what the situation asks — and each can be switched off in Settings.
//  Whether it came off is the process side: a putt played as meant that does
//  not drop is no mistake.
//

import Foundation

/// A part of an intention the intention field asks for.
enum IntentionPart: String, Codable, CaseIterable, Identifiable {
    case goal, speed, line, situation

    var id: String { rawValue }
    var titleKey: String { "intention.part.\(rawValue)" }
    /// For a four-way picker, where the full title does not fit.
    var shortTitleKey: String { "intention.part.\(rawValue).short" }

    var icon: String {
        switch self {
        case .goal: return "flag.fill"
        case .speed: return "speedometer"
        case .line: return "scope"
        case .situation: return "person.2.fill"
        }
    }
}

/// What the putt is for.
enum PuttGoal: String, Codable, CaseIterable, Identifiable {
    /// In the hole: line and pace chosen for holing, the leave comes second.
    case make
    /// A safe two-putt: pace over line, into a circle of about a metre.
    case lag
    /// Staying below the hole on purpose, so the next putt is uphill.
    case position
    /// Only knocking it in.
    case tapIn

    var id: String { rawValue }
    var labelKey: String { "intention.goal.\(rawValue)" }
}

/// How hard the putt is meant to be struck.
enum PuttSpeed: String, Codable, CaseIterable, Identifiable {
    /// Dying at the hole: all of its width, but more break and less forgiving
    /// of a misjudged pace.
    case dieIn
    /// Dave Pelz's pace: enough to finish about 30 cm — a foot — past the hole.
    case pelz
    /// Firm: less break and less of the hole, but past the bumps round the
    /// edge — at the cost of a longer one back.
    case firm

    var id: String { rawValue }
    var labelKey: String { "intention.speed.\(rawValue)" }

    static let pelzPastM = 0.3
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
    var goal: PuttGoal?
    var speed: PuttSpeed?
    var line: PuttLine?
    var situation: PuttSituation?
    /// Whether the putt was played as meant; nil when not said.
    var executed: Bool?

    var isEmpty: Bool { goal == nil && speed == nil && line == nil && situation == nil }

    /// The option chosen for a part, by its raw value and label, and where it
    /// stands among that part's options.
    func option(for part: IntentionPart) -> (id: String, labelKey: String, rank: Int)? {
        switch part {
        case .goal: return goal.map { ($0.rawValue, $0.labelKey, PuttGoal.allCases.firstIndex(of: $0) ?? 0) }
        case .speed: return speed.map { ($0.rawValue, $0.labelKey, PuttSpeed.allCases.firstIndex(of: $0) ?? 0) }
        case .line: return line.map { ($0.rawValue, $0.labelKey, PuttLine.allCases.firstIndex(of: $0) ?? 0) }
        case .situation: return situation.map { ($0.rawValue, $0.labelKey, PuttSituation.allCases.firstIndex(of: $0) ?? 0) }
        }
    }
}
