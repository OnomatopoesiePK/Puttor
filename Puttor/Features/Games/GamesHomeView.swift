//
//  GamesHomeView.swift
//  Puttor
//
//  Tab 3 root: putting practice games & drills, each with its own high score.
//

import SwiftUI
import SwiftData

struct GamesHomeView: View {
    @Query(sort: \GameSession.date, order: .reverse) private var allSessions: [GameSession]
    @State private var activeGame: GameType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(GameType.allCases) { gameType in
                        GameCard(
                            gameType: gameType,
                            bestSession: GameScoring.bestSession(for: gameType, in: allSessions)
                        ) {
                            activeGame = gameType
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                Text(L("games.title"))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, 4)
                    .background(Theme.background)
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $activeGame) { gameType in
                destination(for: gameType)
            }
        }
    }

    @ViewBuilder
    private func destination(for gameType: GameType) -> some View {
        let onDone = { activeGame = nil }
        switch gameType {
        case .gate: GateDrillView(onDone: onDone)
        case .clock: ClockDrillView(onDone: onDone)
        case .ninePutt: NinePuttDrillView(onDone: onDone)
        case .routine: RoutineDrillView(onDone: onDone)
        case .aroundTheWorld: AroundTheWorldView(onDone: onDone)
        }
    }
}
