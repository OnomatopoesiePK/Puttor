//
//  DrillBenchmarkCard.swift
//  Puttor
//
//  A drill's percentage put where it belongs: next to the tour's rate from the
//  same distance, and converted into strokes over eighteen holes.
//

import SwiftUI

struct DrillBenchmarkCard: View {
    let benchmark: DrillBenchmark
    var useFeet: Bool

    private var gained: Bool { benchmark.strokesPerRound >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L("game.benchmark"))
                    .font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                Spacer(minLength: 0)
                FieldInfoButton(titleKey: L("game.benchmark"), textKey: "game.benchmark.info")
            }

            HStack(spacing: Theme.Spacing.sm) {
                box(
                    value: "\(Int(benchmark.yourMakePct.rounded()))%",
                    label: L("game.benchmark.you"),
                    colour: gained ? Theme.primary : Theme.error
                )
                box(
                    value: "\(Int(benchmark.tourMakePct.rounded()))%",
                    label: String(
                        format: L("game.benchmark.tourAt"),
                        UnitConverter.formatDistance(benchmark.distanceM, useFeet: useFeet)
                    ),
                    colour: Theme.text
                )
                VStack(spacing: 2) {
                    MetricValue(value: benchmark.strokesPerRound, metric: .sg, size: 20)
                    Text(L("game.benchmark.perRound"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 58)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
            }

            Text(String(
                format: L("game.benchmark.basis"),
                benchmark.puttsPerRound,
                UnitConverter.formatDistance(benchmark.distanceM, useFeet: useFeet)
            ))
            .font(.system(size: 11))
            .foregroundStyle(Theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    private func box(value: String, label: String, colour: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(colour)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
    }
}
