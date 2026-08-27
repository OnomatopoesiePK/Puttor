//
//  StatsReferenceView.swift
//  Puttor
//
//  Explains the two numbers the app reports — strokes gained per hole, and
//  PCG per putt — the curves they are read off, and the tour data behind them.
//  Each part folds away like the sections on the statistics tab.
//

import SwiftUI

struct StatsReferenceView: View {
    private static let broadiePaperURL = URL(string: "https://www.columbia.edu/~mnb2/broadie/Assets/putting_strokes_gained_20110113.pdf")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                explanation

                CollapsibleStatSection(title: L("reference.sgTitle"), storageKey: "referenceSG") {
                    formulaBody(
                        formula: "SG = E(d₁) − n",
                        prose: L("reference.sgText"),
                        legend: L("reference.sgLegend"),
                        example: L("reference.sgExample")
                    )
                }

                CollapsibleStatSection(title: L("reference.pcgTitle"), storageKey: "referencePCG") {
                    formulaBody(
                        formula: "PCG = 1 − p   ·   PCG = −p",
                        prose: L("reference.pcgText"),
                        legend: L("reference.pcgLegend"),
                        example: L("reference.pcgExample")
                    )
                }

                // Reference material rather than reading matter, so both start
                // folded away.
                CollapsibleStatSection(title: L("reference.curvesTitle"), storageKey: "referenceCurves", defaultExpanded: false) {
                    curvesBody
                }

                CollapsibleStatSection(title: L("reference.tableTitle"), storageKey: "referenceTable", defaultExpanded: false) {
                    baselineTable
                }

                source
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
    }

    // MARK: - Formulas

    private func formulaBody(formula: String, prose: String, legend: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
    }

    /// The two fitted curves the whole table is read off. Written out because
    /// "calibrated against Tour figures" is a claim, and this is the claim in
    /// full.
    private var curvesBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("reference.curvesText"))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            curve(
                label: L("reference.curvesMake"),
                formula: "p(d) = 1 / (1 + e^−f(x))",
                polynomial: "f(x) = 0.017441x⁵ − 0.128716x⁴ + 0.206577x³ + 0.520123x² − 3.449886x + 2.664622"
            )
            curve(
                label: L("reference.curvesExpected"),
                formula: "E(d) = 1 + e^g(x)",
                polynomial: "g(x) = 0.011685x⁵ − 0.166096x⁴ + 0.942073x³ − 2.665428x² + 4.064010x − 2.785208"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func curve(label: String, formula: String, polynomial: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold)).tracking(1.0)
                .foregroundStyle(Theme.textMuted)
            Text(formula)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(polynomial)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
    }

    // MARK: - Table

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
    }

    // MARK: - Source

    /// What all of it rests on, and where to go and read it.
    private var source: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("reference.sourceTitle"))
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            Text(L("reference.sourceText"))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: Self.broadiePaperURL) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L("reference.sourceLink"))
                        .font(.system(size: 13, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Theme.primary)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.primary.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.primary.opacity(0.35), lineWidth: 1))
            }

            Text(L("reference.version"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
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
