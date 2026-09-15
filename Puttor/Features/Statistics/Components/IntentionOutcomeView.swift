//
//  IntentionOutcomeView.swift
//  Puttor
//
//  Played as meant against dropped, then one card per option of the chosen
//  part of the intention: how often it dropped, how often it came off and
//  what that did for the make rate, which way the misses went and how far
//  they finished.
//

import SwiftUI

struct IntentionOutcomeView: View {
    let putts: [Putt]
    var useFeet = false
    @AppStorage("stats.intentionPart") private var partRaw = IntentionPart.goal.rawValue

    var body: some View {
        let parts = IntentionOutcome.parts(in: putts)
        let part = parts.first { $0.rawValue == partRaw } ?? parts.first
        let execution = IntentionExecution(putts)

        VStack(spacing: Theme.Spacing.sm) {
            if execution.total > 0 {
                matrix(execution)
            }

            if parts.count > 1 {
                Picker("", selection: Binding(get: { part?.rawValue ?? partRaw }, set: { partRaw = $0 })) {
                    ForEach(parts) { option in
                        Text(L(option.shortTitleKey)).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let part {
                ForEach(IntentionOutcome.outcomes(in: putts, by: part, useFeet: useFeet)) { outcome in
                    card(outcome, part: part)
                }
            }
        }
    }

    // MARK: - Played as meant × dropped

    private func matrix(_ execution: IntentionExecution) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    header(L("intention.matrix.made"))
                    header(L("intention.matrix.missed"))
                }
                GridRow {
                    rowLabel(L("intention.executed"), icon: "checkmark", tint: Theme.primary)
                    cell(execution.executedMade, of: execution, tint: Theme.primary)
                    cell(execution.executedMissed, of: execution, tint: Theme.textSecondary)
                }
                GridRow {
                    rowLabel(L("intention.notExecuted"), icon: "xmark", tint: Theme.error)
                    cell(execution.notExecutedMade, of: execution, tint: Theme.accent)
                    cell(execution.notExecutedMissed, of: execution, tint: Theme.error)
                }
            }
            if let share = execution.executedMissPercent, execution.executedMissed > 0 {
                line(String(format: L("intention.matrix.note"), percentText(share)))
            }
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)
    }

    private func rowLabel(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .heavy)).foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 96, alignment: .leading)
    }

    private func cell(_ count: Int, of execution: IntentionExecution, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text("\(count)")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tint)
            Text(percentText(execution.percent(count)))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(tint.opacity(0.1)))
    }

    // MARK: - One option

    private func card(_ outcome: IntentionOutcome, part: IntentionPart) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: part.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text(L(outcome.labelKey))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 0)
                Text(String(format: L("intention.putts"), outcome.putts))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }

            HStack(spacing: Theme.Spacing.sm) {
                stat(percentText(outcome.makePercent), L("intention.stat.made"), "\(outcome.made)/\(outcome.putts)")
                stat(percentText(outcome.executedPercent), L("intention.stat.executed"), "\(outcome.executed)/\(outcome.answered)")
                stat(
                    outcome.averageLeave.map { UnitConverter.formatDistance($0, useFeet: useFeet) } ?? "—",
                    L("intention.stat.leave"),
                    String(format: L("intention.misses"), outcome.misses)
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                if outcome.answered > 0 {
                    line(String(
                        format: L("intention.madeByExecution"),
                        percentText(outcome.makePercentWhenExecuted),
                        percentText(outcome.makePercentWhenNot)
                    ))
                }
                if outcome.misses > 0 {
                    line(String(
                        format: L("intention.missLength"),
                        percentText(outcome.missPercent(outcome.short)),
                        percentText(outcome.missPercent(outcome.long))
                    ))
                    line(String(
                        format: L("intention.missSide"),
                        percentText(outcome.missPercent(outcome.left)),
                        percentText(outcome.missPercent(outcome.right))
                    ))
                }
                if let highSide = outcome.highSidePercent {
                    line(String(format: L("intention.proSide"), percentText(highSide)))
                }
                if part == .goal, outcome.id == PuttGoal.lag.rawValue, let inCircle = outcome.inCirclePercent {
                    line(String(
                        format: L("intention.inCircle"),
                        UnitConverter.formatDistance(IntentionOutcome.circle(useFeet: useFeet), useFeet: useFeet),
                        percentText(inCircle)
                    ))
                }
                if part == .goal, outcome.id == PuttGoal.position.rawValue, let uphill = outcome.uphillLeavePercent {
                    line(String(format: L("intention.uphillLeave"), percentText(uphill)))
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
    }

    private func stat(_ value: String, _ label: String, _ detail: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.surface))
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func percentText(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))%" } ?? "—"
    }
}
