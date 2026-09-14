//
//  MissSideTally.swift
//  Puttor
//
//  Which way a drill's misses went, and whether one side keeps coming up —
//  read after a single drill and over every drill that asks.
//

import Foundation

struct MissSideTally: Equatable {
    let left: Int
    let right: Int

    /// Below this many misses a lean is chance.
    static let minimumMisses = 8
    /// The share of the misses one side needs before it is named.
    static let leanPercent = 65

    init(left: Int, right: Int) {
        self.left = left
        self.right = right
    }

    /// Every finished session of a drill that asks which way it missed.
    init(sessions: [GameSession]) {
        let asked = sessions.filter { $0.isComplete && $0.gameType.recordsMissSide }
        self.init(
            left: asked.reduce(0) { $0 + $1.missedLeft },
            right: asked.reduce(0) { $0 + $1.missedRight }
        )
    }

    var misses: Int { left + right }

    /// -1 when the misses keep going left, +1 right, nil while neither side
    /// stands out.
    var leaning: Int? {
        guard misses >= Self.minimumMisses, left != right,
              max(left, right) * 100 >= Self.leanPercent * misses
        else { return nil }
        return left > right ? -1 : 1
    }
}
