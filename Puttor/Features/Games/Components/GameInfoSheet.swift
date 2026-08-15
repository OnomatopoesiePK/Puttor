//
//  GameInfoSheet.swift
//  Puttor
//
//  Info (ⓘ) button + explanation sheet, shown in the top corner of every
//  drill's setup/play screen.
//

import SwiftUI

struct GameInfoButton: View {
    let gameType: GameType
    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.primary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showInfo) {
            GameInfoSheet(gameType: gameType)
        }
    }
}

struct GameInfoSheet: View {
    let gameType: GameType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(gameType.icon).font(.system(size: 48))
                    Text(L(gameType.titleKey)).font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.text)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("game.info.goal")).font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(Theme.primary)
                        Text(L(gameType.goalKey)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("game.info.howTo")).font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(Theme.primary)
                        Text(L(gameType.explanationKey)).font(.system(size: 15)).foregroundStyle(Theme.textSecondary).lineSpacing(5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common.done")) { dismiss() }
                        .foregroundStyle(Theme.primary)
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(ThemeManager.shared.colorScheme)
    }
}
