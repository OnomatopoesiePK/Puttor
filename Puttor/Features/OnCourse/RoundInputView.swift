//
//  RoundInputView.swift
//  Puttor
//
//  Pro-mode putt entry. Ported from round/input.tsx, plus the spec addition
//  of a putt-for-category row and a third miss-reason ("wrong aim").
//

import SwiftUI
import SwiftData

struct RoundInputView: View {
    @Bindable var round: Round
    var initialHole: Int? = nil
    var isPostRoundEdit: Bool = false
    var onDone: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"

    @State private var session: RoundSession?
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

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if let holeOutCategory = session.displayedHoleOutCategory {
                        HoleOutCategoryCard(category: holeOutCategory) { newCategory in
                            session.updateHoleOutCategory(session.displayHole, to: newCategory)
                        }
                    }

                    section {
                        DistancePickerView(value: Binding(get: { session.draftDistanceM }, set: { session.draftDistanceM = $0 }), useFeet: useFeet)
                    }

                    section {
                        scoreCategoryRow(session)
                    }

                    section {
                        SlopeGridPickerView(
                            sideValue: Binding(get: { session.draftSideSlopePct }, set: { session.draftSideSlopePct = $0 }),
                            hillValue: Binding(get: { session.draftHillSlopePct }, set: { session.draftHillSlopePct = $0 })
                        )
                        DoubleBreakButtonsView(value: Binding(get: { session.draftDoubleBreak }, set: { session.draftDoubleBreak = $0 }))
                    }

                    section {
                        DartboardMissView(
                            result: Binding(get: { session.draftResult }, set: { session.draftResult = $0 }),
                            lipOut: Binding(get: { session.draftLipOut }, set: { session.draftLipOut = $0 })
                        )
                        missReasonRow(session)
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .overlay(alignment: .top) {
                InputStatusBanner(
                    savedSG: showSavedFlash ? flashSG : nil,
                    isEditing: session.hasUnsavedEdits
                )
                .animation(.easeOut(duration: 0.2), value: showSavedFlash)
            }

            bottomBar(session)
        }
        .alert(L("input.holeCompleteTitle"), isPresented: $showSequenceEndAlert) {
            Button(L("input.endRound")) { session.endRound(holeCount: session.playedHoleCount <= 9 ? 9 : 18); navigateToSummary = true }
            Button(L("input.continueFromStart")) { /* session already advanced internally on next putt entry */ }
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
        // Border is folded into .background() (not .overlay()) so content that
        // intentionally overflows its card — e.g. the enlarged slope grid —
        // renders in front of the border instead of being cut off by it.
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
        ScoreCategoryRow(selection: Binding(get: { session.draftPuttFor }, set: { session.draftPuttFor = $0 }))
    }

    private func missReasonRow(_ session: RoundSession) -> some View {
        MissReasonRow(
            missRead: Binding(get: { session.draftMissRead }, set: { session.draftMissRead = $0 }),
            badStroke: Binding(get: { session.draftBadStroke }, set: { session.draftBadStroke = $0 }),
            badStrokeType: Binding(get: { session.draftBadStrokeType }, set: { session.draftBadStrokeType = $0 }),
            wrongAim: Binding(get: { session.draftWrongAim }, set: { session.draftWrongAim = $0 }),
            showsTitle: false
        )
    }

    private func bottomBar(_ session: RoundSession) -> some View {
        HStack(spacing: 8) {
            navArrowButton(icon: "chevron.left", enabled: session.canGoPreviousHole) {
                session.goToPreviousHole()
            }
            navArrowButton(icon: "chevron.right", enabled: session.canGoNextHole) {
                session.goToNextHole()
            }

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
                Button {
                    if session.isReviewing { session.startNewPutt() }
                    handleOutcome(session.recordTapIn(), session)
                } label: {
                    Text(L("input.tapInShort"))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary.opacity(0.13)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.primary, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
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
