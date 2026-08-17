//
//  PolarGeometry.swift
//  Puttor
//
//  Shared polar helpers for the ring-of-sectors drawings: the dartboard miss
//  picker during play, and the miss-frequency donut in the statistics.
//

import SwiftUI

enum PolarGeometry {
    /// The eight miss directions, laid out clockwise from the top of the ring.
    /// `startDeg` is the sector's leading edge in screen coordinates, where 0°
    /// points right and angles increase clockwise.
    static let missSectors: [(result: PuttResult, startDeg: Double)] = [
        (.long, -112.5),
        (.longRight, -67.5),
        (.right, -22.5),
        (.shortRight, 22.5),
        (.short, 67.5),
        (.shortLeft, 112.5),
        (.left, 157.5),
        (.longLeft, 202.5),
    ]

    static let sectorSpan: Double = 45

    static func point(_ deg: Double, _ radius: CGFloat, _ center: CGPoint) -> CGPoint {
        let rad = deg * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(cos(rad)), y: center.y + radius * CGFloat(sin(rad)))
    }

    /// A wedge of a ring: the arc from `startDeg` to `endDeg` between the inner
    /// radius `r1` and the outer radius `r2`.
    static func annularSector(startDeg: Double, endDeg: Double, r1: CGFloat, r2: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        let steps = 10
        path.move(to: point(startDeg, r2, center))
        for i in 1...steps {
            let d = startDeg + (endDeg - startDeg) * Double(i) / Double(steps)
            path.addLine(to: point(d, r2, center))
        }
        for i in 0...steps {
            let d = endDeg - (endDeg - startDeg) * Double(i) / Double(steps)
            path.addLine(to: point(d, r1, center))
        }
        path.closeSubpath()
        return path
    }

    /// Is `angle` within [start, start + span) modulo 360?
    static func angleInSector(_ angle: Double, start: Double, span: Double = sectorSpan) -> Bool {
        var diff = (angle - start).truncatingRemainder(dividingBy: 360)
        if diff < 0 { diff += 360 }
        return diff < span
    }
}
