//
//  NinePuttDrillView.swift
//  Puttor
//
//  9-Putt Drill: 3 balls from each of 3 distances (9 putts total). All 9 must
//  go in, or the cycle starts over — counted on the green rather than on the
//  phone, so the app only runs the clock and records that the practice
//  happened.
//

import SwiftUI
import SwiftData

struct NinePuttDrillView: View {
    var onDone: () -> Void
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @Query(sort: \GameSession.date, order: .reverse) private var allSessions: [GameSession]

    @State private var distances: [Double] = [1.0, 2.0, 3.0]
    @State private var playing = false
    @State private var finishedSession: GameSession?

    private var useFeet: Bool { unitsPref == "imperial" }
    private var configSummary: String {
        distances.map { UnitConverter.formatDistance($0, useFeet: useFeet) }.joined(separator: " / ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(L(GameType.ninePutt.goalKey))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)

                ForEach(0..<3, id: \.self) { i in
                    configCard {
                        Text("\(L("game.ninePutt.distance")) \(i + 1)").font(.caption).foregroundStyle(Theme.textMuted)
                        Stepper(UnitConverter.formatDistance(distances[i], useFeet: useFeet), value: $distances[i], in: 0.5...8, step: 0.5)
                            .foregroundStyle(Theme.text)
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
        .navigationTitle(L(GameType.ninePutt.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: .ninePutt)
            }
        }
        .navigationDestination(isPresented: $playing) {
            TimedDrillPlayView(
                gameType: .ninePutt,
                reminder: String(format: L("game.ninePutt.reminder"), configSummary),
                configSummary: configSummary
            ) { session in
                finishedSession = session
            }
        }
        .navigationDestination(item: $finishedSession) { session in
            TimedDrillResultView(session: session, onDone: onDone)
        }
    }

    private func configCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}
