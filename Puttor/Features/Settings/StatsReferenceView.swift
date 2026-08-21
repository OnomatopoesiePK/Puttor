//
//  StatsReferenceView.swift
//  Puttor
//
//  Explains the two numbers the app reports — strokes gained per hole, and
//  GSD per putt — and lists the tour baseline both are measured against.
//

import SwiftUI

struct StatsReferenceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                explanation
                formulaCard(
                    title: L("reference.sgTitle"),
                    formula: "SG = E(d₁) − n",
                    prose: L("reference.sgText"),
                    legend: L("reference.sgLegend"),
                    example: L("reference.sgExample")
                )
                formulaCard(
                    title: L("reference.gsdTitle"),
                    formula: "GSD = 1 − p   ·   GSD = −p",
                    prose: L("reference.gsdText"),
                    legend: L("reference.gsdLegend"),
                    example: L("reference.gsdExample")
                )
                baselineTable
                footer
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L("reference.title"))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(ThemeManager.shared.colorScheme)
    }

    private var explanation: some View {
        Text(L("reference.intro"))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 2)
    }

    /// Was its own settings block; it belongs with the numbers it explains.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("reference.version"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(L("settings.about.desc"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func formulaCard(title: String, formula: String, prose: String, legend: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.primary)

            Text(prose)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(formula)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(legend)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))

            VStack(alignment: .leading, spacing: 4) {
                Text(L("reference.example"))
                    .font(.system(size: 9, weight: .bold)).tracking(1.0)
                    .foregroundStyle(Theme.textMuted)
                Text(example)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    private var baselineTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("input.distanceLabel")).frame(width: 84, alignment: .leading)
                Text(L("chart.made")).frame(maxWidth: .infinity, alignment: .trailing)
                Text(L("reference.expectedPutts")).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .bold)).tracking(0.8)
            .foregroundStyle(Theme.textMuted)
            .padding(.vertical, 8)

            ForEach(Array(StrokesGained.tourBaseline.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text("\(formatted(row.distanceM)) m  ·  \(Int(UnitConverter.metresToFeet(row.distanceM).rounded())) ft")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 116, alignment: .leading)
                    Text("\(String(format: "%.1f", row.makeProbability * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(String(format: "%.3f", row.expectedPutts))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(row.expectedPutts > 2 ? Theme.accent : Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 6)

                if index < StrokesGained.tourBaseline.count - 1 {
                    Rectangle().fill(Theme.borderLight).frame(height: 1)
                }
            }

            Text(L("reference.tableNote"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    private func formatted(_ metres: Double) -> String {
        metres.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", metres)
            : String(format: "%.1f", metres)
    }
}

#Preview {
    NavigationStack { StatsReferenceView() }
}
