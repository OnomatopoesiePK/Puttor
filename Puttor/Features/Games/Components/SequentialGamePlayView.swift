//
//  SequentialGamePlayView.swift
//  Puttor
//
//  Generic engine for any drill that is "a pre-built ordered list of labeled
//  attempts, mark each made/missed, tally a % score at the end". Powers the
//  Gate, Clock, Speed (ladder & circle) and Routine drills — each just builds
//  a different `plan` at setup time.
//

import SwiftUI
import SwiftData

struct GamePlanItem: Identifiable {
    let id = UUID()
    var groupIndex: Int = 0
    var label: String
    var distanceM: Double = 0
    var breakPct: Double? = nil
}

struct SequentialGamePlayView: View {
    let gameType: GameType
    let plan: [GamePlanItem]
    let configSummary: String
    var useFeet: Bool = false
    /// Override the default make% score formula (e.g. not needed for these games today, but kept flexible).
    var scoreOverride: ((_ made: Int, _ total: Int) -> Double)? = nil
    var onFinished: (GameSession) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var index = 0
    @State private var results: [(item: GamePlanItem, success: Bool)] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            currentItemCard
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
                Text(L(gameType.titleKey)).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.text)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: gameType)
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("\(L("game.attempt")) \(index + 1) / \(plan.count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textMuted)
            ProgressView(value: Double(index), total: Double(plan.count))
                .tint(Theme.primary)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, Theme.Spacing.md)
    }

    private var currentItemCard: some View {
        let item = plan[index]
        return VStack(spacing: 10) {
            Text(item.label)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            if item.distanceM > 0 {
                Text(UnitConverter.formatDistance(item.distanceM, useFeet: useFeet))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            if let breakPct = item.breakPct, breakPct != 0 {
                Text("\(breakPct > 0 ? "L→R" : "R→L") \(String(format: "%.0f", abs(breakPct)))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func mark(_ success: Bool) {
        results.append((plan[index], success))
        if index + 1 < plan.count {
            index += 1
        } else {
            finish()
        }
    }

    private func finish() {
        let session = GameSession(gameType: gameType)
        session.configSummary = configSummary
        session.attemptsTotal = results.count
        session.madeTotal = results.filter { $0.success }.count
        session.score = scoreOverride?(session.madeTotal, session.attemptsTotal)
            ?? (session.attemptsTotal > 0 ? Double(session.madeTotal) / Double(session.attemptsTotal) * 100 : 0)
        session.isComplete = true
        modelContext.insert(session)
        for (i, r) in results.enumerated() {
            let attempt = GameAttempt(
                groupIndex: r.item.groupIndex, index: i, label: r.item.label,
                distanceM: r.item.distanceM, breakPct: r.item.breakPct ?? 0, success: r.success
            )
            attempt.session = session
            session.attempts.append(attempt)
            modelContext.insert(attempt)
        }
        try? modelContext.save()
        onFinished(session)
    }
}
