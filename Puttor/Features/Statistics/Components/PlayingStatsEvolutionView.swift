//
//  PlayingStatsEvolutionView.swift
//  Puttor
//
//  How the playing stats moved from round to round: one chart per figure,
//  stacked straight on the background, each on its own scale and in its own
//  colour, with the rounds along a single axis at the bottom. About three
//  charts fill a screen, in portrait and in landscape alike.
//

import SwiftUI

enum PlayingStatsMetric: String, CaseIterable, Identifiable {
    case score, gir, conversion, scramble, puttsGir, puttsNoGir, threePutts, lipOuts, proximity

    var id: String { rawValue }
    var titleKey: String { "evolution.\(rawValue)" }
}

/// One round's playing stats, in the order the rounds were played. A figure is
/// missing where the round cannot give it: no score reference, no green hit,
/// no up-and-down to try.
struct PlayingStatsPoint: Identifiable, Equatable {
    /// The round's place in the series, oldest first.
    let id: Int
    let date: Date
    let values: [PlayingStatsMetric: Double]

    /// Rounds in any order, laid out oldest first. `tracksScore` says whether
    /// the figures read off the score reference can be trusted for the round.
    static func series(_ rounds: [(date: Date, stats: RoundStats, tracksScore: Bool)]) -> [PlayingStatsPoint] {
        rounds
            .filter { $0.stats.holes > 0 || $0.stats.scoredHoles > 0 }
            .sorted { $0.date < $1.date }
            .enumerated()
            .map { index, round in
                let stats = round.stats
                // Counted from the putts alone, so every round has them.
                var values: [PlayingStatsMetric: Double] = [
                    .threePutts: Double(stats.threePuttHoles),
                    .lipOuts: Double(stats.lipOutCount),
                ]
                if round.tracksScore {
                    if stats.scoredHoles > 0 { values[.score] = Double(stats.scoreRelativeToPar) }
                    if stats.holes > 0 { values[.gir] = stats.girPercent }
                    if stats.girCount > 0 { values[.conversion] = stats.girConversionPercent }
                    if stats.scrambleAttempts > 0 { values[.scramble] = stats.scramblePercent }
                    values[.puttsGir] = stats.avgPuttsOnGir
                    values[.puttsNoGir] = stats.avgPuttsOffGir
                    values[.proximity] = stats.avgGirProximityM
                }
                return PlayingStatsPoint(id: index, date: round.date, values: values)
            }
    }
}

struct PlayingStatsEvolutionView: View {
    let points: [PlayingStatsPoint]
    let useFeet: Bool
    let onBack: () -> Void

    /// The height of the scroll view, which the charts share out. Read off the
    /// scroll view's own frame, which its content has no say in, so a turn of
    /// the screen changes it once and the charts simply follow.
    @State private var viewportHeight: CGFloat = 0

    private static let chartsPerScreen: CGFloat = 3
    private static let spacing: CGFloat = Theme.Spacing.md
    /// The strip down the left edge that holds the way back.
    private static let backStripWidth: CGFloat = 20
    /// Under the last chart, for the dates.
    private static let roundAxisHeight: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.spacing) {
                if points.count < 2 {
                    Text(L("evolution.needMore"))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    let metrics = PlayingStatsMetric.allCases
                    ForEach(Array(metrics.enumerated()), id: \.element) { index, metric in
                        let isLast = index == metrics.count - 1
                        chart(metric, colour: palette[index % palette.count], showsRounds: isLast)
                            .frame(height: chartHeight + (isLast ? Self.roundAxisHeight : 0))
                    }
                }
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Self.spacing)
            .padding(.leading, Self.backStripWidth)
            .padding(.trailing, Theme.Spacing.edge)
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded(.down) } action: { height in
            viewportHeight = height
        }
        .overlay(alignment: .leading) { backButton }
        // A swipe to the right goes back, as the arrow does.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { drag in
                if drag.translation.width > 80, drag.translation.width > abs(drag.translation.height) * 1.5 {
                    onBack()
                }
            }
        )
        .background(Theme.background)
    }

    /// A third of the screen each, less the gaps between them.
    private var chartHeight: CGFloat {
        guard viewportHeight > 0 else { return 160 }
        let free = viewportHeight - Theme.Spacing.sm - Self.spacing * Self.chartsPerScreen
        return max(80, (free / Self.chartsPerScreen).rounded(.down))
    }

    // MARK: - Pieces

    private func chart(_ metric: PlayingStatsMetric, colour: Color, showsRounds: Bool) -> some View {
        let series = points.compactMap { point in
            point.values[metric].map { (index: point.id, value: shown($0, metric)) }
        }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(L(metric.titleKey))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(colour)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if !series.isEmpty {
                    let average = series.reduce(0) { $0 + $1.value } / Double(series.count)
                    Text("Ø \(text(average, metric))")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(colour)
                }
            }

            let domain = yDomain(series.map(\.value), metric)
            EvolutionChart(
                series: series,
                rounds: points.count,
                domain: domain,
                ticks: yTicks(domain),
                gridRounds: roundTicks,
                colour: colour,
                axisText: { text($0, metric, onAxis: true) },
                pointText: { text($0, metric) },
                // The rounds are named once, under the last chart, spread the
                // same way as in every chart above.
                roundLabels: showsRounds
                    ? labelledTicks.map { (index: $0, text: points[$0].date.formatted(.dateTime.day().month(.defaultDigits))) }
                    : []
            )
            .overlay {
                if series.isEmpty {
                    Text("—")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            // One element to VoiceOver, not one per point.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L(metric.titleKey))
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.compact.left")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.primary)
                .frame(width: Self.backStripWidth, height: 160)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("evolution.back"))
    }

    // MARK: - Scales and numbers

    /// A grid line per round while they fit, fewer beyond that.
    private var roundTicks: [Int] {
        let step = max(1, Int((Double(points.count) / 20).rounded(.up)))
        return Array(stride(from: 0, to: points.count, by: step))
    }

    /// Dates under the rounds, never more than six of them.
    private var labelledTicks: [Int] {
        let step = max(1, Int((Double(points.count) / 6).rounded(.up)))
        return Array(stride(from: 0, to: points.count, by: step))
    }

    /// One colour per chart, bright on the dark theme and deeper on the light.
    private var palette: [Color] {
        let dark = ThemeManager.shared.isDark
        let pairs: [(UInt32, UInt32)] = [
            (0x3DBA6F, 0x1F7A45), // green
            (0x6FA8FF, 0x1D5FCC), // blue
            (0xFF5C6C, 0xD62839), // red
            (0xFFB84D, 0xB86A0A), // amber
            (0x5BE7C4, 0x0E8F73), // teal
            (0xB08CFF, 0x6A3FC4), // violet
            (0xFF9E7D, 0xC24A26), // orange
            (0xF28AC8, 0xB0357A), // pink
            (0xB6E36A, 0x5E8A12), // lime
        ]
        return pairs.map { Color(hex: dark ? $0.0 : $0.1) }
    }

    /// Each chart on its own scale, around its own values, with a little room
    /// above and below. A flat series still gets a readable span, and shares
    /// and counts never run below nothing — nor shares past everything.
    private func yDomain(_ values: [Double], _ metric: PlayingStatsMetric) -> ClosedRange<Double> {
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let minimumSpan: Double
        switch metric {
        case .score: minimumSpan = 4
        case .gir, .conversion, .scramble: minimumSpan = 20
        case .puttsGir, .puttsNoGir: minimumSpan = 0.5
        case .threePutts, .lipOuts: minimumSpan = 2
        case .proximity: minimumSpan = useFeet ? 3 : 1
        }
        let span = max(high - low, minimumSpan)
        let middle = (low + high) / 2
        var lower = middle - span * 0.6
        var upper = middle + span * 0.6
        if metric != .score, lower < 0 {
            upper -= lower
            lower = 0
        }
        if [.gir, .conversion, .scramble].contains(metric), upper > 100 {
            lower = max(0, lower - (upper - 100))
            upper = 100
        }
        return lower...upper
    }

    /// Two or three round numbers inside a scale, worked out from the scale
    /// alone so the chart has nothing to reconsider when its size changes.
    private func yTicks(_ domain: ClosedRange<Double>) -> [Double] {
        let raw = (domain.upperBound - domain.lowerBound) / 2.5
        guard raw > 0 else { return [domain.lowerBound] }
        let magnitude = pow(10, floor(log10(raw)))
        let step = [1, 2, 2.5, 5, 10].map { $0 * magnitude }.first { $0 >= raw } ?? 10 * magnitude
        let first = (domain.lowerBound / step).rounded(.up) * step
        return Array(stride(from: first, through: domain.upperBound, by: step))
    }

    private func shown(_ value: Double, _ metric: PlayingStatsMetric) -> Double {
        metric == .proximity && useFeet ? UnitConverter.metresToFeet(value) : value
    }

    /// A figure as the chart writes it: whole numbers without decimals, the
    /// putts to two places beside a point and one on the axis.
    private func text(_ value: Double, _ metric: PlayingStatsMetric, onAxis: Bool = false) -> String {
        let whole = abs(value - value.rounded()) < 0.001
        switch metric {
        case .score:
            if abs(value) < 0.05 { return "E" }
            let number = whole ? String(Int(value.rounded())) : String(format: "%.1f", value)
            return value > 0 ? "+\(number)" : number
        case .gir, .conversion, .scramble:
            return "\(Int(value.rounded()))%"
        case .puttsGir, .puttsNoGir:
            return String(format: onAxis ? "%.1f" : "%.2f", value)
        case .threePutts, .lipOuts:
            return whole ? String(Int(value.rounded())) : String(format: "%.1f", value)
        case .proximity:
            let number = onAxis && whole ? String(Int(value.rounded())) : String(format: "%.1f", value)
            return number + (useFeet ? " ft" : " m")
        }
    }
}

/// A line through the rounds, drawn on a plain canvas: the values down the
/// left edge, the rounds spread evenly — the same in every chart, so they line
/// up down the stack — and the highest and lowest value written at their
/// points. A canvas has no size of its own to negotiate; it draws into
/// whatever it is given.
private struct EvolutionChart: View {
    let series: [(index: Int, value: Double)]
    let rounds: Int
    let domain: ClosedRange<Double>
    let ticks: [Double]
    let gridRounds: [Int]
    let colour: Color
    let axisText: (Double) -> String
    let pointText: (Double) -> String
    let roundLabels: [(index: Int, text: String)]

    /// The band at the left edge the values sit in.
    private static let valueBand: CGFloat = 30
    /// Above and below the line: room for the numbers at its highest and
    /// lowest points.
    private static let markRoom: CGFloat = 14
    /// The band under the plot the dates sit in, on the last chart.
    private static let roundBand: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let bottom = roundLabels.isEmpty ? 0 : Self.roundBand
            let plot = CGRect(
                x: Self.valueBand,
                y: Self.markRoom,
                width: max(1, size.width - Self.valueBand - 4),
                height: max(1, size.height - Self.markRoom * 2 - bottom)
            )
            let span = max(domain.upperBound - domain.lowerBound, 0.0001)
            let slots = Double(max(1, rounds))

            func xPosition(_ index: Int) -> CGFloat {
                plot.minX + plot.width * CGFloat((Double(index) + 0.5) / slots)
            }
            func yPosition(_ value: Double) -> CGFloat {
                plot.maxY - plot.height * CGFloat((value - domain.lowerBound) / span)
            }

            let grid = Theme.borderLight
            for index in gridRounds {
                var line = Path()
                line.move(to: CGPoint(x: xPosition(index), y: plot.minY))
                line.addLine(to: CGPoint(x: xPosition(index), y: plot.maxY))
                context.stroke(line, with: .color(grid), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
            }

            for tick in ticks {
                let y = yPosition(tick)
                var line = Path()
                line.move(to: CGPoint(x: plot.minX, y: y))
                line.addLine(to: CGPoint(x: plot.maxX, y: y))
                context.stroke(line, with: .color(grid), lineWidth: 0.5)
                context.draw(
                    Text(axisText(tick)).font(.system(size: 9)).foregroundStyle(Theme.textMuted),
                    at: CGPoint(x: 0, y: y),
                    anchor: .leading
                )
            }

            if series.count > 1 {
                var path = Path()
                for (position, item) in series.enumerated() {
                    let point = CGPoint(x: xPosition(item.index), y: yPosition(item.value))
                    if position == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                context.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            for item in series {
                let point = CGPoint(x: xPosition(item.index), y: yPosition(item.value))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)), with: .color(colour))
            }

            // The highest value over its point, the lowest under its own, both
            // kept clear of the chart's sides.
            var marks: [(item: (index: Int, value: Double), above: Bool)] = []
            if let highest = series.max(by: { $0.value < $1.value }) {
                marks.append((highest, true))
                if let lowest = series.min(by: { $0.value < $1.value }), lowest.value < highest.value {
                    marks.append((lowest, false))
                }
            }
            for mark in marks {
                let x = min(max(xPosition(mark.item.index), plot.minX + 14), size.width - 16)
                let y = yPosition(mark.item.value)
                context.draw(
                    Text(pointText(mark.item.value)).font(.system(size: 10, weight: .bold)).foregroundStyle(colour),
                    at: CGPoint(x: x, y: mark.above ? y - 5 : y + 5),
                    anchor: mark.above ? .bottom : .top
                )
            }

            for label in roundLabels {
                context.draw(
                    Text(label.text).font(.system(size: 9)).foregroundStyle(Theme.textMuted),
                    at: CGPoint(x: xPosition(label.index), y: plot.maxY + Self.markRoom),
                    anchor: .top
                )
            }
        }
    }
}
