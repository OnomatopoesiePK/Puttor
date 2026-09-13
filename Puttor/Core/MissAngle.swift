//
//  MissAngle.swift
//  Puttor
//
//  The angle a miss finished at, and how it maps onto everything that still
//  thinks in eight directions. Stored in "clock-face" degrees seen from the
//  player: 0 is straight short, negative runs to the left, positive to the
//  right, up to ±175 at long-left and long-right. The ring is split at the
//  top, so every miss is on one side of the hole or the other.
//

import Foundation

enum MissAngle {
    /// Either end of the track, on the step grid. Close enough to the top
    /// that a putt running long reaches it, far enough to leave a split.
    static let limit: Double = 175
    static let step: Double = 5

    /// Screen degrees (0 pointing right, turning clockwise) for an angle.
    static func screenDegrees(_ angle: Double) -> Double { 90 - angle }

    /// The track in screen degrees, drawn from its right end, around the
    /// bottom, to its left end.
    static let trackStartScreen = screenDegrees(limit)      // -85
    static let trackEndScreen = screenDegrees(-limit)       // 265

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

    /// Whether a screen direction falls in the split at the top.
    static func isInGap(screen: Double) -> Bool {
        abs(angle(fromScreen: screen)) > limit
    }

    /// The direction an angle belongs to, so the miss tendency, the patterns
    /// and the coach read an angle as they read a tap on the board. Anything
    /// below the sides of the hole is short and anything above them long, so
    /// 85° is still short; only exactly beside the hole is plain left or right.
    static func result(for angle: Double) -> PuttResult {
        let magnitude = abs(angle)
        let right = angle > 0
        switch magnitude {
        case ..<22.5: return .short
        case ..<90: return right ? .shortRight : .shortLeft
        case 90: return right ? .right : .left
        default: return right ? .longRight : .longLeft
        }
    }

    /// The angle as the dial reads it out: 0° straight short, 90° beside the
    /// hole, and back down towards 0° as a miss runs round to long.
    static func displayDegrees(_ angle: Double) -> Int {
        let magnitude = abs(angle)
        return Int((magnitude <= 90 ? magnitude : 180 - magnitude).rounded())
    }
}
