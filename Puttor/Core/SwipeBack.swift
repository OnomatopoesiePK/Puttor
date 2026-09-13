//
//  SwipeBack.swift
//  Puttor
//
//  A screen that draws its own back button loses the swipe back iOS gives
//  every other pushed screen. `.swipeBack()` hands it back for as long as the
//  screen is on top, and lets the screen refuse it for a moment, as when there
//  are unsaved changes to ask about first.
//

import SwiftUI
import UIKit

extension View {
    /// The swipe back of a screen with the system back button. While `allowed`
    /// is false a swipe from the edge goes nowhere and calls `onRefused`.
    func swipeBack(allowed: Bool = true, onRefused: (() -> Void)? = nil) -> some View {
        background(SwipeBackInstaller(allowed: allowed, onRefused: onRefused).frame(width: 0, height: 0))
    }
}

private struct SwipeBackInstaller: UIViewControllerRepresentable {
    let allowed: Bool
    let onRefused: (() -> Void)?

    func makeUIViewController(context: Context) -> SwipeBackController {
        SwipeBackController()
    }

    func updateUIViewController(_ controller: SwipeBackController, context: Context) {
        controller.allowed = allowed
        controller.onRefused = onRefused
    }
}

/// Stands in as the navigation controller's swipe-back delegate while its
/// screen is showing, and gives the old delegate back as soon as the screen
/// starts to leave — so the screens pushed over it, or left under it, keep
/// whatever they had.
private final class SwipeBackController: UIViewController, UIGestureRecognizerDelegate {
    var allowed = true
    var onRefused: (() -> Void)?

    /// The recognisers taken over, each with the delegate it had.
    private var taken: [(recogniser: UIGestureRecognizer, delegate: UIGestureRecognizerDelegate?)] = []

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard taken.isEmpty, let navigation = navigationController else { return }
        // The swipe from the edge, and the one from anywhere on the page.
        let recognisers = [navigation.interactivePopGestureRecognizer, navigation.interactiveContentPopGestureRecognizer]
        for case let recogniser? in recognisers {
            taken.append((recogniser, recogniser.delegate))
            recogniser.delegate = self
            recogniser.isEnabled = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for entry in taken where entry.recogniser.delegate === self {
            entry.recogniser.delegate = entry.delegate
        }
        taken.removeAll()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation = navigationController, navigation.viewControllers.count > 1 else { return false }
        guard allowed else {
            // Only the edge swipe asks: the page-wide one also comes up
            // while the page is merely being dragged about.
            if gestureRecognizer === navigation.interactivePopGestureRecognizer { onRefused?() }
            return false
        }
        return true
    }
}
