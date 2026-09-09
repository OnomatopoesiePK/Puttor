//
//  PickUpBallIcon.swift
//  Puttor
//
//  A hand reaching down for the ball, seen from the side: the thumb up and
//  away, the index finger and the one beside it down over the ball, and a
//  single finger behind them on the far side. Drawn rather than borrowed —
//  every hand in SF Symbols is raised, waving, pointing or tapping, and none
//  of them is picking anything up.
//
//  Laid out in a 100×100 square and scaled to whatever it is given, so the
//  same drawing serves a 16 pt corner button and a 40 pt tile.
//

import SwiftUI

struct PickUpBallIcon: Shape {
    /// The hand's outline, as vertices of the palm and the four limbs that
    /// leave it. Every limb tapers, because a finger does.
    private static let palm: [CGPoint] = [
        CGPoint(x: 56, y: 41), CGPoint(x: 62, y: 27), CGPoint(x: 74, y: 21),
        CGPoint(x: 83, y: 33), CGPoint(x: 76, y: 49), CGPoint(x: 63, y: 53),
    ]
    private static let palmCorner: CGFloat = 3

    /// from, its half-width, to, its half-width.
    private static let limbs: [(CGPoint, CGFloat, CGPoint, CGFloat)] = [
        (CGPoint(x: 62, y: 28), 6, CGPoint(x: 24, y: 12), 2.5),    // thumb
        (CGPoint(x: 64, y: 51), 6, CGPoint(x: 34, y: 73), 4.2),    // index
        (CGPoint(x: 57, y: 41), 5.2, CGPoint(x: 14, y: 57), 3.8),  // the finger beside it
        (CGPoint(x: 78, y: 47), 5.5, CGPoint(x: 80, y: 68), 4.5),  // one finger behind
    ]
    private static let ball = (center: CGPoint(x: 57, y: 79), radius: CGFloat(12))

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let scale = side / 100
        let originX = rect.minX + (rect.width - side) / 2
        let originY = rect.minY + (rect.height - side) / 2

        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: originX + point.x * scale, y: originY + point.y * scale)
        }

        var result = Path()

        // The palm: the flat shape, with a rounded band run around its edge so
        // the corners are not points.
        result.move(to: place(Self.palm[0]))
        for vertex in Self.palm.dropFirst() { result.addLine(to: place(vertex)) }
        result.closeSubpath()
        for (vertex, next) in zip(Self.palm, Array(Self.palm.dropFirst()) + [Self.palm[0]]) {
            result.addPath(Self.taper(
                place(vertex), Self.palmCorner * scale,
                place(next), Self.palmCorner * scale
            ))
        }

        for (from, fromWidth, to, toWidth) in Self.limbs {
            result.addPath(Self.taper(place(from), fromWidth * scale, place(to), toWidth * scale))
        }

        result.addEllipse(in: CGRect(
            x: place(Self.ball.center).x - Self.ball.radius * scale,
            y: place(Self.ball.center).y - Self.ball.radius * scale,
            width: Self.ball.radius * 2 * scale,
            height: Self.ball.radius * 2 * scale
        ))

        return result
    }

    /// The shape wrapped around two circles — a stroke that changes width from
    /// one end to the other. Traced as one closed outline rather than a stroke
    /// plus caps, so every piece of the drawing winds the same way and the
    /// whole hand fills as one silhouette.
    private static func taper(_ from: CGPoint, _ fromRadius: CGFloat, _ to: CGPoint, _ toRadius: CGFloat) -> Path {
        let dx = to.x - from.x, dy = to.y - from.y
        let distance = (dx * dx + dy * dy).squareRoot()
        var path = Path()
        guard distance > 0.0001 else {
            path.addEllipse(in: CGRect(
                x: from.x - fromRadius, y: from.y - fromRadius,
                width: fromRadius * 2, height: fromRadius * 2
            ))
            return path
        }

        let alpha = atan2(dy, dx)
        // Where the outer tangents touch: the angle between the centre line
        // and the line that grazes both circles.
        let beta = acos(min(1, max(-1, (fromRadius - toRadius) / distance)))
        let steps = 16

        func arc(_ center: CGPoint, _ radius: CGFloat, _ start: CGFloat, _ end: CGFloat, first: Bool) {
            for step in 0...steps {
                let angle = start + (end - start) * CGFloat(step) / CGFloat(steps)
                let point = CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
                if first && step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }

        // The long way around the near end, then across the far one.
        arc(from, fromRadius, alpha + beta, alpha + 2 * .pi - beta, first: true)
        arc(to, toRadius, alpha - beta, alpha + beta, first: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 20) {
        ForEach([16, 22, 44, 96], id: \.self) { size in
            PickUpBallIcon()
                .fill(Theme.accent)
                .frame(width: CGFloat(size), height: CGFloat(size))
        }
    }
    .padding()
}
