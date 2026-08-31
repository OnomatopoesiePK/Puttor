//
//  GamesHomeView.swift
//  Puttor
//
//  Tab root: putting practice games & drills, each with its own high score.
//

import SwiftUI
import SwiftData

/// A single destination type for the stack, so playing a game and viewing its
/// statistics don't collide on two `navigationDestination(item:)` of the same
/// underlying GameType.
private enum GameRoute: Hashable, Identifiable {
    case play(GameType)
    case stats(GameType)

    var id: String {
        switch self {
        case .play(let g): return "play-\(g.rawValue)"
        case .stats(let g): return "stats-\(g.rawValue)"
        }
    }
}

struct GamesHomeView: View {
    @Query(sort: \GameSession.date, order: .reverse) private var allSessions: [GameSession]
    @State private var route: GameRoute?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(GameType.allCases) { gameType in
                        GameCard(
                            gameType: gameType,
                            bestSession: GameScoring.bestSession(for: gameType, in: allSessions),
                            recentAverage: GameScoring.recentAverage(for: gameType, in: allSessions),
                            action: { route = .play(gameType) },
                            onShowStats: { route = .stats(gameType) }
                        )
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                ScreenTitle(text: L("games.title"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, 4)
                    .background(Theme.background)
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $route) { route in
                switch route {
                case .play(let gameType):
                    GameDestinationView(gameType: gameType) { self.route = nil }
                case .stats(let gameType):
                    GameStatsView(gameType: gameType)
                }
            }
        }
    }
}
