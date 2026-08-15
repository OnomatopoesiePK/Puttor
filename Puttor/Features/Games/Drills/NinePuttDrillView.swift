//
//  NinePuttDrillView.swift
//  Puttor
//
//  9-Putt Drill: 3 balls from each of 3 distances (9 putts total). All 9 must
//  go in, or you start the cycle over. Score = cycles needed to clear (lower
//  is better) — so this is a bespoke loop, not the generic % engine.
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
            NinePuttPlayView(distances: distances, configSummary: configSummary, useFeet: useFeet) { session in
                finishedSession = session
            }
        }
        .navigationDestination(item: $finishedSession) { session in
            GameResultView(
                gameType: .ninePutt,
                session: session,
                isNewBest: GameScoring.isNewBest(session, among: allSessions),
                onDone: onDone
            )
        }
    }

    private func configCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}

private struct NinePuttPlayView: View {
    let distances: [Double]
    let configSummary: String
    let useFeet: Bool
    var onFinished: (GameSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var cycle = 1
    @State private var index = 0
    @State private var currentCycleResults: [Bool] = []
    @State private var allAttempts: [(cycle: Int, label: String, distance: Double, success: Bool)] = []

    private var puttPlan: [(label: String, distance: Double)] {
        distances.enumerated().flatMap { _, d in
            (1...3).map { ball in (label: "\(L("game.ninePutt.ball")) \(ball) · \(UnitConverter.formatDistance(d, useFeet: useFeet))", distance: d) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            card
            Spacer()
            SuccessFailButtons(
                successLabel: L("game.made"),
                failLabel: L("game.missed"),
                onSuccess: { mark(true) },
                onFail: { mark(false) }
            )
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L(GameType.ninePutt.titleKey)).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.text)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L("game.giveUp")) { dismiss() }
                    .foregroundStyle(Theme.textSecondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: .ninePutt)
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("\(L("game.ninePutt.cycle")) \(cycle)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("\(L("game.attempt")) \(index + 1) / 9")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textMuted)
            ProgressView(value: Double(index), total: 9)
                .tint(Theme.primary)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, Theme.Spacing.md)
    }

    private var card: some View {
        let item = puttPlan[index]
        return VStack(spacing: 10) {
            Text(item.label)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func mark(_ success: Bool) {
        let item = puttPlan[index]
        allAttempts.append((cycle, item.label, item.distance, success))
        currentCycleResults.append(success)
        if index + 1 < 9 {
            index += 1
        } else if currentCycleResults.allSatisfy({ $0 }) {
            finish()
        } else {
            cycle += 1
            index = 0
            currentCycleResults = []
        }
    }

    private func finish() {
        let session = GameSession(gameType: .ninePutt)
        session.configSummary = configSummary
        session.attemptsTotal = allAttempts.count
        session.madeTotal = allAttempts.filter { $0.success }.count
        session.score = Double(cycle)
        session.isComplete = true
        modelContext.insert(session)
        for (i, a) in allAttempts.enumerated() {
            let attempt = GameAttempt(groupIndex: a.cycle, index: i, label: a.label, distanceM: a.distance, success: a.success)
            attempt.session = session
            session.attempts.append(attempt)
            modelContext.insert(attempt)
        }
        try? modelContext.save()
        onFinished(session)
    }
}
