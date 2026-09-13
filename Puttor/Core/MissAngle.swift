//
//  MissAngle.swift
//  Puttor
//
//  The angle a miss finished at, and how it maps onto everything that still
//  thinks in eight directions. Stored in "clock-face" degrees seen from the
//  player: 0 is straight short, negative runs to the left, positive to the
//  right, up to ±150 at long-left and long-right. Past that is the gap at the
//  top, which is Long.
//

import Foundation

enum MissAngle {
    /// Either end of the track, on the step grid.
    static let limit: Double = 150
    static let step: Double = 5

    /// Screen degrees (0 pointing right, turning clockwise) for an angle.
    static func screenDegrees(_ angle: Double) -> Double { 90 - angle }

    /// The track in screen degrees, drawn from its right end, around the
    /// bottom, to its left end.
    static let trackStartScreen = screenDegrees(limit)      // -60
    static let trackEndScreen = screenDegrees(-limit)       // 240

    /// The angle a screen direction points at, in (-180, 180].
    static func angle(fromScreen screen: Double) -> Double {
        var value = (90 - screen).truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value <= -180 { value += 360 }
        return value
    }

    /// Onto the five-degree grid, and inside the track.
    static func snap(_ angle: Double) -> Double {
        min(limit, max(-limit, (angle / step).rounded() * step))
    }

    /// Whether a screen direction falls in the gap at the top.
    static func isInGap(screen: Double) -> Bool {
        abs(angle(fromScreen: screen)) > limit
    }

    /// The sector an angle belongs to, so the miss tendency, the patterns and
    /// the coach read an angle exactly as they read a tap on the board.
    static func result(for angle: Double) -> PuttResult {
        let magnitude = abs(angle)
        let right = angle > 0
        switch magnitude {
        case ..<22.5: return .short
        case ..<67.5: return right ? .shortRight : .shortLeft
        case ..<112.5: return right ? .right : .left
        default: return right ? .longRight : .longLeft
        }
    }
}
