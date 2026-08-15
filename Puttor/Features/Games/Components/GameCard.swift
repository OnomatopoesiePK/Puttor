//
//  GameCard.swift
//  Puttor
//
//  Home-screen tile for a single drill: icon, name, best score, info button.
//

import SwiftUI

struct GameCard: View {
    let gameType: GameType
    let bestSession: GameSession?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Text(gameType.icon).font(.system(size: 34))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L(gameType.titleKey)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                    Text(L(gameType.goalKey)).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(2)
                }

                Spacer()

                VStack(spacing: 2) {
                    if let bestSession {
                        Text(scoreText(bestSession))
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Theme.primary)
                        Text(L("game.best")).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textMuted)
                    } else {
                        Text("–").font(.system(size: 18, weight: .black)).foregroundStyle(Theme.textMuted)
                        Text(L("game.noScoreYet")).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textMuted)
                    }
                }

                GameInfoButton(gameType: gameType)
            }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func scoreText(_ session: GameSession) -> String {
        switch gameType.scoreUnitKey {
        case "game.unit.cycles":
            return String(format: "%.0f", session.score)
        case "game.unit.strokes":
            return String(format: "%.0f", session.score)
        default:
            return "\(Int(session.score.rounded()))%"
        }
    }
}
