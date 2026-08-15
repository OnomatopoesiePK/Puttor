//
//  GameResultView.swift
//  Puttor
//
//  Shared result screen shown after any drill session finishes.
//

import SwiftUI

struct GameResultView<Breakdown: View>: View {
    let gameType: GameType
    let session: GameSession
    let isNewBest: Bool
    var onDone: () -> Void
    @ViewBuilder var breakdown: () -> Breakdown

    private var scoreText: String {
        switch gameType.scoreUnitKey {
        case "game.unit.cycles", "game.unit.strokes":
            return String(format: "%.0f", session.score)
        default:
            return "\(Int(session.score.rounded()))%"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text(gameType.icon).font(.system(size: 56))
                Text(L(gameType.titleKey)).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.text)

                if isNewBest {
                    Text("🏆 \(L("game.newBest"))")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accent.opacity(0.15)))
                        .overlay(Capsule().stroke(Theme.accent, lineWidth: 1.5))
                }

                VStack(spacing: 4) {
                    Text(scoreText).font(.system(size: 56, weight: .black)).foregroundStyle(Theme.primary)
                    Text(L(gameType.scoreUnitKey)).font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    statBox(L("game.attempts"), "\(session.attemptsTotal)")
                    statBox(L("game.made"), "\(session.madeTotal)")
                }

                if !session.configSummary.isEmpty {
                    Text(session.configSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }

                breakdown()

                Button(action: onDone) {
                    Text(L("game.done"))
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
        .navigationBarBackButtonHidden(true)
    }

    private func statBox(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.text)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}

extension GameResultView where Breakdown == EmptyView {
    init(gameType: GameType, session: GameSession, isNewBest: Bool, onDone: @escaping () -> Void) {
        self.init(gameType: gameType, session: session, isNewBest: isNewBest, onDone: onDone, breakdown: { EmptyView() })
    }
}
