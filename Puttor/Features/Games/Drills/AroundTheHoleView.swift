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
            TimedDrillPlayView(
                gameType: .aroundTheHole,
                reminder: String(format: L("game.ath.targetReminder"), rounds, UnitConverter.formatDistance(distance, useFeet: useFeet)),
                configSummary: configSummary,
                configDistanceM: distance,
                targetRounds: rounds,
                extra: { AroundTheHoleMap(currentStation: nil, madeStations: []).frame(maxHeight: 240) },
                onFinished: { session in finishedSession = session }
            )
        }
        .navigationDestination(item: $finishedSession) { session in
            TimedDrillResultView(session: session, onDone: onDone)
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
