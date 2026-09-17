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
    @State private var cardHeight: CGFloat = 0
    /// What the card measures at each size, so the fitting one can be picked.
    @State private var cardHeights: [CGFloat: CGFloat] = [:]
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
    /// The card's own corner: a box's corner plus the margin, the same rule
    /// the opening follows around whatever it shows.
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
        let fieldRadius = step.target.flatMap { tutorial.radii[$0] } ?? Theme.Radius.lg
        let radius = min(fieldRadius + Self.margin, cutout.width / 2, cutout.height / 2)
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

            // As large as fits beside the opening, shrinking down to a size
            // still easy to read; where even that has no room, full size over
            // the opening.
            // The size is chosen here rather than by ViewThatFits: a card in
            // a box only as tall as the room beside the opening kept its Next
            // button outside that box, where a tap no longer reached it.
            card(step, fontSize: fittingSize(room: roomBeside(hole: hole, size: size)))
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    cardHeight = height
                }
                .padding(.horizontal, Self.margin)
                .frame(width: size.width)
                .offset(y: cardTop(hole: hole, preferBelow: cardBelow, size: size))
                .background {
                    // The same card at every size, measured but never shown,
                    // so the one on screen can be the largest that fits.
                    ZStack {
                        ForEach(Self.fontSizes, id: \.self) { size in
                            card(step, fontSize: size)
                                .fixedSize(horizontal: false, vertical: true)
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.size.height
                                } action: { height in
                                    cardHeights[size] = height
                                }
                        }
                    }
                    .hidden()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(Self.movement, value: cutout)
        .animation(Self.movement, value: cardHeight)
    }

    /// The sizes a card is tried at, largest first. Chinese, Japanese and
    /// Korean stop a step higher: their characters carry more strokes in the
    /// same space, and what is still readable in Latin type is not there.
    private static var fontSizes: [CGFloat] {
        switch LocalizationManager.shared.languageCode {
        case "zh-Hans", "ja", "ko": return [17, 16, 15, 14]
        default: return [17, 15, 14, 13]
        }
    }

    /// The largest size whose card fits beside the opening; where none does,
    /// the smallest, so a card lying over the field covers as little as it can.
    private func fittingSize(room: CGFloat) -> CGFloat {
        for size in Self.fontSizes where (cardHeights[size] ?? .infinity) <= room {
            return size
        }
        return Self.fontSizes[Self.fontSizes.count - 1]
    }

    /// The most height the card has on either side of the opening, or on
    /// the whole screen when there is no opening.
    private func roomBeside(hole: CGRect?, size: CGSize) -> CGFloat {
        let insets = Self.windowInsets
        let highest = insets.top + Self.margin
        let bottom = size.height - insets.bottom - Self.margin
        guard let hole else { return max(0, bottom - highest) }
        return max(0, bottom - hole.maxY - Self.margin, hole.minY - Self.margin - highest)
    }

    /// Where the card's top goes: beside the opening on the side with room,
    /// and when neither side has room — a tall opening on a small screen —
    /// over the opening's lower part, so the card and its Next button always
    /// stay inside the screen's safe area.
    private func cardTop(hole: CGRect?, preferBelow: Bool, size: CGSize) -> CGFloat {
        let insets = Self.windowInsets
        let highest = insets.top + Self.margin
        let lowest = max(highest, size.height - insets.bottom - Self.margin - cardHeight)
        guard let hole else { return min(max(highest, (size.height - cardHeight) / 2), lowest) }
        let below = hole.maxY + Self.margin
        let above = hole.minY - Self.margin - cardHeight
        let fitsBelow = below <= lowest
        let fitsAbove = above >= highest
        if preferBelow ? fitsBelow : !fitsAbove && fitsBelow { return below }
        if fitsAbove { return above }
        return lowest
    }

    private static var windowInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero
    }

    private func card(_ step: TutorialStep, fontSize: CGFloat) -> some View {
        VStack(spacing: 14) {
            let body = text(for: step)
            // A list reads down its left edge; a sentence sits in the middle.
            let isList = body.contains("\n•")
            Text(body)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(isList ? .leading : .center)
                .frame(maxWidth: .infinity, alignment: isList ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)

            if step == .missAngleDetail, !tutorial.resultChosen {
                Text(L("tutorial.missAngleDetail.hint"))
                    .font(.system(size: fontSize - 2, weight: .bold))
                    .foregroundStyle(Self.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if step == .courseName {
                Text(L("tutorial.courseName.hint"))
                    .font(.system(size: fontSize - 2, weight: .bold))
                    .foregroundStyle(Self.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if step == .finish {
                Text("Stay curious.")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Theme.primary)
            }

            if step == .units {
                // The question is the way in, so it is answered rather than skipped.
                HStack(spacing: 12) {
                    unitsButton(L("settings.metres"), imperial: false)
                    unitsButton(L("settings.feet"), imperial: true)
                }
            } else {
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
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: 520)
        .background(RoundedRectangle(cornerRadius: Self.holeRadius, style: .continuous).fill(Self.paper))
        .overlay(RoundedRectangle(cornerRadius: Self.holeRadius, style: .continuous).strokeBorder(Theme.primary, lineWidth: 3))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private func unitsButton(_ title: String, imperial: Bool) -> some View {
        Button {
            tutorial.chooseUnits(imperial: imperial)
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(Theme.primary))
        }
        .buttonStyle(.plain)
    }

    /// Next where nothing is asked; nothing where the step waits for the
    /// player to do something.
    private func buttonKey(for step: TutorialStep) -> String? {
        if step.waitsForAction { return nil }
        // The dial is the one field the tutorial insists on: without a result
        // there is nothing to record, so there is no way past it either.
        if step == .missAngleDetail, !tutorial.resultChosen { return nil }
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
        case .slope:
            // Only the escaped percent signs to resolve.
            return String(format: L(step.textKey))
        case .pace:
            // A slightly long step: about a metre, or about a yard.
            return L(unitsPref == "imperial" ? "tutorial.pace.imperial" : step.textKey)
        case .record:
            // The distance a tap-in is saved at: 30 cm, or exactly a foot.
            let tapIn = unitsPref == "imperial" ? "1 \(L("unit.ft"))" : "30 cm"
            return String(format: L(step.textKey), L("input.recordShort"), L("input.tapInShort"), tapIn)
        case .tryRest:
            // What a putt after a miss starts at: a metre, or two feet.
            let followUp = unitsPref == "imperial" ? "2 \(L("unit.ft"))" : "1 \(L("unit.m"))"
            return String(format: L(step.textKey), followUp)
        case .endRound:
            return String(format: L(step.textKey), L("input.end"))
        case .editLater:
            return String(format: L(step.textKey), L("summary.editHole"))
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
