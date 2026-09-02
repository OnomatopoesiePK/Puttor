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
    /// Weeks in a row with practice, for the drills counted by turning up.
    var streakWeeks: Int = 0
    let action: () -> Void
    let onShowStats: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(action: action) {
                HStack(spacing: Theme.Spacing.md) {
                    Text(gameType.icon).font(.system(size: 34))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L(gameType.titleKey)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                        Text(L(gameType.categoryKey))
                            .font(.system(size: 11, weight: .bold)).tracking(0.8)
                            .foregroundStyle(Theme.textMuted)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Reads as a button: its own tinted panel with a chevron, so it is
            // clear the score opens something rather than just standing there.
            Button(action: onShowStats) {
                HStack(spacing: 6) {
                    VStack(spacing: 2) {
                        // A drill you either finish or don't has no score to
                        // beat; what it has is a run of weeks.
                        if gameType.isTrainingDrill {
                            StreakFlameView(weeks: streakWeeks)
                        } else if let bestSession {
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
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Theme.primary.opacity(0.7))
                }
                .frame(minWidth: 64)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.primary.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.primary.opacity(0.45), lineWidth: 1))
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
