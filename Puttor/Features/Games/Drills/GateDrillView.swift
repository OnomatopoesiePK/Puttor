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
                // Straight, so a miss is the start line and never the break.
                Label(L("game.gate.straightPutt"), systemImage: "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)

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

/// After the set: how many were made and how many missed left. Whatever was
/// neither went right.
private struct GateTallyEntryView: View {
    let reps: Int
    let configSummary: String
    var onFinished: (GameSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var madeText = ""
    @State private var leftText = ""
    @FocusState private var focused: Field?

    private enum Field { case made, left }

    private func count(_ text: String) -> Int? {
        guard let value = Int(text), value >= 0, value <= reps else { return nil }
        return value
    }

    private var missedRight: Int? {
        guard let made = count(madeText), let left = count(leftText), made + left <= reps else { return nil }
        return reps - made - left
    }

    /// More made, or missed left, than there were putts in the set — alone or
    /// together.
    private var tooMany: Bool {
        let made = Int(madeText) ?? 0
        let left = Int(leftText) ?? 0
        return made > reps || left > reps || made + left > reps
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Text(String(format: L("game.gate.outOf"), reps))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)

            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                entry(L("game.gate.howMany"), text: $madeText, field: .made, colour: Theme.primary)
                entry(L("game.gate.howManyLeft"), text: $leftText, field: .left, colour: Theme.error)
            }
            .padding(.horizontal, Theme.Spacing.edge)

            Group {
                if tooMany {
                    Label(String(format: L("game.gate.tooMany"), reps), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.error)
                } else if let missedRight {
                    Text(String(format: L("game.gate.restRight"), missedRight))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .multilineTextAlignment(.center)

            Spacer()

            Button {
                finish()
            } label: {
                Text(L("game.done"))
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(missedRight != nil ? Theme.primary : Theme.border))
            }
            .buttonStyle(.plain)
            .disabled(missedRight == nil)
            .padding(.horizontal, Theme.Spacing.edge)
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
        .onAppear { focused = .made }
    }

    private func entry(_ title: String, text: Binding<String>, field: Field, colour: Color) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .focused($focused, equals: field)
                .multilineTextAlignment(.center)
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(colour)
                .frame(maxWidth: .infinity)
                .frame(height: 84)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(
                    (Int(text.wrappedValue) ?? 0) > reps ? Theme.error : (focused == field ? colour : Theme.border),
                    lineWidth: 2
                ))
                .onTapGesture { focused = field }
        }
        .frame(maxWidth: .infinity)
    }

    private func finish() {
        guard let made = count(madeText), let left = count(leftText), let right = missedRight else { return }
        let session = GameSession(gameType: .gate)
        session.configSummary = configSummary
        session.attemptsTotal = reps
        session.madeTotal = made
        session.missedLeft = left
        session.missedRight = right
        session.score = reps > 0 ? Double(made) / Double(reps) * 100 : 0
        session.isComplete = true
        modelContext.insert(session)
        try? modelContext.save()
        onFinished(session)
    }
}
