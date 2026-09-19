//
//  CourseScorecard.swift
//  Puttor
//
//  A course's pars, remembered from the rounds played on it. Nothing is
//  stored apart: whenever a round on a course has the par of a hole, that is
//  the course's par for the hole, the latest round winning. A new round on
//  the course starts with them filled in, so putt 0 only asks what the card
//  cannot know.
//

import Foundation

struct CourseScorecard: Identifiable, Equatable {
    /// The name as it was last written.
    let name: String
    /// Par by hole, where any round on the course gave it.
    let pars: [Int: Int]
    let lastPlayed: Date

    var id: String { Self.key(name) }
    var totalPar: Int { pars.values.reduce(0, +) }
    var hasScorecard: Bool { !pars.isEmpty }

    /// Names are matched without regard to case or surrounding spaces.
    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Every named course, most recently played first.
    static func courses(in rounds: [Round]) -> [CourseScorecard] {
        var byKey: [String: [Round]] = [:]
        for round in rounds {
            let key = key(round.courseName)
            guard !key.isEmpty else { continue }
            byKey[key, default: []].append(round)
        }
        return byKey.values.compactMap { played in
            let oldestFirst = played.sorted { $0.date < $1.date }
            guard let latest = oldestFirst.last else { return nil }
            var pars: [Int: Int] = [:]
            for round in oldestFirst {
                for (hole, details) in round.holeDetails {
                    if let par = details.par { pars[hole] = par }
                }
            }
            return CourseScorecard(
                name: latest.courseName.trimmingCharacters(in: .whitespacesAndNewlines),
                pars: pars,
                lastPlayed: latest.date
            )
        }
        .sorted { $0.lastPlayed > $1.lastPlayed }
    }

    /// The course of that name, if it was played before.
    static func course(named name: String, in rounds: [Round]) -> CourseScorecard? {
        let key = key(name)
        guard !key.isEmpty else { return nil }
        return courses(in: rounds).first { $0.id == key }
    }

    /// Courses to offer while a name is typed: those it matches, the ones
    /// starting with it first, and not the one already written out in full.
    static func suggestions(for text: String, in courses: [CourseScorecard]) -> [CourseScorecard] {
        let typed = key(text)
        guard !typed.isEmpty else { return Array(courses.prefix(5)) }
        let matching = courses.filter { $0.id.contains(typed) && $0.id != typed }
        let leading = matching.filter { $0.id.hasPrefix(typed) }
        let rest = matching.filter { !$0.id.hasPrefix(typed) }
        return Array((leading + rest).prefix(5))
    }

    /// The pars as a round's hole details, marked as taken from the card.
    var holeDetails: [Int: HoleDetails] {
        pars.mapValues { HoleDetails(par: $0, parFromScorecard: true) }
    }
}
