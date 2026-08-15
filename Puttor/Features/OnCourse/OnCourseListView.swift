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
                startButton

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
            .confirmationDialog(
                roundForActionSheet?.courseName.isEmpty == false ? roundForActionSheet!.courseName : L("onCourse.unnamedCourse"),
                isPresented: Binding(get: { roundForActionSheet != nil }, set: { if !$0 { roundForActionSheet = nil } }),
                titleVisibility: .visible
            ) {
                if let r = roundForActionSheet {
                    Button(L("onCourse.edit")) {
                        r.isComplete = false
                        try? modelContext.save()
                        roundToOpen = r
                    }
                    Button(r.isComplete ? L("onCourse.open") : L("onCourse.resume")) {
                        roundToOpen = r
                    }
                    Button(L("onCourse.editSettings")) {
                        roundToEditSettings = r
                    }
                    Button(L("onCourse.delete"), role: .destructive) {
                        modelContext.delete(r)
                        try? modelContext.save()
                    }
                    Button(L("common.cancel"), role: .cancel) {}
                }
            }
            .fullScreenCover(item: $roundToEditSettings) { round in
                RoundSetupView(existingRound: round, onSaved: { roundToEditSettings = nil })
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("On Course")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var startButton: some View {
        Button {
            showingSetup = true
        } label: {
            HStack(spacing: 12) {
                Text("⛳").font(.system(size: 24))
                Text(L("onCourse.startNewRound"))
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
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

    private func roundCard(_ round: Round) -> some View {
        Button {
            roundToOpen = round
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.courseName.isEmpty ? L("onCourse.unnamedCourse") : round.courseName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text)
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

                Text(round.isComplete ? L("onCourse.complete") : L("onCourse.inProgress"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((round.isComplete ? Theme.primary : Theme.accent).opacity(0.13)))

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
