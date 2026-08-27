//
//  TimedDrillViews.swift
//  Puttor
//
//  Screens for drills that are counted on the green rather than on the phone:
//  while it runs there is nothing to tap but a stopwatch, and the only thing
//  the app can't see for itself — whether the drill came off — is answered
//  once at the end.
//

import SwiftUI
import SwiftData

struct TimedDrillPlayView<Extra: View>: View {
    let gameType: GameType
    /// One line naming what has to come off, e.g. "5 clean laps at 1.0 m".
    let reminder: String
    let configSummary: String
    var configDistanceM: Double = 0
    var targetRounds: Int = 0
    @ViewBuilder var extra: () -> Extra
    var onFinished: (GameSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var startedAt = Date()

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(GameScoreFormat.clockText(context.date.timeIntervalSince(startedAt)))
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primary)
                    .monospacedDigit()
            }
            .padding(.top, Theme.Spacing.lg)

            Text(reminder)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            extra()

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    finish(completed: true)
                } label: {
                    Text(L("game.drill.succeeded"))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
                }
                .buttonStyle(.plain)

                // Giving up is kept as practice that happened, so it is a
                // quieter button rather than a hidden one.
                Button {
                    finish(completed: false)
                } label: {
                    Text(L("game.drill.giveUp"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L(gameType.titleKey))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.text)
            }
        }
    }

    private func finish(completed: Bool) {
        let session = GameSession(gameType: gameType)
        session.configSummary = configSummary
        session.configDistanceM = configDistanceM
        session.targetRounds = targetRounds
        session.durationSeconds = Date().timeIntervalSince(startedAt)
        // Only a finished drill is a time to beat; an abandoned one still
        // counts as practice on the activity board.
        session.isComplete = completed
        session.score = session.durationSeconds / 60
        modelContext.insert(session)
        try? modelContext.save()
        onFinished(session)
    }
}

extension TimedDrillPlayView where Extra == EmptyView {
    init(
        gameType: GameType,
        reminder: String,
        configSummary: String,
        configDistanceM: Double = 0,
        targetRounds: Int = 0,
        onFinished: @escaping (GameSession) -> Void
    ) {
        self.init(
            gameType: gameType, reminder: reminder, configSummary: configSummary,
            configDistanceM: configDistanceM, targetRounds: targetRounds,
            extra: { EmptyView() }, onFinished: onFinished
        )
    }
}

// MARK: - Result

struct TimedDrillResultView: View {
    let session: GameSession
    var onDone: () -> Void

    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @Environment(\.modelContext) private var modelContext
    @State private var picked: DrillDifficulty?

    private var useFeet: Bool { unitsPref == "imperial" }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text(session.gameType.icon).font(.system(size: 56))
                Text(L(session.isComplete ? "game.drill.finished" : "game.drill.stopped"))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(session.isComplete ? Theme.primary : Theme.textSecondary)

                VStack(spacing: 4) {
                    Text(GameScoreFormat.clockText(session.durationSeconds))
                        .font(.system(size: 56, weight: .black))
                        .foregroundStyle(Theme.primary)
                    Text(L("game.drill.timeTaken"))
                        .font(.system(size: 12, weight: .bold)).tracking(1.2)
                        .foregroundStyle(Theme.textMuted)
                }

                if session.targetRounds > 0 || session.configDistanceM > 0 {
                    HStack(spacing: Theme.Spacing.sm) {
                        if session.targetRounds > 0 {
                            statBox(L("game.ath.roundsTarget"), "\(session.targetRounds)")
                        }
                        if session.configDistanceM > 0 {
                            statBox(L("game.distance"), UnitConverter.formatDistance(session.configDistanceM, useFeet: useFeet))
                        }
                    }
                }

                if !session.configSummary.isEmpty {
                    Text(session.configSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }

                difficultyCard

                Button(action: onDone) {
                    Text(L("game.done"))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear { picked = session.difficulty }
    }

    /// The one question the drill asks, and — where a drill has a target to
    /// raise — the only one that changes what it offers next time.
    private var difficultyCard: some View {
        VStack(spacing: 10) {
            Text(L("game.drill.howWasIt"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.text)

            HStack(spacing: Theme.Spacing.xs) {
                ForEach(DrillDifficulty.allCases) { option in
                    Button {
                        picked = option
                        session.difficulty = option
                        try? modelContext.save()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.icon).font(.system(size: 18, weight: .semibold))
                            Text(L(option.labelKey))
                                .font(.system(size: 11, weight: .bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 66)
                        .padding(.vertical, 8)
                        .foregroundStyle(picked == option ? Theme.primary : Theme.textSecondary)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(picked == option ? Theme.primary.opacity(0.12) : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(picked == option ? Theme.primary : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if picked == .tooEasy, session.targetRounds > 0 {
                Text(L("game.ath.willAddRound"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    private func statBox(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .black)).foregroundStyle(Theme.text)
            Text(label).font(.system(size: 9, weight: .bold)).tracking(0.6).foregroundStyle(Theme.textMuted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 62)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}
