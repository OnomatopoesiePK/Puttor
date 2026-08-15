//
//  GameAttempt.swift
//  Puttor
//
//  A single logged attempt within a GameSession. groupIndex distinguishes
//  laps/cycles/ladder-tries; index is the order within that group.
//

import Foundation
import SwiftData

@Model
final class GameAttempt {
    var id: UUID = UUID()
    var session: GameSession?
    var groupIndex: Int = 0
    var index: Int = 0
    var label: String = ""
    var distanceM: Double = 0
    var breakPct: Double = 0
    var success: Bool = false
    /// Strokes taken on this "hole" — only meaningful for Around the World.
    var strokes: Int = 0
    var createdAt: Date = Date()

    init(
        groupIndex: Int,
        index: Int,
        label: String,
        distanceM: Double = 0,
        breakPct: Double = 0,
        success: Bool = false,
        strokes: Int = 0
    ) {
        self.id = UUID()
        self.groupIndex = groupIndex
        self.index = index
        self.label = label
        self.distanceM = distanceM
        self.breakPct = breakPct
        self.success = success
        self.strokes = strokes
        self.createdAt = Date()
    }
}
