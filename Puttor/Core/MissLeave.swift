//
//  MissLeave.swift
//  Puttor
//
//  What a miss left behind, read from the putt that followed it on the same
//  hole. It decides what "long" means: a ball that slid past and stopped
//  within a metre had the pace a putt is meant to have — it had its chance to
//  drop and the one back is a tap-in. Only a ball that ran on further is a
//  putt that was hit too hard.
//

import Foundation

struct MissLeave {
    /// Past the hole but no further than this is the right pace, not a miss
    /// long.
    static let settledLongM = 1.0

    private struct HoleKey: Hashable {
        let round: ObjectIdentifier?
        let hole: Int
    }

    private let leaves: [ObjectIdentifier: Double]

    init(_ putts: [Putt]) {
        var byHole: [HoleKey: [Putt]] = [:]
        for putt in putts where putt.puttNumber > 0 {
            let key = HoleKey(round: putt.round.map { ObjectIdentifier($0) }, hole: putt.holeNumber)
            byHole[key, default: []].append(putt)
        }

        var leaves: [ObjectIdentifier: Double] = [:]
        for hole in byHole.values {
            let sorted = hole.sorted { $0.puttNumber < $1.puttNumber }
            for (putt, next) in zip(sorted, sorted.dropFirst()) where next.puttNumber > putt.puttNumber {
                leaves[ObjectIdentifier(putt)] = next.distanceM
            }
        }
        self.leaves = leaves
    }

    /// The next putt's distance, or nil where none was recorded.
    func leave(after putt: Putt) -> Double? {
        leaves[ObjectIdentifier(putt)]
    }

    /// -1 short of the hole, +1 run well past it, 0 for everything else —
    /// including a putt that stopped within a metre past. A long miss with no
    /// putt after it keeps its length, since nothing says how far it ran.
    func lengthBias(_ putt: Putt) -> Int {
        let bias = putt.result.lengthBias
        guard bias > 0, let leave = leave(after: putt) else { return bias }
        return leave > Self.settledLongM ? bias : 0
    }
}
