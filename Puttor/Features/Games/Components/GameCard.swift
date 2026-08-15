//
//  GameCard.swift
//  Puttor
//
//  Home-screen tile for a single drill: icon, name, best score + recent
//  average, info button.
//
//  The three zones are siblings rather than nested buttons: tapping the body
//  starts the drill, tapping the score opens that game's statistics, and the
//  info button explains the rules.
//

import SwiftUI

struct GameCard: View {
    let gameType: GameType
    let bestSession: GameSession?
    let recentAverage: Double?
    let action: () -> Void
    let onShowStats: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(action: action) {
                HStack(spacing: Theme.Spacing.md) {
                    Text(gameType.icon).font(.system(size: 34))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L(gameType.titleKey)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                        Text(L(gameType.goalKey)).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onShowStats) {
                VStack(spacing: 2) {
                    if let bestSession {
                        Text(GameScoreFormat.text(bestSession.score, for: gameType))
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Theme.primary)
                        Text(L("game.best")).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textMuted)
                        if let recentAverage {
                            Text("⌀ \(GameScoreFormat.preciseText(recentAverage, for: gameType))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                    } else {
                        Text("–").font(.system(size: 18, weight: .black)).foregroundStyle(Theme.textMuted)
                        Text(L("game.noScoreYet")).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textMuted)
                    }
                }
                .frame(minWidth: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            GameInfoButton(gameType: gameType)
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }
}
