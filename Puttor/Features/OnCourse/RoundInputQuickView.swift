//
//  RoundInputQuickView.swift
//  Puttor
//
//  Quick mode: distance + putt-for-category + made/missed only — no slope
//  grid, no dartboard direction, no miss-reasons. New vs. the prototype
//  (which only had one, "Pro"-equivalent, flow).
//

import SwiftUI
import SwiftData

struct RoundInputQuickView: View {
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
            } else if session.hasUnsavedEdits {
                Text(L("input.editing"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.accent.opacity(0.13))
            }

            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                Text(L("inputMode.quick"))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textMuted)

                DistancePickerView(value: Binding(get: { session.draftDistanceM }, set: { session.draftDistanceM = $0 }), useFeet: useFeet)

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

                HStack(spacing: 14) {
                    bigButton(title: L("input.missed"), color: Theme.error) {
                        session.draftResult = .missedGeneric
                        handleOutcome(session.recordDraft(), session)
                    }
                    bigButton(title: L("input.holedBtn"), color: Theme.primary) {
                        session.draftResult = .holed
                        handleOutcome(session.recordDraft(), session)
                    }
                }

                if !session.isReviewing || session.canStartNewPutt {
                    Button {
                        if session.isReviewing { session.startNewPutt() }
                        handleOutcome(session.recordTapIn(), session)
                    } label: {
                        Text(L("input.tapIn"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.lg)

            Spacer()

            holeNavBar(session)
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

    private func handleOutcome(_ outcome: RoundOutcome, _ session: RoundSession) {
        if outcome == .reachedSequenceEnd { showSequenceEndAlert = true }
        if let sg = session.lastSavedSG {
            flashSG = sg
            showSavedFlash = true
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                showSavedFlash = false
            }
        }
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
        .padding(Theme.Spacing.md)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    /// Hole navigation, matching Pro/Custom: the arrows step through the round's
    /// play order and never record anything themselves.
    private func holeNavBar(_ session: RoundSession) -> some View {
        HStack(spacing: 8) {
            navArrowButton(icon: "chevron.left", enabled: session.canGoPreviousHole) {
                session.goToPreviousHole()
            }
            Spacer()
            Text("\(L("input.hole")) \(session.displayHole)")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
            Spacer()
            navArrowButton(icon: "chevron.right", enabled: session.canGoNextHole) {
                session.goToNextHole()
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
                .frame(width: 56, height: 48)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    private func bigButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(color))
        }
        .buttonStyle(.plain)
    }
}
