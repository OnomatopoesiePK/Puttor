//
//  GateDrillView.swift
//  Puttor
//
//  Gate Drill: putt through two tees ("gate") set just in front of the ball,
//  checking start-line control. Instead of marking every single rep, you
//  play the whole set then enter how many of them you made.
//

import SwiftUI
import SwiftData

struct GateDrillView: View {
    var onDone: () -> Void
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @Query(sort: \GameSession.date, order: .reverse) private var allSessions: [GameSession]

    @State private var distance: Double = 0.5
    @State private var reps: Int = 20
    @State private var playing = false
    @State private var finishedSession: GameSession?

    private var useFeet: Bool { unitsPref == "imperial" }
    private var configSummary: String {
        "\(reps) \(L("game.gate.reps")) · \(UnitConverter.formatDistance(distance, useFeet: useFeet))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(L(GameType.gate.goalKey))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)

                configCard {
                    Text(L("game.distance")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper(UnitConverter.formatDistance(distance, useFeet: useFeet), value: $distance, in: 0.5...5, step: 0.5)
                        .foregroundStyle(Theme.text)
                }
                configCard {
                    Text(L("game.gate.reps")).font(.caption).foregroundStyle(Theme.textMuted)
                    Stepper("\(reps)", value: $reps, in: 3...50)
                        .foregroundStyle(Theme.text)
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
        .navigationTitle(L(GameType.gate.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: .gate)
            }
        }
        .navigationDestination(isPresented: $playing) {
            GateTallyEntryView(reps: reps, configSummary: configSummary) { session in
                finishedSession = session
            }
        }
        .navigationDestination(item: $finishedSession) { session in
            GameResultView(
                gameType: .gate,
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

private struct GateTallyEntryView: View {
    let reps: Int
    let configSummary: String
    var onFinished: (GameSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var madeText: String = ""
    @FocusState private var fieldFocused: Bool

    private var madeCount: Int? {
        guard let v = Int(madeText), v >= 0, v <= reps else { return nil }
        return v
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: 10) {
                Text(L("game.gate.howMany"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                Text(String(format: L("game.gate.outOf"), reps))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
            }

            TextField("0", text: $madeText)
                .keyboardType(.numberPad)
                .focused($fieldFocused)
                .multilineTextAlignment(.center)
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(Theme.primary)
                .frame(width: 180, height: 100)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(fieldFocused ? Theme.primary : Theme.border, lineWidth: 2))
                .onTapGesture { fieldFocused = true }

            Spacer()

            Button {
                finish()
            } label: {
                Text(L("game.done"))
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(madeCount != nil ? Theme.primary : Theme.border))
            }
            .buttonStyle(.plain)
            .disabled(madeCount == nil)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L(GameType.gate.titleKey)).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.text)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L("game.giveUp")) { dismiss() }
                    .foregroundStyle(Theme.textSecondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: .gate)
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { fieldFocused = true }
    }

    private func finish() {
        guard let made = madeCount else { return }
        let session = GameSession(gameType: .gate)
        session.configSummary = configSummary
        session.attemptsTotal = reps
        session.madeTotal = made
        session.score = reps > 0 ? Double(made) / Double(reps) * 100 : 0
        session.isComplete = true
        modelContext.insert(session)
        try? modelContext.save()
        onFinished(session)
    }
}
