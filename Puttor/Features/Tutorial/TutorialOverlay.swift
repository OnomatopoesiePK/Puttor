//
//  TutorialOverlay.swift
//  Puttor
//
//  The tutorial over a screen: everything washed out but an opening around
//  what the step is about — one that follows it as it moves and fits its
//  size — and a card saying what it is, with Next where nothing is asked and
//  a skip that asks first.
//

import SwiftUI

struct TutorialOverlay: View {
    let screen: TutorialScreen

    @State private var confirmingSkip = false
    @AppStorage(AppStorageKeys.units) private var unitsPref = "metric"
    private let tutorial = TutorialController.shared

    /// Light in either theme, the way the tutorial was drawn: a pale wash
    /// over the screen, a pale card with dark writing on it.
    private static let scrim = Color(white: 0.92).opacity(0.66)
    private static let paper = Color(white: 0.92)
    private static let ink = Color.black
    /// The app's own margin, used for every gap here: round what is shown,
    /// between the opening and the card, and between the card and the
    /// screen's sides. Something as wide as the screen opens to its edges.
    private static let margin = Theme.Spacing.edge
    /// A box's corner plus the margin, so the opening's corners run
    /// parallel to the corners of what it shows.
    private static let holeRadius = Theme.Radius.lg + margin
    private static let movement = Animation.smooth(duration: 0.45)

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let step = tutorial.visibleStep(on: screen)
            let hole = step.flatMap { opening(for: $0, origin: origin, size: geo.size) }
            // A step pointing at something waits until it is on screen.
            let showing = step.map { $0.target == nil || hole != nil } ?? false

            ZStack {
                if showing, let step {
                    layer(step, hole: hole, size: geo.size)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 0.3), value: showing)
        }
        .ignoresSafeArea()
        .alert(L("tutorial.skipTitle"), isPresented: $confirmingSkip) {
            Button(L("tutorial.skipConfirm"), role: .destructive) { tutorial.skip() }
            Button(L("tutorial.skipCancel"), role: .cancel) {}
        } message: {
            Text(L("tutorial.skipMessage"))
        }
    }

    private func opening(for step: TutorialStep, origin: CGPoint, size: CGSize) -> CGRect? {
        guard let target = step.target,
              let frame = tutorial.frames[target],
              frame.width > 1, frame.height > 1 else { return nil }
        return frame
            .offsetBy(dx: -origin.x, dy: -origin.y)
            .insetBy(dx: -Self.margin, dy: -Self.margin)
    }

    private func layer(_ step: TutorialStep, hole: CGRect?, size: CGSize) -> some View {
        // With nothing to point at, the opening closes to a point mid-screen.
        let cutout = hole ?? CGRect(x: size.width / 2, y: size.height / 2, width: 0, height: 0)
        let radius = min(Self.holeRadius, cutout.width / 2, cutout.height / 2)
        let cardBelow = hole.map { $0.midY < size.height / 2 } ?? true

        return ZStack(alignment: .topLeading) {
            TutorialScrim(hole: cutout, cornerRadius: radius)
                .fill(Self.scrim, style: FillStyle(eoFill: true))
                // Only the washed-out part takes touches; the opening passes
                // them on to what it shows.
                .contentShape(TutorialScrim(hole: cutout, cornerRadius: radius), eoFill: true)
                // Taps and drags on the wash go nowhere, so nothing under it
                // reacts or scrolls.
                .onTapGesture {}
                .gesture(DragGesture(minimumDistance: 0))

            if hole != nil {
                // Inside the opening, so none of it is cut off at the
                // screen's edge.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.primary, lineWidth: 3)
                    .frame(width: cutout.width, height: cutout.height)
                    .offset(x: cutout.minX, y: cutout.minY)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                if let hole, cardBelow {
                    Color.clear
                        .frame(height: hole.maxY + Self.margin)
                        .allowsHitTesting(false)
                } else {
                    Spacer(minLength: 60)
                }
                card(step)
                if let hole, !cardBelow {
                    Color.clear
                        .frame(height: max(0, size.height - hole.minY + Self.margin))
                        .allowsHitTesting(false)
                } else {
                    Spacer(minLength: 40)
                }
            }
            .padding(.horizontal, Self.margin)
            .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(Self.movement, value: cutout)
    }

    private func card(_ step: TutorialStep) -> some View {
        VStack(spacing: 14) {
            let body = text(for: step)
            // A list reads down its left edge; a sentence sits in the middle.
            let isList = body.contains("\n•")
            Text(body)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(isList ? .leading : .center)
                .frame(maxWidth: .infinity, alignment: isList ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)

            if step == .courseName {
                Text(L("tutorial.courseName.hint"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Self.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if step == .finish {
                Text("Stay curious.")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Theme.primary)
            }

            HStack(spacing: 12) {
                if step != .finish {
                    Button(L("tutorial.skip")) { confirmingSkip = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Self.ink.opacity(0.5))
                        .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                if let key = buttonKey(for: step) {
                    Button {
                        tutorial.next()
                    } label: {
                        Text(L(key))
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Theme.primary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: 520)
        .background(RoundedRectangle(cornerRadius: Self.holeRadius, style: .continuous).fill(Self.paper))
        .overlay(RoundedRectangle(cornerRadius: Self.holeRadius, style: .continuous).strokeBorder(Theme.primary, lineWidth: 3))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    /// Next where nothing is asked; nothing where the step waits for the
    /// player to do something.
    private func buttonKey(for step: TutorialStep) -> String? {
        if step.waitsForAction { return nil }
        switch step {
        case .tryRest: return "tutorial.gotIt"
        case .finish: return "tutorial.done"
        default: return "tutorial.next"
        }
    }

    /// The step's text, with the names of the buttons and modes it mentions
    /// taken from the app itself, so they always match what is on screen.
    private func text(for step: TutorialStep) -> String {
        switch step {
        case .courseName:
            return String(format: L(step.textKey), L("onCourse.tournamentTag"))
        case .format:
            return String(format: L(step.textKey), L("format.strokePlay"), L("format.matchPlay"))
        case .inputModes:
            return String(format: L(step.textKey), L("inputMode.pro"), L("inputMode.quick"), L("inputMode.custom"))
        case .startRound:
            return String(format: L(step.textKey), L("setup.startRound"))
        case .distance:
            return String(format: L(step.textKey), L("numpad.enter"))
        case .pace:
            // A slightly long step: about a metre, or three feet.
            let step = unitsPref == "imperial" ? "3 \(L("unit.ft"))" : "1 \(L("unit.m"))"
            return String(format: L(TutorialStep.pace.textKey), step)
        case .record:
            // The distance a tap-in is saved at: 30 cm, or exactly a foot.
            let tapIn = unitsPref == "imperial" ? "1 \(L("unit.ft"))" : "30 cm"
            return String(format: L(step.textKey), L("input.recordShort"), L("input.tapInShort"), tapIn)
        case .endRound:
            return String(format: L(step.textKey), L("input.end"))
        default:
            return L(step.textKey)
        }
    }
}

/// The wash with a rounded opening cut out of it, the opening sliding and
/// resizing smoothly between steps.
private struct TutorialScrim: Shape {
    var hole: CGRect
    var cornerRadius: CGFloat

    var animatableData: CGRect.AnimatableData {
        get { hole.animatableData }
        set { hole.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -2, dy: -2))
        path.addRoundedRect(
            in: hole,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        return path
    }
}
