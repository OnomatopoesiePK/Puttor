//
//  HoleDetails.swift
//  Puttor
//
//  What is said about a hole before its first putt, in Custom mode's putt 0:
//  its par, and whether the approach was a real chance at the green in
//  regulation. Kept on the round rather than on a putt, since both belong to
//  the hole and are answered before any putt exists.
//

import Foundation

struct HoleDetails: Codable, Equatable {
    /// 3, 4 or 5.
    var par: Int?
    /// A clear shot at the green in regulation, within reach.
    var girOpportunity: Bool?

    var isEmpty: Bool { par == nil && girOpportunity == nil }

    static let pars = [3, 4, 5]
}
