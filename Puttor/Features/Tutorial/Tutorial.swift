//
//  Tutorial.swift
//  Puttor
//
//  The walk through the first round: the steps, what each one points at, and
//  where those things are on screen. The steps on the round settings play
//  over that cover; the rest over the whole app, tab bar included, so each of
//  the two has its own overlay reading this one controller.
//

import SwiftUI

/// Something a step points at.
enum TutorialTarget: Hashable {
    case courseName, putter, greenSpeed, weather, format, inputModes, startRound
    case distance, puttFor, slope, missAngle, missReasons, recordBar
    case pickUp, holeButton, navArrows, puttChips, endButton
}

enum TutorialScreen {
    case setup, input
}

enum TutorialStep: Int, CaseIterable {
    case welcome, courseName, putter, greenSpeed, weather, format, inputModes, startRound
    case distance, pace, puttFor, slope, missAngle, missReasons, record, tryRest
    case pickUp, holePicker, navArrows, puttChips, endRound, settings, finish

    var screen: TutorialScreen {
        rawValue <= TutorialStep.startRound.rawValue ? .setup : .input
    }

    var target: TutorialTarget? {
        switch self {
        case .welcome, .tryRest, .settings, .finish: return nil
        case .courseName: return .courseName
        case .putter: return .putter
        case .greenSpeed: return .greenSpeed
        case .weather: return .weather
        case .format: return .format
        case .inputModes: return .inputModes
        case .startRound: return .startRound
        case .distance, .pace: return .distance
        case .puttFor: return .puttFor
        case .slope: return .slope
        case .missAngle: return .missAngle
        case .missReasons: return .missReasons
        case .record: return .recordBar
        case .pickUp: return .pickUp
        case .holePicker: return .holeButton
        case .navArrows: return .navArrows
        case .puttChips: return .puttChips
        case .endRound: return .endButton
        }
    }

    /// Moved on by doing what it asks — naming the course, starting the
    /// round, recording the putt — rather than by Next.
    var waitsForAction: Bool {
        self == .courseName || self == .startRound || self == .record
    }

    var textKey: String { "tutorial.\(self)" }
}

@Observable
final class TutorialController {
    static let shared = TutorialController()

    private(set) var step: TutorialStep?
    /// The try-it-yourself card has been put away: nothing shows until the
    /// hole is finished.
    private(set) var practising = false
    /// Where each target is, in window coordinates.
    var frames: [TutorialTarget: CGRect] = [:]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Finished or skipped; either way it does not start again on its own.
    var isFinished: Bool { defaults.bool(forKey: AppStorageKeys.tutorialFinished) }

    /// The step the overlay of this screen shows, if any.
    func visibleStep(on screen: TutorialScreen) -> TutorialStep? {
        guard let step, step.screen == screen, !practising else { return nil }
        return step
    }

    /// With a new round, unless it was finished or skipped before.
    func startIfNeeded() {
        guard step == nil, !isFinished else { return }
        practising = false
        step = .welcome
    }

    func next() {
        guard let step else { return }
        if step == .tryRest {
            practising = true
        } else {
            move(on: step)
        }
    }

    /// The player did what the step asked.
    func advance(from expected: TutorialStep) {
        guard step == expected else { return }
        move(on: expected)
    }

    /// What recording a putt did. A miss leaves the rest of the hole to the
    /// player; a finished hole goes on to what is left to show.
    func recorded(_ outcome: RoundOutcome) {
        guard step == .record || step == .tryRest else { return }
        switch outcome {
        case .missed:
            if step == .record { step = .tryRest }
        case .advancedToNextHole, .reachedSequenceEnd:
            practising = false
            step = .pickUp
        case .edited:
            break
        }
    }

    func skip() {
        end()
    }

    /// Starts again with the next round.
    func replay() {
        defaults.removeObject(forKey: AppStorageKeys.tutorialFinished)
    }

    private func move(on step: TutorialStep) {
        var following = TutorialStep(rawValue: step.rawValue + 1)
        // Only a missed putt leads into trying the rest.
        if following == .tryRest { following = .pickUp }
        guard let following else {
            end()
            return
        }
        self.step = following
    }

    private func end() {
        step = nil
        practising = false
        defaults.set(true, forKey: AppStorageKeys.tutorialFinished)
    }
}

extension View {
    /// Something a tutorial step can point at: the tutorial is told where it
    /// is whenever it moves, and can scroll to it by its id.
    func tutorialTarget(_ target: TutorialTarget) -> some View {
        id(target)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                TutorialController.shared.frames[target] = frame
            }
    }

    /// Scrolls whatever the tutorial points at into view.
    func tutorialScrolling(_ proxy: ScrollViewProxy) -> some View {
        modifier(TutorialScrolling(proxy: proxy))
    }
}

private struct TutorialScrolling: ViewModifier {
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        let tutorial = TutorialController.shared
        content
            // While a step shows, the screen stays where the tutorial put it.
            .scrollDisabled(tutorial.step != nil && !tutorial.practising)
            .onChange(of: tutorial.step, initial: true) { _, step in
            guard let target = step?.target else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                proxy.scrollTo(target, anchor: UnitPoint(x: 0.5, y: 0.1))
            }
        }
    }
}
