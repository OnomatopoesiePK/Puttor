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

        /// Straight, for the back of the hand and the wrist behind it.
        func bone(_ from: CGPoint, _ to: CGPoint, _ width: CGFloat) -> Path {
            var stroke = Path()
            stroke.move(to: from)
            stroke.addLine(to: to)
            return stroke.strokedPath(StrokeStyle(lineWidth: width * scale, lineCap: .round))
        }

        // Seen from the side: the wrist comes in from the upper right and the
        // hand reaches down, which is what picking something up looks like —
        // a hand facing the reader is a hand waving.
        result.addPath(bone(point(82, 27), point(44, 39), 16))

        // Four fingers hanging with a hand's own stagger — short, long, long,
        // short — and a thumb closing from behind.
        let fingers: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (37, 43, 29, 55, 30, 67, 6),
            (45, 46, 38, 59, 39, 73, 6),
            (53, 49, 47, 61, 48, 73, 6),
            (61, 52, 56, 61, 57, 67, 5.5),
            (70, 42, 76, 53, 68, 60, 7),
        ]
        for (x1, y1, cx, cy, x2, y2, width) in fingers {
            result.addPath(limb(point(x1, y1), point(cx, cy), point(x2, y2), width))
        }

        // The ball, under the fingertips.
        result.addEllipse(in: CGRect(
            x: originX + 29.5 * scale,
            y: originY + 74.5 * scale,
            width: 19 * scale,
            height: 19 * scale
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
