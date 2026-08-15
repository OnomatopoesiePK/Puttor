//
//  GameStatsView.swift
//  Puttor
//
//  Per-game history: all-time best next to the recent average, the last ten
//  rounds as a bar chart with the record highlighted, and tap-to-delete on any
//  round so a mistyped result can be taken back out.
//

import SwiftUI
import SwiftData

struct GameStatsView: View {
    let gameType: GameType

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameSession.date, order: .reverse) private var allSessions: [GameSession]

    @State private var sessionToDelete: GameSession?
    @State private var showResetConfirm = false
    @State private var playingGame: GameType?

    private let chartHeight: CGFloat = 110
    private let recentCount = 10

    private var history: [GameSession] { GameScoring.history(for: gameType, in: allSessions) }
    /// Newest first for the list, oldest first for the chart's left-to-right time axis.
    private var recent: [GameSession] { Array(history.prefix(recentCount)) }
    private var chartSessions: [GameSession] { recent.reversed() }
    private var best: GameSession? { GameScoring.bestSession(for: gameType, in: allSessions) }
    private var average: Double? { GameScoring.recentAverage(for: gameType, in: allSessions) }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                headerCard
                if history.isEmpty {
                    emptyState
                } else {
                    chartCard
                    roundsCard
                }
                playButton
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L(gameType.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .navigationDestination(item: $playingGame) { game in
            GameDestinationView(gameType: game) { playingGame = nil }
        }
        .confirmationDialog(
            L("game.stats.deleteRoundTitle"),
            isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L("onCourse.delete"), role: .destructive) {
                if let s = sessionToDelete { delete(s) }
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            if let s = sessionToDelete {
                Text("\(s.date.formatted(date: .abbreviated, time: .shortened)) · \(GameScoreFormat.text(s.score, for: gameType))")
            }
        }
        .confirmationDialog(L("game.stats.resetTitle"), isPresented: $showResetConfirm, titleVisibility: .visible) {
            if let best {
                Button(L("game.stats.deleteRecordOnly"), role: .destructive) { delete(best) }
            }
            Button(L("game.stats.deleteAll"), role: .destructive) { deleteAll() }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("game.stats.resetMessage"))
        }
        .preferredColorScheme(ThemeManager.shared.colorScheme)
    }

    // MARK: - Header: best + recent average

    private var headerCard: some View {
        HStack(spacing: Theme.Spacing.sm) {
            statBox(
                value: best.map { GameScoreFormat.text($0.score, for: gameType) } ?? "–",
                label: L("game.best"),
                color: Theme.primary,
                trailing: best != nil ? { showResetConfirm = true } : nil
            )
            statBox(
                value: average.map { GameScoreFormat.preciseText($0, for: gameType) } ?? "–",
                label: L("game.stats.avgLast5"),
                color: Theme.accent,
                trailing: nil
            )
        }
    }

    private func statBox(value: String, label: String, color: Color, trailing: (() -> Void)?) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(value).font(.system(size: 26, weight: .black)).foregroundStyle(color)
                if let trailing {
                    Button(action: trailing) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(label).font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Theme.textMuted)
            Text(L(gameType.scoreUnitKey)).font(.system(size: 9)).foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(spacing: 10) {
            Text(L("game.stats.lastRounds"))
                .font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            let maxScore = max(chartSessions.map(\.score).max() ?? 1, 0.0001)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(chartSessions) { session in
                    bar(session, maxScore: maxScore)
                }
            }
            .frame(height: chartHeight + 40, alignment: .bottom)

            Text(L("game.stats.tapToDelete"))
                .font(.system(size: 10)).foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    private func bar(_ session: GameSession, maxScore: Double) -> some View {
        let isBest = session.id == best?.id
        // Height is proportional to the raw score, so for stroke/cycle games a
        // taller bar means a worse round — the record is called out by colour
        // and the ★ instead of by height.
        let height = max(6, chartHeight * (session.score / maxScore))

        return Button {
            sessionToDelete = session
        } label: {
            VStack(spacing: 3) {
                Text(isBest ? "★" : " ")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Theme.primary)
                Text(GameScoreFormat.text(session.score, for: gameType))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isBest ? Theme.primary : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                RoundedRectangle(cornerRadius: 3)
                    .fill(isBest ? Theme.primary : Theme.surfaceElevated)
                    .frame(height: height)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(isBest ? Theme.primary : Theme.border, lineWidth: 1))
                Text(session.date.formatted(.dateTime.day().month(.twoDigits)))
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Round list

    private var roundsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, session in
                Button {
                    sessionToDelete = session
                } label: {
                    HStack(spacing: 10) {
                        Text(session.id == best?.id ? "★" : "\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(session.id == best?.id ? Theme.primary : Theme.textMuted)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                            if !session.configSummary.isEmpty {
                                Text(session.configSummary)
                                    .font(.system(size: 10)).foregroundStyle(Theme.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(GameScoreFormat.text(session.score, for: gameType))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(session.id == best?.id ? Theme.primary : Theme.text)
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.error)
                    }
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)

                if index < recent.count - 1 {
                    Rectangle().fill(Theme.borderLight).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(gameType.icon).font(.system(size: 40))
            Text(L("game.stats.noRounds")).font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var playButton: some View {
        Button {
            playingGame = gameType
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill").font(.system(size: 20, weight: .heavy))
                Text(L("game.stats.playAgain")).font(.system(size: 17, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.primary))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mutations

    private func delete(_ session: GameSession) {
        modelContext.delete(session)
        try? modelContext.save()
        sessionToDelete = nil
    }

    private func deleteAll() {
        for session in allSessions where session.gameType == gameType {
            modelContext.delete(session)
        }
        try? modelContext.save()
    }
}
