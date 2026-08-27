//
//  AroundTheHoleView.swift
//  Puttor
//
//  Around The Hole: five tees around the cup — one straight uphill putt to
//  start on, then the four breaking ones. Hole them all, lap after lap, until
//  the target number of clean laps is done. A miss puts you back to the start
//  of the lap, so this is a drill you finish rather than a score you chase.
//

import SwiftUI
import SwiftData

struct AroundTheHoleView: View {
    var onDone: () -> Void

    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @Query(sort: \GameSession.date, order: .reverse) private var allSessions: [GameSession]

    @State private var distance: Double = 1.0
    @State private var rounds: Int = AroundTheHolePlan.defaultRounds(forDistance: 1.0)
    /// Cleared once the player touches the stepper, so a suggestion never
    /// overrides a deliberate choice.
    @State private var roundsTouched = false
    @State private var playing = false
    @State private var finishedSession: GameSession?

    private var useFeet: Bool { unitsPref == "imperial" }

    private var suggestedRounds: Int {
        AroundTheHolePlan.suggestedRounds(forDistance: distance, history: allSessions)
    }

    /// True once a session at this distance has been rated, which is what the
    /// suggestion is drawn from — before that it is just the default.
    private var suggestionHasHistory: Bool {
        allSessions.contains {
            $0.gameType == .aroundTheHole
                && abs($0.configDistanceM - distance) < 0.05
                && $0.difficulty != nil
        }
    }

    private var configSummary: String {
        "\(AroundTheHolePlan.puttsPerLap) \(L("game.ath.tees")) · \(UnitConverter.formatDistance(distance, useFeet: useFeet)) · \(rounds) \(L("game.ath.rounds"))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(L(GameType.aroundTheHole.goalKey))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)

                stationMap

                configCard {
                    Text(L("game.distance")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper(UnitConverter.formatDistance(distance, useFeet: useFeet), value: $distance, in: 0.5...5, step: 0.1)
                        .foregroundStyle(Theme.text)
                        .onChange(of: distance) { _, _ in
                            if !roundsTouched { rounds = suggestedRounds }
                        }
                }

                configCard {
                    HStack {
                        Text(L("game.ath.rounds")).font(.caption).foregroundStyle(Theme.textMuted)
                        Spacer()
                        Text(String(format: L("game.ath.puttsTotal"), rounds * AroundTheHolePlan.puttsPerLap))
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    Stepper("\(rounds)", value: $rounds, in: 1...20)
                        .foregroundStyle(Theme.text)
                        .onChange(of: rounds) { _, _ in roundsTouched = true }

                    if rounds != suggestedRounds {
                        Button {
                            rounds = suggestedRounds
                            roundsTouched = false
                        } label: {
                            Text(String(format: L(suggestionHasHistory ? "game.ath.suggestionFromLast" : "game.ath.suggestion"), suggestedRounds))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

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
        .navigationTitle(L(GameType.aroundTheHole.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: .aroundTheHole)
            }
        }
        .onAppear { if !roundsTouched { rounds = suggestedRounds } }
        .navigationDestination(isPresented: $playing) {
            AroundTheHolePlayView(
                distance: distance,
                targetRounds: rounds,
                configSummary: configSummary,
                useFeet: useFeet
            ) { session in
                finishedSession = session
            }
        }
        .navigationDestination(item: $finishedSession) { session in
            AroundTheHoleResultView(session: session, onDone: onDone)
        }
    }

    /// The setup, drawn: where each tee goes and which way it breaks.
    private var stationMap: some View {
        VStack(spacing: 8) {
            AroundTheHoleMap(currentStation: nil, madeStations: [])
                .frame(height: 200)
            Text(L("game.ath.mapHint"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
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

// MARK: - Play

private struct AroundTheHolePlayView: View {
    let distance: Double
    let targetRounds: Int
    let configSummary: String
    let useFeet: Bool
    var onFinished: (GameSession) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var startedAt = Date()
    @State private var showEndDialog = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Nothing to tap while putting: the drill is counted on the green,
            // and the phone only keeps the time.
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(GameScoreFormat.clockText(context.date.timeIntervalSince(startedAt)))
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primary)
                    .monospacedDigit()
            }
            .padding(.top, Theme.Spacing.lg)

            Text(String(format: L("game.ath.targetReminder"), targetRounds, UnitConverter.formatDistance(distance, useFeet: useFeet)))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            AroundTheHoleMap(currentStation: nil, madeStations: [])
                .frame(maxHeight: 240)

            Spacer(minLength: 0)

            Button {
                showEndDialog = true
            } label: {
                Text(L("game.ath.end"))
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L(GameType.aroundTheHole.titleKey))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.text)
            }
        }
        .confirmationDialog(L("game.ath.endTitle"), isPresented: $showEndDialog, titleVisibility: .visible) {
            // The one thing the app can't see for itself: whether the laps
            // actually came off.
            Button(L("game.ath.endCompleted")) { finish(completed: true) }
            Button(L("game.ath.endGaveUp")) { finish(completed: false) }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("game.ath.endMessage"))
        }
    }

    private func finish(completed: Bool) {
        let session = GameSession(gameType: .aroundTheHole)
        session.configSummary = configSummary
        session.configDistanceM = distance
        session.targetRounds = targetRounds
        session.durationSeconds = Date().timeIntervalSince(startedAt)
        // Only a finished drill is a time to beat; an abandoned one is kept as
        // a record that the practice happened.
        session.isComplete = completed
        session.score = session.durationSeconds / 60
        modelContext.insert(session)
        try? modelContext.save()
        onFinished(session)
    }
}

// MARK: - Result

private struct AroundTheHoleResultView: View {
    let session: GameSession
    var onDone: () -> Void

    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @Environment(\.modelContext) private var modelContext
    @State private var picked: DrillDifficulty?

    private var useFeet: Bool { unitsPref == "imperial" }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text(GameType.aroundTheHole.icon).font(.system(size: 56))
                Text(L(session.isComplete ? "game.ath.finished" : "game.ath.stopped"))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(session.isComplete ? Theme.primary : Theme.textSecondary)

                VStack(spacing: 4) {
                    Text(GameScoreFormat.clockText(session.durationSeconds))
                        .font(.system(size: 56, weight: .black))
                        .foregroundStyle(Theme.primary)
                    Text(L("game.ath.timeTaken"))
                        .font(.system(size: 12, weight: .bold)).tracking(1.2)
                        .foregroundStyle(Theme.textMuted)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    statBox(L("game.ath.roundsTarget"), "\(session.targetRounds)")
                    statBox(L("game.distance"), UnitConverter.formatDistance(session.configDistanceM, useFeet: useFeet))
                }

                if !session.configSummary.isEmpty {
                    Text(session.configSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
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

    /// The one question the drill asks, and the only one that changes what it
    /// offers next time.
    private var difficultyCard: some View {
        VStack(spacing: 10) {
            Text(L("game.ath.howWasIt"))
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

            if picked == .tooEasy {
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
