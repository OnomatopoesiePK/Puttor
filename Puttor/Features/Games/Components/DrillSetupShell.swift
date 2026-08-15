//
//  DrillSetupShell.swift
//  Puttor
//
//  Shared chrome for every "% score" drill's setup screen: goal blurb, info
//  button, custom config controls, Start button, and the Play -> Result
//  navigation plumbing. Concrete drills just supply config UI + a plan.
//

import SwiftUI
import SwiftData

struct DrillSetupShell<ConfigContent: View, Breakdown: View>: View {
    let gameType: GameType
    var onDone: () -> Void
    let plan: [GamePlanItem]
    let configSummary: String
    var useFeet: Bool = false
    var canStart: Bool = true
    @ViewBuilder var configContent: () -> ConfigContent
    @ViewBuilder var breakdown: (GameSession) -> Breakdown

    @Query(sort: \GameSession.date, order: .reverse) private var allSessions: [GameSession]

    @State private var startPlay = false
    @State private var finishedSession: GameSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(L(gameType.goalKey))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)

                configContent()

                startButton
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L(gameType.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                GameInfoButton(gameType: gameType)
            }
        }
        .navigationDestination(isPresented: $startPlay) {
            SequentialGamePlayView(gameType: gameType, plan: plan, configSummary: configSummary, useFeet: useFeet) { session in
                finishedSession = session
            }
        }
        .navigationDestination(item: $finishedSession) { session in
            GameResultView(
                gameType: gameType,
                session: session,
                isNewBest: GameScoring.isNewBest(session, among: allSessions),
                onDone: onDone,
                breakdown: { breakdown(session) }
            )
        }
    }

    private var startButton: some View {
        Button {
            startPlay = true
        } label: {
            Text(L("game.start"))
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(canStart ? Theme.primary : Theme.border))
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .padding(.top, Theme.Spacing.md)
    }
}

extension DrillSetupShell where Breakdown == EmptyView {
    init(
        gameType: GameType,
        onDone: @escaping () -> Void,
        plan: [GamePlanItem],
        configSummary: String,
        useFeet: Bool = false,
        canStart: Bool = true,
        @ViewBuilder configContent: @escaping () -> ConfigContent
    ) {
        self.init(
            gameType: gameType, onDone: onDone, plan: plan, configSummary: configSummary,
            useFeet: useFeet, canStart: canStart, configContent: configContent,
            breakdown: { _ in EmptyView() }
        )
    }
}
