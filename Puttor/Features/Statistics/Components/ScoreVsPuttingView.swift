//
//  ScoreVsPuttingView.swift
//  Puttor
//
//  Draws each round twice — as it was scored, and as it would have scored with
//  the putting result taken back out — so the gap between the two lines is the
//  putter's doing, and the spread of each line shows which half of the game
//  moves your scores around.
//

import SwiftUI

struct ScoreVsPuttingView: View {
    let analysis: ScorePuttingAnalysis

    private let chartHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 12) {
            chart
            legend
            summaryBoxes
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Canvas { context, size in
            let rounds = analysis.rounds
            guard !rounds.isEmpty else { return }

            let playedMean = analysis.avgScore
            let playedSD = analysis.sdScore
            let proMean = analysis.avgScoreWithoutPutting
            let proSD = analysis.sdScoreWithoutPutting

            // The bands have to fit in the picture along with the markers.
            let values: [Double] = rounds.flatMap { [$0.score, $0.scoreWithoutPutting] }
                + [0, playedMean - playedSD, playedMean + playedSD, proMean - proSD, proMean + proSD]
            let rawMin = values.min() ?? 0
            let rawMax = values.max() ?? 0
            // A flat series would divide by zero; give it a stroke of room.
            let padding = max(1.0, (rawMax - rawMin) * 0.15)
            let low = rawMin - padding
            let high = rawMax + padding

            // Left gutter carries the scale; the plot starts after it.
            let gutter: CGFloat = 30
            let inset: CGFloat = 12
            let plotLeft = gutter
            let plotRight = size.width - 4
            let plotWidth = plotRight - plotLeft - inset * 2
            let step = rounds.count > 1 ? plotWidth / CGFloat(rounds.count - 1) : 0

            func x(_ index: Int) -> CGFloat {
                rounds.count > 1 ? plotLeft + inset + CGFloat(index) * step : (plotLeft + plotRight) / 2
            }
            // Over par upwards, under par downwards — the way a scorecard reads.
            func y(_ value: Double) -> CGFloat {
                let t = (value - low) / (high - low)
                return size.height - CGFloat(t) * size.height
            }

            // Scale: round numbers either side of par, as few as read cleanly.
            for tick in ScorePuttingAnalysis.scaleTicks(low: low, high: high) {
                let ty = y(tick)
                let isPar = abs(tick) < 0.0001

                var line = Path()
                line.move(to: CGPoint(x: plotLeft, y: ty))
                line.addLine(to: CGPoint(x: plotRight, y: ty))
                if isPar {
                    context.stroke(line, with: .color(Theme.textMuted.opacity(0.6)),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                } else {
                    context.stroke(line, with: .color(Theme.borderLight), lineWidth: 1)
                }

                context.draw(
                    Text(isPar ? "PAR" : tickLabel(tick))
                        .font(.system(size: 8, weight: isPar ? .bold : .semibold))
                        .foregroundStyle(Theme.textMuted),
                    at: CGPoint(x: gutter - 5, y: ty),
                    anchor: .trailing
                )
            }

            // Each series gets its average and a band one standard deviation
            // either side of it, so the two spreads can be compared by eye.
            func band(mean: Double, sd: Double, color: Color, dashed: Bool) {
                if sd > 0.0001 {
                    let top = y(mean + sd)
                    let bottom = y(mean - sd)
                    let rect = CGRect(x: plotLeft, y: top, width: plotRight - plotLeft, height: bottom - top)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color.opacity(0.18)))
                }
                var line = Path()
                let meanY = y(mean)
                line.move(to: CGPoint(x: plotLeft, y: meanY))
                line.addLine(to: CGPoint(x: plotRight, y: meanY))
                context.stroke(
                    line,
                    with: .color(color),
                    style: dashed ? StrokeStyle(lineWidth: 1.5, dash: [5, 3]) : StrokeStyle(lineWidth: 2)
                )
            }

            band(mean: proMean, sd: proSD, color: Theme.warning, dashed: true)
            band(mean: playedMean, sd: playedSD, color: Theme.textMuted, dashed: false)

            // Hairlines through the markers so the eye can follow each series
            // from round to round: solid for played, dashed for pro putting.
            if rounds.count > 1 {
                var playedPath = Path()
                var proPath = Path()
                for (index, round) in rounds.enumerated() {
                    let played = CGPoint(x: x(index), y: y(round.score))
                    let pro = CGPoint(x: x(index), y: y(round.scoreWithoutPutting))
                    if index == 0 {
                        playedPath.move(to: played)
                        proPath.move(to: pro)
                    } else {
                        playedPath.addLine(to: played)
                        proPath.addLine(to: pro)
                    }
                }
                context.stroke(playedPath, with: .color(Theme.text.opacity(0.45)), lineWidth: 0.5)
                context.stroke(proPath, with: .color(Theme.textMuted.opacity(0.55)),
                               style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }

            // The gap between the two is what the putter did that round.
            for (index, round) in rounds.enumerated() {
                let px = x(index)
                let scoreY = y(round.score)
                let withoutY = y(round.scoreWithoutPutting)
                let helped = round.sg > 0
                let gapColor = helped ? Theme.primary : Theme.error

                var gap = Path()
                gap.move(to: CGPoint(x: px, y: withoutY))
                gap.addLine(to: CGPoint(x: px, y: scoreY))
                context.stroke(gap, with: .color(gapColor.opacity(0.75)), lineWidth: 3)

                let hollow = CGRect(x: px - 3.5, y: withoutY - 3.5, width: 7, height: 7)
                context.stroke(Path(ellipseIn: hollow), with: .color(Theme.textMuted), lineWidth: 1.5)

                let filled = CGRect(x: px - 4, y: scoreY - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: filled), with: .color(Theme.text))
            }
        }
        .frame(height: chartHeight)
    }

    private func tickLabel(_ value: Double) -> String {
        "\(value > 0 ? "+" : "")\(String(format: "%.0f", value))"
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 14) {
                legendItem(L("stats.svp.scoreLegend")) {
                    Circle().fill(Theme.text).frame(width: 8, height: 8)
                }
                legendItem(L("stats.svp.withoutLegend")) {
                    Circle().stroke(Theme.textMuted, lineWidth: 1.5).frame(width: 8, height: 8)
                }
                legendItem(L("stats.svp.gapLegend")) {
                    // Green where putting gained, red where it cost — both
                    // appear in the chart, so both belong in the key.
                    HStack(spacing: 2) {
                        Capsule().fill(Theme.primary).frame(width: 3, height: 10)
                        Capsule().fill(Theme.error).frame(width: 3, height: 10)
                    }
                }
                Spacer(minLength: 0)
            }
            // The average line and its band belong to one another, so one key
            // covers both.
            legendItem(L("stats.svp.bandLegend")) {
                bandMarker(color: Theme.textMuted, dashed: false)
            }
            legendItem(L("stats.svp.bandLegendPro")) {
                bandMarker(color: Theme.warning, dashed: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A slice of the chart in miniature: the band with its average through it.
    private func bandMarker(color: Color, dashed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.28))
            Rectangle()
                .fill(color)
                .frame(height: 1.5)
                .mask(alignment: .leading) {
                    if dashed {
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { _ in Rectangle().frame(width: 3) }
                            Spacer(minLength: 0)
                        }
                    } else {
                        Rectangle()
                    }
                }
        }
        .frame(width: 20, height: 12)
    }

    private func legendItem<Marker: View>(_ label: String, @ViewBuilder marker: () -> Marker) -> some View {
        HStack(spacing: 5) {
            marker()
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Numbers

    private var summaryBoxes: some View {
        // Every box stretches to the tallest of the three, so the row reads as
        // one block rather than three different-sized cards.
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            box(
                L("stats.svp.avgScore"),
                signed(analysis.avgScore),
                caption: L("stats.svp.perRound"),
                color: Theme.text
            )
            box(
                L("stats.svp.avgWithout"),
                signed(analysis.avgScoreWithoutPutting),
                caption: L("stats.svp.perRound"),
                color: Theme.textSecondary
            )
            spreadBox
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func box(_ label: String, _ value: String, caption: String? = nil, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold)).tracking(0.4)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
    }

    /// What a narrower or wider pro-putting band actually tells you.
    ///
    /// Tighter with tour putting means your own putting is what pulls the
    /// rounds apart — fix that and the scores converge. Wider means the rounds
    /// would differ regardless, so the cause lies elsewhere.
    @ViewBuilder
    private var spreadBox: some View {
        if let change = analysis.spreadChangePercent, abs(change) >= 1 {
            let tighter = change < 0
            box(
                L(tighter ? "stats.svp.impactHigh" : "stats.svp.impactLow"),
                "\(Int(abs(change).rounded()))%",
                caption: L(tighter ? "stats.svp.tighter" : "stats.svp.wider"),
                color: tighter ? Theme.primary : Theme.textSecondary
            )
        } else {
            box(L("stats.svp.impactNone"), "—", color: Theme.textSecondary)
        }
    }

    private func signed(_ value: Double) -> String {
        if abs(value) < 0.05 { return "E" }
        return "\(value > 0 ? "+" : "")\(String(format: "%.1f", value))"
    }
}
