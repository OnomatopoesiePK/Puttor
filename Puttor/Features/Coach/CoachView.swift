//
//  CoachView.swift
//  Puttor
//
//  What the numbers add up to, in sentences, and what to go and practise
//  because of them. Everything here is read from rounds already recorded; the
//  drills it points at are the ones in the Games tab.
//

import SwiftUI
import SwiftData

struct CoachView: View {
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \GameSession.date, order: .reverse) private var sessions: [GameSession]
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"

    @State private var report = CoachReport(hasEnoughData: false, roundCount: 0, puttCount: 0)
    @State private var drillToPlay: GameType?

    private var useFeet: Bool { unitsPref == "imperial" }
    private var completeRounds: [Round] { allRounds.filter { $0.isComplete } }
    /// The recent stretch rather than a career: advice about last season is
    /// advice about somebody else.
    private var consideredRounds: [Round] { Array(completeRounds.prefix(10)) }
    /// Conditions are read from further back: how you putt in the rain is a
    /// trait rather than a form, and rain is rare enough that ten rounds
    /// rarely hold enough of it.
    private var conditionRounds: [Round] { Array(completeRounds.prefix(30)) }

    private var reportKey: Int {
        conditionRounds.reduce(sessions.count) { $0 &+ $1.putts.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if report.hasEnoughData {
                        summaryCard
                        if !report.metrics.isEmpty { metricsCard }
                        if report.practice.sessions > 0 { practiceCard }
                        if !report.findings.isEmpty { findingsCard }
                        if !report.conditions.isEmpty { conditionsCard }
                    } else {
                        notEnoughYetCard
                    }

                    recommendationsCard
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                ScreenTitle(text: L("tab.coach"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .screenHeaderPadding()
                    .background(Theme.background)
            }
            .navigationBarHidden(true)
            .task(id: reportKey) {
                // Per round, then merged. Pooling every putt into one call
                // would put hole 7 of ten different rounds on one hole and
                // report a score nobody shot.
                let perRound = consideredRounds.map { RoundStats.compute(putts: $0.putts, useFeet: useFeet) }
                report = CoachAdvisor.report(
                    rounds: consideredRounds,
                    stats: RoundStats.merge(perRound, useFeet: useFeet),
                    putts: consideredRounds.flatMap { $0.putts },
                    sessions: sessions,
                    conditionRounds: conditionRounds
                )
            }
            .navigationDestination(item: $drillToPlay) { drill in
                GameDestinationView(gameType: drill) { drillToPlay = nil }
            }
        }
    }

    // MARK: - Cards

    private var summaryCard: some View {
        card {
            Text(String(format: L("coach.summary"), report.roundCount, report.puttCount))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let weakest = report.weakestBracketLabel {
                Text(String(format: L("coach.weakestDistance"), weakest))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let trend = report.trend {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: trendIcon(trend))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(trendColour(trend))
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(format: L(trend.key), abs(report.trendDelta), report.trendBaseline))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(trendColour(trend))
                            .fixedSize(horizontal: false, vertical: true)
                        // Say what was compared with what, or the arrow is
                        // just a mood.
                        Text(String(format: L("coach.trend.method"), report.trendRecentRounds, report.trendWindowRounds))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var metricsCard: some View {
        card {
            Text(L("coach.numbers"))
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textMuted)
            Text(L("coach.numbers.source"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 2), spacing: Theme.Spacing.sm) {
                ForEach(report.metrics) { metric in
                    VStack(spacing: 2) {
                        Text(metric.value)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(colour(for: metric.tone))
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(L(metric.labelKey))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    /// The drills, counted on their own. Practice under no pressure and a
    /// scorecard are different things, and averaging them would say neither.
    private var practiceCard: some View {
        card {
            Text(L("coach.practice"))
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            HStack(spacing: Theme.Spacing.sm) {
                practiceStat("\(report.practice.sessions)", L("coach.practice.sessions"))
                practiceStat("\(report.practice.attempts)", L("coach.practice.putts"))
                practiceStat("\(Int(report.practice.makePercent.rounded()))%", L("chart.made"))
                if let pcg = report.practice.pcgPerAttempt {
                    practiceStat("\(pcg > 0 ? "+" : "")\(String(format: "%.2f", pcg))", L("coach.practice.pcgPerPutt"))
                }
            }

            Text(L("coach.practice.source"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func practiceStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }

    private var findingsCard: some View {
        card {
            Text(L("coach.whatIsHappening"))
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            ForEach(report.findings) { finding in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 2)
                    Text(text(for: finding))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// The conditions card: differences that belong to the day rather than to
    /// the player, and are therefore worth knowing before the round instead of
    /// after it.
    private var conditionsCard: some View {
        card {
            Text(L("coach.conditions"))
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            ForEach(report.conditions) { finding in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "cloud.sun")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.warning)
                        .padding(.top, 2)
                    Text(text(for: finding))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(L("coach.conditions.source"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notEnoughYetCard: some View {
        card {
            Text(L("coach.notEnough.title"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(String(format: L("coach.notEnough.body"), CoachAdvisor.minimumRounds, CoachAdvisor.minimumPutts, report.roundCount, report.puttCount))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recommendationsCard: some View {
        card {
            Text(L(report.hasEnoughData ? "coach.workOnThis" : "coach.startWith"))
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            ForEach(report.recommendations) { recommendation in
                Button {
                    drillToPlay = recommendation.gameType
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Text(recommendation.gameType.icon).font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L(recommendation.gameType.titleKey))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text(reasonText(recommendation))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        VStack(spacing: 2) {
                            Text("\(recommendation.targetSessions)×")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(Theme.primary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    .padding(Theme.Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Text

    private func text(for finding: CoachFinding) -> String {
        guard !finding.numbers.isEmpty else { return L(finding.key) }
        return String(format: L(finding.key), arguments: finding.numbers.map { $0 as CVarArg })
    }

    private func text(for finding: SplitFinding) -> String {
        String(
            format: L(finding.key),
            L(finding.conditionKey),
            finding.highText,
            L(finding.otherKey),
            finding.lowText
        )
    }

    private func reasonText(_ recommendation: CoachRecommendation) -> String {
        if let distance = recommendation.distanceM {
            return String(format: L(recommendation.reasonKey), UnitConverter.formatDistance(distance, useFeet: useFeet))
        }
        if let idleDays = recommendation.idleDays {
            return String(format: L(recommendation.reasonKey), idleDays)
        }
        return L(recommendation.reasonKey)
    }

    private func trendIcon(_ trend: CoachTrend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .slipping: return "arrow.down.right"
        case .steadyStrong: return "checkmark.circle"
        case .steadySolid: return "equal"
        case .steadyWeak: return "exclamationmark.circle"
        }
    }

    private func trendColour(_ trend: CoachTrend) -> Color {
        switch trend {
        case .improving, .steadyStrong: return Theme.primary
        case .slipping, .steadyWeak: return Theme.error
        case .steadySolid: return Theme.textSecondary
        }
    }

    private func colour(for tone: CoachMetric.Tone) -> Color {
        switch tone {
        case .good: return Theme.primary
        case .neutral: return Theme.text
        case .bad: return Theme.error
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }
}
