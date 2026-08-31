//
//  OnCourseListView.swift
//  Puttor
//
//  Tab 1 root. Ported from (tabs)/index.tsx.
//

import SwiftUI
import SwiftData

struct OnCourseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.date, order: .reverse) private var rounds: [Round]

    @State private var showingSetup = false
    @State private var roundToOpen: Round?
    @State private var roundForActionSheet: Round?
    @State private var roundToEditSettings: Round?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if rounds.isEmpty {
                    emptyState
                    Spacer()
                } else {
                    List {
                        Section {
                            ForEach(rounds) { round in
                                roundCard(round)
                                    .listRowBackground(Theme.background)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: Theme.Spacing.lg, bottom: 4, trailing: Theme.Spacing.lg))
                            }
                        } header: {
                            Text(L("onCourse.recentRounds"))
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(Theme.textMuted)
                                // Headers carry their own default insets, which
                                // don't match the ones set on the rows — without
                                // this the heading sits left of the cards.
                                .listRowInsets(EdgeInsets(top: 10, leading: Theme.Spacing.lg, bottom: 6, trailing: Theme.Spacing.lg))
                                .textCase(nil)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingSetup) {
                RoundSetupView { newRound in
                    showingSetup = false
                    roundToOpen = newRound
                }
            }
            .navigationDestination(item: $roundToOpen) { round in
                if round.isComplete {
                    RoundSummaryView(round: round, onDone: { roundToOpen = nil })
                } else if round.inputMode == .quick {
                    RoundInputQuickView(round: round, onDone: { roundToOpen = nil })
                } else if round.inputMode == .custom {
                    RoundInputCustomView(round: round, onDone: { roundToOpen = nil })
                } else {
                    RoundInputView(round: round, onDone: { roundToOpen = nil })
                }
            }
            .fullScreenCover(item: $roundToEditSettings) { round in
                RoundSetupView(existingRound: round, onSaved: { roundToEditSettings = nil })
            }
        }
    }

    /// Title and the one action on this screen share a line, which gives the
    /// list of rounds back the height a full-width button used to take.
    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            ScreenTitle(text: "On Course")
            Spacer(minLength: 0)
            startButton
        }
        .screenHeaderPadding()
    }

    private var startButton: some View {
        Button {
            showingSetup = true
        } label: {
            HStack(spacing: 8) {
                Text("⛳").font(.system(size: 18))
                Text(L("onCourse.startNewRound"))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🏌️").font(.system(size: 48))
            Text(L("onCourse.noRounds"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(L("onCourse.noRoundsHint"))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    /// Same total RoundStats reports, summed directly here rather than building
    /// the full stats (brackets, dispersion, leaves) for every row of the list.
    private func strokesGained(_ round: Round) -> Double {
        // Strokes gained is a per-hole measure, so it's summed over holes.
        Set(round.putts.map(\.holeNumber)).compactMap { hole in
            RoundStats.holeStrokesGained(round.putts.filter { $0.holeNumber == hole })
        }.reduce(0, +)
    }

    private func roundCard(_ round: Round) -> some View {
        Button {
            roundToOpen = round
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 1) {
                        Text(round.courseName.isEmpty ? L("onCourse.unnamedCourse") : round.courseName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.text)
                        // Marks a round scored over nine holes, so its totals
                        // aren't mistaken for a full round's.
                        if round.isComplete && round.holeCount == 9 {
                            Text("*")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Theme.accent)
                                .accessibilityLabel(L("onCourse.nineHoleRound"))
                        }
                    }
                    HStack(spacing: 6) {
                        Text(round.date.formatted(date: .abbreviated, time: .omitted))
                        if let putter = round.putter {
                            Text("·")
                            Text(putter.name)
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button {
                    roundForActionSheet = round
                } label: {
                    Text("⋮")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Theme.surfaceElevated))
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                // Attached to this row's own button, and presented only for this
                // row, so where the popover points is the round it acts on.
                .confirmationDialog(
                    round.courseName.isEmpty ? L("onCourse.unnamedCourse") : round.courseName,
                    isPresented: Binding(
                        get: { roundForActionSheet?.persistentModelID == round.persistentModelID },
                        set: { if !$0 { roundForActionSheet = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button(L("onCourse.edit")) {
                        round.isComplete = false
                        try? modelContext.save()
                        roundToOpen = round
                    }
                    Button(round.isComplete ? L("onCourse.open") : L("onCourse.resume")) {
                        roundToOpen = round
                    }
                    Button(L("onCourse.editSettings")) {
                        roundToEditSettings = round
                    }
                    Button(L("onCourse.delete"), role: .destructive) {
                        modelContext.delete(round)
                        try? modelContext.save()
                    }
                    Button(L("common.cancel"), role: .cancel) {}
                }

                VStack(spacing: 3) {
                    Text(round.isComplete ? L("onCourse.complete") : L("onCourse.inProgress"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill((round.isComplete ? Theme.primary : Theme.accent).opacity(0.13)))

                    if round.isComplete {
                        let sg = strokesGained(round)
                        Text("\(sg > 0 ? "+" : "")\(String(format: "%.2f", sg)) \(L("summary.sg"))")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(sg >= 0 ? Theme.primary : Theme.error)
                    }
                }

                Text("›").font(.system(size: 22)).foregroundStyle(Theme.textMuted)
            }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnCourseListView()
        .modelContainer(for: [Putter.self, Round.self, Putt.self], inMemory: true)
}
