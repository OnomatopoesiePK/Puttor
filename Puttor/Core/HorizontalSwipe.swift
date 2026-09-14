//
//  HorizontalSwipe.swift
//  Puttor
//
//  A sideways swipe that leaves vertical scrolling alone. SwiftUI's drag
//  gesture inside a scroll view claims the touch before it knows which way the
//  finger is going, so the page under it stopped scrolling. This recogniser
//  only begins once the finger is clearly moving sideways in its direction,
//  and shares every touch with the scroll view.
//

import SwiftUI
import UIKit

/// One recogniser for either way: two on the same view kept the second from
/// ever being asked.
struct HorizontalSwipe: UIGestureRecognizerRepresentable {
    enum Direction { case left, right }

    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?

    init(onLeft: (() -> Void)? = nil, onRight: (() -> Void)? = nil) {
        self.onLeft = onLeft
        self.onRight = onRight
    }

    init(direction: Direction, isEnabled: Bool = true, action: @escaping () -> Void) {
        let handler: (() -> Void)? = isEnabled ? action : nil
        self.init(onLeft: direction == .left ? handler : nil, onRight: direction == .right ? handler : nil)
    }

    /// How far the finger travels sideways before the swipe counts: as soon as
    /// that, not once the finger lifts.
    static let distance: CGFloat = 30

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recogniser = UIPanGestureRecognizer()
        recogniser.delegate = context.coordinator
        return recogniser
    }

    func updateUIGestureRecognizer(_ recogniser: UIPanGestureRecognizer, context: Context) {
        context.coordinator.allowsLeft = onLeft != nil
        context.coordinator.allowsRight = onRight != nil
        recogniser.isEnabled = onLeft != nil || onRight != nil
    }

    func handleUIGestureRecognizerAction(_ recogniser: UIPanGestureRecognizer, context: Context) {
        switch recogniser.state {
        case .began:
            context.coordinator.fired = false
        case .changed:
            guard !context.coordinator.fired else { return }
            let moved = recogniser.translation(in: recogniser.view).x
            if moved < -Self.distance, let onLeft {
                context.coordinator.fired = true
                onLeft()
            } else if moved > Self.distance, let onRight {
                context.coordinator.fired = true
                onRight()
            }
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var allowsLeft = false
        var allowsRight = false
        /// Once per swipe, however far the finger goes on.
        var fired = false

        /// Only a swipe that sets off sideways, a way there is something for:
        /// anything more up or down than across is the scroll view's.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            guard abs(velocity.x) > abs(velocity.y) * 1.5 else { return false }
            return velocity.x < 0 ? allowsLeft : allowsRight
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
