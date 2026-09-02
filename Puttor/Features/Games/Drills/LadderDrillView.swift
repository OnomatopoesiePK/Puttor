//
//  LadderDrillView.swift
//  Puttor
//
//  Ladder Drill: one spot, a row of target distances, and a 30 cm window
//  either side of each. Nothing is holed here — the ball only has to stop in
//  the window — so it is the one drill that trains pace on its own, with the
//  line taken out of the question.
//
//  Two ladders: whole metres from 5 m out to lag range, or half metres between
//  5 and 10 m, where the gaps are small enough that the stroke has to be
//  measured rather than felt.
//

import SwiftUI
import SwiftData

struct LadderDrillView: View {
    var onDone: () -> Void

    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"

    @State private var mode: LadderMode = .large
    @State private var fromM: Double = LadderMode.large.shortestM
    @State private var toM: Double = LadderMode.large.longestM
    @State private var playing = false
    @State private var finishedSession: GameSession?

    private var useFeet: Bool { unitsPref == "imperial" }
    private var rungs: [Double] { LadderPlan.distances(mode: mode, fromM: fromM, toM: toM) }

    private var configSummary: String {
        "\(L(mode.labelKey)) · \(UnitConverter.formatDistance(fromM, useFeet: useFeet))–\(UnitConverter.formatDistance(toM, useFeet: useFeet)) · \(rungs.count) \(L("game.ladder.rungs"))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(L(GameType.ladder.goalKey))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)

                modeCard
                rangeCard
                ladderCard

                Button {
                    playing = true
                } label: {
                    Text(L("game.start"))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.md)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L(GameType.ladder.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: .ladder)
            }
        }
        .navigationDestination(isPresented: $playing) {
            TimedDrillPlayView(
                gameType: .ladder,
                reminder: String(
                    format: L("game.ladder.targetReminder"),
                    rungs.count,
                    UnitConverter.formatDistance(LadderPlan.toleranceM, useFeet: useFeet)
                ),
                configSummary: configSummary,
                configDistanceM: LadderPlan.middleDistanceM(mode: mode, fromM: fromM, toM: toM),
                targetRounds: rungs.count,
                extra: {
                    LadderMap(distances: rungs, useFeet: useFeet)
                        .frame(maxHeight: 260)
                },
                onFinished: { session in finishedSession = session }
            )
        }
        .navigationDestination(item: $finishedSession) { session in
            TimedDrillResultView(session: session, onDone: onDone)
        }
    }

    // MARK: - Setup

    private var modeCard: some View {
        configCard {
            Text(L("game.ladder.mode")).font(.caption).foregroundStyle(Theme.textMuted)
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(LadderMode.allCases) { option in
                    Button {
                        mode = option
                        // Each ladder has its own range, so switching resets to
                        // the whole of the new one rather than keeping numbers
                        // that mean something else.
                        fromM = option.shortestM
                        toM = option.longestM
                    } label: {
                        VStack(spacing: 3) {
                            Text(L(option.labelKey))
                                .font(.system(size: 13, weight: .bold))
                            Text(String(
                                format: L("game.ladder.stepNote"),
                                UnitConverter.formatDistance(option.stepM, useFeet: useFeet)
                            ))
                            .font(.system(size: 10))
                            .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(mode == option ? Theme.primary : Theme.textSecondary)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(mode == option ? Theme.primary.opacity(0.12) : Theme.surfaceElevated))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(mode == option ? Theme.primary : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var rangeCard: some View {
        configCard {
            Stepper(
                "\(L("game.ladder.from")): \(UnitConverter.formatDistance(fromM, useFeet: useFeet))",
                value: $fromM,
                in: mode.shortestM...mode.longestM,
                step: mode.stepM
            )
            .foregroundStyle(Theme.text)
            .onChange(of: fromM) { _, new in if toM < new { toM = new } }

            Stepper(
                "\(L("game.ladder.to")): \(UnitConverter.formatDistance(toM, useFeet: useFeet))",
                value: $toM,
                in: mode.shortestM...mode.longestM,
                step: mode.stepM
            )
            .foregroundStyle(Theme.text)
            .onChange(of: toM) { _, new in if fromM > new { fromM = new } }

            Text(String(
                format: L("game.ladder.window"),
                UnitConverter.formatDistance(LadderPlan.toleranceM, useFeet: useFeet)
            ))
            .font(.system(size: 11))
            .foregroundStyle(Theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ladderCard: some View {
        VStack(spacing: 8) {
            LadderMap(distances: rungs, useFeet: useFeet)
                .frame(height: min(280, CGFloat(rungs.count) * 22 + 30))
            Text(String(format: L("game.ladder.rungCount"), rungs.count))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    private func configCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}
