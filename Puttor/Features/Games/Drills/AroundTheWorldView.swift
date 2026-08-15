//
//  AroundTheWorldView.swift
//  Puttor
//
//  Around the World / Par 18: build a course of 9 or 18 different putts
//  around the green and play it like a mini round — count strokes per
//  "hole" and sum them at the end. Lower total is better.
//

import SwiftUI
import SwiftData

struct AroundTheWorldView: View {
    var onDone: () -> Void
    @Query(sort: \GameSession.date, order: .reverse) private var allSessions: [GameSession]

    @State private var holeCount: Int = 9
    @State private var playing = false
    @State private var finishedSession: GameSession?

    private var configSummary: String { "\(holeCount) \(L("summary.holes"))" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(L(GameType.aroundTheWorld.goalKey))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)

                configCard {
                    Text(L("game.aroundTheWorld.holeCount")).font(.caption).foregroundStyle(Theme.textMuted)
                    Picker("", selection: $holeCount) {
                        Text("9").tag(9)
                        Text("18").tag(18)
                    }
                    .pickerStyle(.segmented)
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
        .navigationTitle(L(GameType.aroundTheWorld.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: .aroundTheWorld)
            }
        }
        .navigationDestination(isPresented: $playing) {
            AroundTheWorldPlayView(totalHoles: holeCount, configSummary: configSummary) { session in
                finishedSession = session
            }
        }
        .navigationDestination(item: $finishedSession) { session in
            GameResultView(
                gameType: .aroundTheWorld,
                session: session,
                isNewBest: GameScoring.isNewBest(session, among: allSessions),
                onDone: onDone
            ) {
                bestWorstBreakdown(session)
            }
        }
    }

    @ViewBuilder
    private func bestWorstBreakdown(_ session: GameSession) -> some View {
        if let best = session.attempts.min(by: { $0.strokes < $1.strokes }),
           let worst = session.attempts.max(by: { $0.strokes < $1.strokes }) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(spacing: 2) {
                    Text("\(best.strokes)").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.primary)
                    Text("\(L("game.aroundTheWorld.best")) (\(best.label))").font(.system(size: 9)).foregroundStyle(Theme.textMuted)
                }
                VStack(spacing: 2) {
                    Text("\(worst.strokes)").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.error)
                    Text("\(L("game.aroundTheWorld.worst")) (\(worst.label))").font(.system(size: 9)).foregroundStyle(Theme.textMuted)
                }
            }
        }
    }

    private func configCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}

private struct AroundTheWorldPlayView: View {
    let totalHoles: Int
    let configSummary: String
    var onFinished: (GameSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var hole = 1
    @State private var strokesSoFar = 0
    @State private var log: [(hole: Int, strokes: Int)] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            VStack(spacing: 12) {
                Text("\(L("summary.holeAbbr")) \(hole)").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.textSecondary)
                Text("\(strokesSoFar + 1)")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(Theme.primary)
                Text(L("game.aroundTheWorld.strokeCount")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            HStack(spacing: 14) {
                Button { strokesSoFar += 1 } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 26, weight: .heavy))
                        Text(L("game.aroundTheWorld.missed")).font(.system(size: 15, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.error))
                }
                .buttonStyle(.plain)

                Button { holed() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy))
                        Text(L("result.holed")).font(.system(size: 15, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L(GameType.aroundTheWorld.titleKey)).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.text)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L("game.giveUp")) { dismiss() }
                    .foregroundStyle(Theme.textSecondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: .aroundTheWorld)
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("\(L("summary.holeAbbr")) \(hole) / \(totalHoles)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textMuted)
            ProgressView(value: Double(hole - 1), total: Double(totalHoles))
                .tint(Theme.primary)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, Theme.Spacing.md)
    }

    private func holed() {
        let strokes = strokesSoFar + 1
        log.append((hole, strokes))
        if hole >= totalHoles {
            finish()
        } else {
            hole += 1
            strokesSoFar = 0
        }
    }

    private func finish() {
        let session = GameSession(gameType: .aroundTheWorld)
        session.configSummary = configSummary
        session.attemptsTotal = totalHoles
        session.madeTotal = log.filter { $0.strokes == 1 }.count
        session.score = Double(log.reduce(0) { $0 + $1.strokes })
        session.isComplete = true
        modelContext.insert(session)
        for (i, entry) in log.enumerated() {
            let attempt = GameAttempt(
                groupIndex: 0, index: i, label: "\(L("summary.holeAbbr")) \(entry.hole)",
                success: entry.strokes == 1, strokes: entry.strokes
            )
            attempt.session = session
            session.attempts.append(attempt)
            modelContext.insert(attempt)
        }
        try? modelContext.save()
        onFinished(session)
    }
}
