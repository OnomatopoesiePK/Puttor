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
            shareBar
            if let verdict = analysis.verdict {
                Text(L(verdictKey(verdict)))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(L("stats.svp.note"))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Canvas { context, size in
            let rounds = analysis.rounds
            guard !rounds.isEmpty else { return }

            let values: [Double] = rounds.flatMap { [$0.score, $0.scoreWithoutPutting] } + [0]
            let rawMin = values.min() ?? 0
            let rawMax = values.max() ?? 0
            // A flat series would divide by zero; give it a stroke of room.
            let padding = max(1.0, (rawMax - rawMin) * 0.15)
            let low = rawMin - padding
            let high = rawMax + padding

            let inset: CGFloat = 14
            let plotWidth = size.width - inset * 2
            let step = rounds.count > 1 ? plotWidth / CGFloat(rounds.count - 1) : 0

            func x(_ index: Int) -> CGFloat {
                rounds.count > 1 ? inset + CGFloat(index) * step : size.width / 2
            }
            // Scores run the golfer's way round: under par sits at the top.
            func y(_ value: Double) -> CGFloat {
                let t = (value - low) / (high - low)
                return size.height - CGFloat(t) * size.height
            }

            // Par line.
            let parY = y(0)
            var par = Path()
            par.move(to: CGPoint(x: 0, y: parY))
            par.addLine(to: CGPoint(x: size.width, y: parY))
            context.stroke(par, with: .color(Theme.textMuted.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            context.draw(
                Text("PAR").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.textMuted),
                at: CGPoint(x: 12, y: parY - 7)
            )

            // Trend lines behind the markers.
            var withoutPath = Path()
            var scorePath = Path()
            for (index, round) in rounds.enumerated() {
                let p1 = CGPoint(x: x(index), y: y(round.scoreWithoutPutting))
                let p2 = CGPoint(x: x(index), y: y(round.score))
                if index == 0 {
                    withoutPath.move(to: p1)
                    scorePath.move(to: p2)
                } else {
                    withoutPath.addLine(to: p1)
                    scorePath.addLine(to: p2)
                }
            }
            context.stroke(withoutPath, with: .color(Theme.textMuted.opacity(0.45)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            context.stroke(scorePath, with: .color(Theme.text.opacity(0.55)), lineWidth: 1.5)

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

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Circle().fill(Theme.text).frame(width: 8, height: 8)
                Text(L("stats.svp.scoreLegend")).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 5) {
                Circle().stroke(Theme.textMuted, lineWidth: 1.5).frame(width: 8, height: 8)
                Text(L("stats.svp.withoutLegend")).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 5) {
                Capsule().fill(Theme.primary).frame(width: 3, height: 10)
                Text(L("stats.svp.gapLegend")).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Numbers

    private var summaryBoxes: some View {
        HStack(spacing: Theme.Spacing.xs) {
            box(
                L("stats.svp.avgScore"),
                signed(analysis.avgScore),
                subtitle: "σ \(String(format: "%.1f", analysis.sdScore))",
                color: analysis.avgScore <= 0 ? Theme.primary : Theme.text
            )
            box(
                L("stats.svp.avgWithout"),
                signed(analysis.avgScoreWithoutPutting),
                subtitle: "σ \(String(format: "%.1f", analysis.sdScoreWithoutPutting))",
                color: Theme.textSecondary
            )
            box(
                L("summary.sg"),
                "\(analysis.avgSG > 0 ? "+" : "")\(String(format: "%.2f", analysis.avgSG))",
                subtitle: L("stats.svp.perRound"),
                color: analysis.avgSG > 0 ? Theme.primary : (analysis.avgSG < 0 ? Theme.error : Theme.textSecondary)
            )
        }
    }

    private func box(_ label: String, _ value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .semibold)).tracking(0.4)
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textMuted.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
    }

    @ViewBuilder
    private var shareBar: some View {
        if let share = analysis.puttingShareForDisplay {
            VStack(spacing: 6) {
                HStack {
                    Text(L("stats.svp.share"))
                        .font(.system(size: 9, weight: .bold)).tracking(0.8)
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                }
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Theme.primary)
                            .frame(width: max(0, (geo.size.width - 2) * share))
                        Rectangle().fill(Theme.borderLight)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .frame(height: 14)

                HStack {
                    Text("\(Int((share * 100).rounded()))% \(L("stats.svp.putting"))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.primary)
                    Spacer()
                    Text("\(Int(((1 - share) * 100).rounded()))% \(L("stats.svp.rest"))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func signed(_ value: Double) -> String {
        if abs(value) < 0.05 { return "E" }
        return "\(value > 0 ? "+" : "")\(String(format: "%.1f", value))"
    }

    private func verdictKey(_ verdict: ScorePuttingAnalysis.Verdict) -> String {
        switch verdict {
        case .putting: return "stats.svp.verdictPutting"
        case .mixed: return "stats.svp.verdictMixed"
        case .rest: return "stats.svp.verdictRest"
        }
    }
}
