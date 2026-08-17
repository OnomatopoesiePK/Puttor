//
//  RoundInputCustomView.swift
//  Puttor
//
//  Custom mode: distance and result are always present, everything else is
//  whatever optional fields the user configured (in order) in Settings.
//  Reuses RoundSession unchanged — only the fields shown differ from Pro.
//

import SwiftUI
import SwiftData

struct RoundInputCustomView: View {
    @Bindable var round: Round
    var initialHole: Int? = nil
    var isPostRoundEdit: Bool = false
    var onDone: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"

    @State private var session: RoundSession?
    @State private var config: CustomModeConfig = CustomModeConfig.load()
    @State private var showSequenceEndAlert = false
    @State private var showEndRoundAlert = false
    @State private var showNineOrEighteenAlert = false
    @State private var navigateToSummary = false
    @State private var showHolePicker = false
    @State private var showSavedFlash = false
    @State private var flashSG: Double = 0
    @State private var showDeleteHoleConfirm = false

    private var useFeet: Bool { unitsPref == "imperial" }

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                Color.clear.onAppear {
                    session = RoundSession(round: round, modelContext: modelContext, initialHole: initialHole, isPostRoundEdit: isPostRoundEdit)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToSummary) {
            RoundSummaryView(round: round, onDone: onDone)
        }
    }

    @ViewBuilder
    private func content(_ session: RoundSession) -> some View {
        VStack(spacing: 0) {
            topBar(session)

            if showSavedFlash {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L("input.saved"))
                    Text("\(flashSG >= 0 ? "+" : "")\(String(format: "%.2f", flashSG)) SG")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(flashSG > 0 ? Theme.primary : Theme.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background((flashSG > 0 ? Theme.primary : Theme.error).opacity(0.15))
                .transition(.opacity)
            } else if session.hasUnsavedEdits {
                Text(L("input.editing"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.accent.opacity(0.13))
            }

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    section {
                        let distance = Binding(get: { session.draftDistanceM }, set: { session.draftDistanceM = $0 })
                        if config.distanceStyle == .numpad {
                            DistanceNumpadView(value: distance, useFeet: useFeet)
                        } else {
                            DistancePickerView(value: distance, useFeet: useFeet)
                        }
                    }

                    ForEach(config.fields) { field in
                        section {
                            fieldContent(field, session)
                        }
                    }

                    section {
                        resultContent(session)
                    }
                }
                .padding(Theme.Spacing.md)
            }

            bottomBar(session)
        }
        .alert(L("input.holeCompleteTitle"), isPresented: $showSequenceEndAlert) {
            Button(L("input.endRound")) { session.endRound(holeCount: session.playedHoleCount <= 9 ? 9 : 18); navigateToSummary = true }
            Button(L("input.continueFromStart")) {}
        } message: {
            Text(L("input.holeCompleteMessage"))
        }
        .alert(L("input.endRoundTitle"), isPresented: $showEndRoundAlert) {
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("input.endRound"), role: .destructive) {
                if session.playedHoleCount <= 9 {
                    showNineOrEighteenAlert = true
                } else {
                    session.endRound(holeCount: 18)
                    navigateToSummary = true
                }
            }
        } message: {
            Text(String(format: L("input.endRoundMessage"), session.totalRealPutts, session.playedHoleCount))
        }
        .alert(L("input.save9Or18Title"), isPresented: $showNineOrEighteenAlert) {
            Button(L("input.save9")) { session.endRound(holeCount: 9); navigateToSummary = true }
            Button(L("input.save18")) { session.endRound(holeCount: 18); navigateToSummary = true }
        } message: {
            Text(L("input.save9Or18Message"))
        }
        .sheet(isPresented: $showHolePicker) {
            HolePickerSheet(holes: session.holeSequence, current: session.displayHole) { hole in
                session.jumpToHole(hole)
            }
        }
    }

    @ViewBuilder
    private func fieldContent(_ field: CustomField, _ session: RoundSession) -> some View {
        switch field.kind {
        case .puttForCategory:
            scoreCategoryRow(session)
        case .slope:
            if field.complexity == .complex {
                SlopeGridPickerView(
                    sideValue: Binding(get: { session.draftSideSlopePct }, set: { session.draftSideSlopePct = $0 }),
                    hillValue: Binding(get: { session.draftHillSlopePct }, set: { session.draftHillSlopePct = $0 })
                )
            } else {
                SimpleSlopeGridView(
                    sideValue: Binding(get: { session.draftSideSlopePct }, set: { session.draftSideSlopePct = $0 }),
                    hillValue: Binding(get: { session.draftHillSlopePct }, set: { session.draftHillSlopePct = $0 })
                )
            }
        case .doubleBreak:
            DoubleBreakButtonsView(value: Binding(get: { session.draftDoubleBreak }, set: { session.draftDoubleBreak = $0 }))
        case .missReasons:
            missReasonRow(session)
        }
    }

    @ViewBuilder
    private func resultContent(_ session: RoundSession) -> some View {
        if config.resultComplexity == .complex {
            DartboardMissView(
                result: Binding(get: { session.draftResult }, set: { session.draftResult = $0 }),
                lipOut: Binding(get: { session.draftLipOut }, set: { session.draftLipOut = $0 })
            )
        } else {
            VStack(spacing: 8) {
                ZStack {
                    Text(L("input.result"))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                    HStack {
                        Spacer()
                        FieldInfoButton(titleKey: "input.result", textKey: "custom.result.desc")
                    }
                }
                // Simple result doubles as the record action, exactly like Quick
                // mode: missing shows the hole's next putt, holing moves on to
                // the next hole. There is no separate save step.
                HStack(spacing: 14) {
                    simpleResultButton(title: L("input.missed"), color: Theme.error) {
                        session.draftResult = .missedGeneric
                        handleOutcome(session.recordDraft(), session)
                    }
                    simpleResultButton(title: L("input.holedBtn"), color: Theme.primary) {
                        session.draftResult = .holed
                        handleOutcome(session.recordDraft(), session)
                    }
                }
            }
        }
    }

    private func simpleResultButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(color))
        }
        .buttonStyle(.plain)
    }

    private func handleOutcome(_ outcome: RoundOutcome, _ session: RoundSession) {
        if outcome == .reachedSequenceEnd {
            showSequenceEndAlert = true
        }
        if let sg = session.lastSavedSG {
            flashSaved(sg: sg)
        }
    }

    private func flashSaved(sg: Double) {
        flashSG = sg
        showSavedFlash = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            showSavedFlash = false
        }
    }

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12) { content() }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
            )
    }

    private func topBar(_ session: RoundSession) -> some View {
        HStack(spacing: 8) {
            Button {
                showHolePicker = true
            } label: {
                VStack(spacing: 0) {
                    Text(L("input.hole")).font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                    HStack(spacing: 2) {
                        Text("\(session.displayHole)").font(.system(size: 30, weight: .black)).foregroundStyle(Theme.primary)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.primary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 40)

            PuttChipsView(session: session)

            if !session.puttsOnHole(session.displayHole).isEmpty {
                Button {
                    showDeleteHoleConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.error)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.error.opacity(0.13)))
                        .overlay(Circle().stroke(Theme.error, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    String(format: L("input.deleteHoleConfirm"), session.displayHole),
                    isPresented: $showDeleteHoleConfirm,
                    titleVisibility: .visible
                ) {
                    Button(L("onCourse.delete"), role: .destructive) {
                        session.deleteAllPuttsOnHole(session.displayHole)
                    }
                    Button(L("common.cancel"), role: .cancel) {}
                }
            }

            VStack(spacing: 0) {
                Text("\(session.totalRealPutts)").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.text)
                Text(L("input.total")).font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.textMuted)
            }

            Button {
                if isPostRoundEdit {
                    round.isComplete = true
                    try? modelContext.save()
                    dismiss()
                } else {
                    showEndRoundAlert = true
                }
            } label: {
                Text(isPostRoundEdit ? L("summary.done") : L("input.end"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isPostRoundEdit ? Theme.primary : Theme.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(isPostRoundEdit ? Theme.primary : Theme.error, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func scoreCategoryRow(_ session: RoundSession) -> some View {
        VStack(spacing: 6) {
            Text(L("input.puttFor")).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(Theme.textMuted)
            HStack(spacing: 6) {
                ForEach(ScoreCategory.allCases) { cat in
                    let selected = session.draftPuttFor == cat
                    Button {
                        session.draftPuttFor = cat
                    } label: {
                        Text(L(cat.shortLabelKey))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(selected ? .white : cat.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(cat.color.opacity(selected ? 0.85 : 0.18)))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(cat.color, lineWidth: selected ? 2 : 1.2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func missReasonRow(_ session: RoundSession) -> some View {
        VStack(spacing: 6) {
            Text(L("custom.field.missReasons")).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(Theme.textMuted)
            HStack(spacing: 8) {
                reasonButton(L("input.missRead"), icon: "📖", isOn: Binding(get: { session.draftMissRead }, set: { session.draftMissRead = $0 }))
                reasonButton(L("input.badStroke"), icon: "🏌️", isOn: Binding(get: { session.draftBadStroke }, set: { session.draftBadStroke = $0 }))
                reasonButton(L("input.wrongAim"), icon: "🎯", isOn: Binding(get: { session.draftWrongAim }, set: { session.draftWrongAim = $0 }))
            }
        }
    }

    private func reasonButton(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text("\(icon) \(title)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Theme.accent : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(isOn.wrappedValue ? Theme.accent.opacity(0.13) : Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(isOn.wrappedValue ? Theme.accent : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func bottomBar(_ session: RoundSession) -> some View {
        HStack(spacing: 8) {
            navArrowButton(icon: "chevron.left", enabled: session.canGoPreviousHole) {
                session.goToPreviousHole()
            }
            navArrowButton(icon: "chevron.right", enabled: session.canGoNextHole) {
                session.goToNextHole()
            }

            // With the simple result the Missed/Holed buttons already record, so
            // a separate save action would be a second way to do the same thing.
            // Tap-in then takes that space, keeping this row to one line.
            if config.resultComplexity == .complex {
                Button {
                    handleOutcome(session.recordDraft(), session)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: recordIcon(session)).font(.system(size: 20, weight: .heavy))
                        Text(recordLabel(session))
                            .font(.system(size: 16, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(session.canRecord ? Theme.primary : Theme.border))
                }
                .buttonStyle(.plain)
                .disabled(!session.canRecord)

                if !session.isReviewing || session.canStartNewPutt {
                    tapInButton(session, fillsRow: false)
                }
            } else if !session.isReviewing || session.canStartNewPutt {
                tapInButton(session, fillsRow: true)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
    }

    /// `fillsRow` stretches it across the space the record button would have
    /// taken, for the simple result where that button isn't shown.
    private func tapInButton(_ session: RoundSession, fillsRow: Bool) -> some View {
        Button {
            if session.isReviewing { session.startNewPutt() }
            handleOutcome(session.recordTapIn(), session)
        } label: {
            Text(L("input.tapInShort"))
                .font(.system(size: fillsRow ? 15 : 13, weight: .heavy))
                .foregroundStyle(fillsRow ? .white : Theme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, fillsRow ? 0 : 12)
                .frame(maxWidth: fillsRow ? .infinity : nil)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .fill(fillsRow ? Theme.primaryDark : Theme.primary.opacity(0.13))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .stroke(fillsRow ? .clear : Theme.primary, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func navArrowButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.text)
                .frame(width: 40, height: 48)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    private func recordIcon(_ session: RoundSession) -> String {
        if session.isReviewing { return "checkmark.circle.fill" }
        if session.draftResult == .holed { return "flag.circle.fill" }
        return "play.circle.fill"
    }

    private func recordLabel(_ session: RoundSession) -> String {
        if session.isReviewing { return L("input.saveEditShort") }
        if session.draftResult == .holed { return L("input.holedNextShort") }
        return L("input.recordShort")
    }
}
