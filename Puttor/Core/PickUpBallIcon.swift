//
//  PickUpBallIcon.swift
//  Puttor
//
//  A hand reaching down for the ball. Drawn rather than borrowed: every hand
//  in SF Symbols is raised, waving, pointing or tapping, and none of them is
//  picking anything up — which is the one thing this button means.
//
//  Laid out in a 100×100 square and scaled to whatever it is given, so the
//  same drawing serves a 14 pt corner button and a 40 pt tile.
//

import SwiftUI

struct PickUpBallIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let scale = side / 100
        let originX = rect.minX + (rect.width - side) / 2
        let originY = rect.minY + (rect.height - side) / 2

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + x * scale, y: originY + y * scale)
        }

        /// One bone of the hand: a curve given thickness, which draws far more
        /// cleanly at small sizes than an outline traced by hand.
        func limb(_ from: CGPoint, _ control: CGPoint, _ to: CGPoint, _ width: CGFloat) -> Path {
            var stroke = Path()
            stroke.move(to: from)
            stroke.addQuadCurve(to: to, control: control)
            return stroke.strokedPath(StrokeStyle(lineWidth: width * scale, lineCap: .round))
        }

        var result = Path()

        // The back of the hand, arched over the ball.
        result.addPath(limb(point(21, 45), point(49, 12), point(75, 42), 11))

        // Three fingers curling down, and a thumb on the far side.
        let fingers: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (25, 35, 19, 50, 22, 61, 6),
            (38, 21, 31, 48, 34, 62, 6),
            (53, 22, 48, 48, 49, 62, 6),
            (73, 44, 79, 52, 75, 60, 6.5),
        ]
        for (x1, y1, cx, cy, x2, y2, width) in fingers {
            result.addPath(limb(point(x1, y1), point(cx, cy), point(x2, y2), width))
        }

        // The ball, just under the fingertips.
        result.addEllipse(in: CGRect(
            x: originX + 35 * scale,
            y: originY + 69 * scale,
            width: 20 * scale,
            height: 20 * scale
        ))

        return result
    }
}

#Preview {
    HStack(spacing: 20) {
        ForEach([14, 20, 40, 80], id: \.self) { size in
            PickUpBallIcon()
                .fill(Theme.accent)
                .frame(width: CGFloat(size), height: CGFloat(size))
        }
    }
    .padding()
}
