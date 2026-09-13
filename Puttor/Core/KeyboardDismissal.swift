//
//  KeyboardDismissal.swift
//  Puttor
//
//  A tap anywhere outside a text field puts the keyboard away. A number pad
//  has no return key, so without this the pad under a distance field stayed
//  up until the screen was left. The tap is only watched, never taken: the
//  button or row underneath still gets it.
//

import UIKit

@MainActor
final class KeyboardDismissal: NSObject, UIGestureRecognizerDelegate {
    private static let shared = KeyboardDismissal()

    /// Adds the watcher to every window of the app, once each.
    static func install() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows where !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === shared }) {
            let tap = UITapGestureRecognizer(target: shared, action: #selector(dismiss(_:)))
            tap.cancelsTouchesInView = false
            tap.delegate = shared
            window.addGestureRecognizer(tap)
        }
    }

    @objc private func dismiss(_ tap: UITapGestureRecognizer) {
        tap.view?.endEditing(true)
    }

    /// A tap into a text field is the start of typing, not the end of it.
    nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        MainActor.assumeIsolated {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
    }

    /// Alongside every other gesture, so nothing underneath loses its tap.
    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
