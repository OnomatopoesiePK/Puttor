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
    // The order the charts stack in until they are arranged otherwise: the
    // putting figures first, then the round's — the score with its holes by
    // score under it — and the total just above the putts it splits into.
    case sg, pcg, score, birdies, pars, bogeys, doubles
    case gir, conversion, scramble, totalPutts, puttsGir, puttsNoGir, threePutts, lipOuts, proximity

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
    /// Played over nine holes, so its totals are half a round's; marked in the
    /// charts with the asterisk it carries in the lists.
    var isNineHoles = false

    /// Rounds in any order, laid out oldest first. `tracksScore` says whether
    /// the figures read off the score reference can be trusted for the round.
    static func series(_ rounds: [(date: Date, stats: RoundStats, tracksScore: Bool, nineHoles: Bool)]) -> [PlayingStatsPoint] {
        rounds
            .filter { $0.stats.holes > 0 || $0.stats.scoredHoles > 0 }
            .sorted { $0.date < $1.date }
            .enumerated()
            .map { index, round in
                let stats = round.stats
                // Counted from the putts alone, so every round has them.
                var values: [PlayingStatsMetric: Double] = [
                    .sg: stats.sgTotal,
                    .pcg: stats.pcgTotal,
                    .totalPutts: Double(stats.totalPutts),
                    .threePutts: Double(stats.threePuttHoles),
                    .lipOuts: Double(stats.lipOutCount),
                ]
                if round.tracksScore {
                    if stats.scoredHoles > 0 {
                        values[.score] = Double(stats.scoreRelativeToPar)
                        values[.birdies] = Double(stats.birdiesOrBetter)
                        values[.pars] = Double(stats.pars)
                        values[.bogeys] = Double(stats.bogeys)
                        values[.doubles] = Double(stats.doublesOrWorse)
                    }
                    if stats.holes > 0 { values[.gir] = stats.girPercent }
                    if stats.girCount > 0 { values[.conversion] = stats.girConversionPercent }
                    if stats.scrambleAttempts > 0 { values[.scramble] = stats.scramblePercent }
                    values[.puttsGir] = stats.avgPuttsOnGir
                    values[.puttsNoGir] = stats.avgPuttsOffGir
                    values[.proximity] = stats.avgGirProximityM
                }
                return PlayingStatsPoint(id: index, date: round.date, values: values, isNineHoles: round.nineHoles)
            }
    }
}

/// Which evolution charts show, in what order, and which were taken out, kept
/// as one line of text: the figures in order, the taken-out ones marked. A
/// figure the text has never heard of joins the end of the shown ones.
struct EvolutionChartLayout: Equatable {
    private(set) var shown: [PlayingStatsMetric]
    private(set) var hidden: [PlayingStatsMetric]

    init(text: String) {
        var shown: [PlayingStatsMetric] = []
        var hidden: [PlayingStatsMetric] = []
        for entry in text.split(separator: ",") {
            let isHidden = entry.hasPrefix("-")
            guard let metric = PlayingStatsMetric(rawValue: String(isHidden ? entry.dropFirst() : entry)),
                  !shown.contains(metric), !hidden.contains(metric)
            else { continue }
            if isHidden { hidden.append(metric) } else { shown.append(metric) }
        }
        shown += PlayingStatsMetric.allCases.filter { !shown.contains($0) && !hidden.contains($0) }
        self.shown = shown
        self.hidden = hidden
    }

    var text: String {
        (shown.map(\.rawValue) + hidden.map { "-" + $0.rawValue }).joined(separator: ",")
    }

    func moving(from source: IndexSet, to destination: Int) -> EvolutionChartLayout {
        var copy = self
        copy.shown.move(fromOffsets: source, toOffset: destination)
        return copy
    }

    /// Taken out, and first in line to come back.
    func hiding(at offsets: IndexSet) -> EvolutionChartLayout {
        var copy = self
        let taken = offsets.map { shown[$0] }
        copy.shown.remove(atOffsets: offsets)
        copy.hidden = taken + copy.hidden
        return copy
    }

    /// Back in, at the bottom of the stack.
    func showing(_ metric: PlayingStatsMetric) -> EvolutionChartLayout {
        guard let index = hidden.firstIndex(of: metric) else { return self }
        var copy = self
        copy.hidden.remove(at: index)
        copy.shown.append(metric)
        return copy
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

    /// The charts' order and which are taken out, the same in both compare panes.
    @AppStorage("evolution.chartLayout") private var layoutText = ""
    @State private var arranging = false

    private var layout: EvolutionChartLayout {
        get { EvolutionChartLayout(text: layoutText) }
        nonmutating set { layoutText = newValue.text }
    }

    private static let chartsPerScreen: CGFloat = 3
    /// Landscape has a third of portrait's height; below this a chart is too
    /// flat to read, so there a little less than three fit.
    private static let minimumChartHeight: CGFloat = 135
    /// Up to this many rounds every point carries its number; beyond it only
    /// the highest and the lowest do.
    private static let everyPointLimit = 10
    private static let spacing: CGFloat = Theme.Spacing.md
    /// The strip down the left edge that holds the way back.
    private static let backStripWidth: CGFloat = 20
    /// Under the last chart, for the dates.
    private static let roundAxisHeight: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if arranging {
                chartArranger
            } else {
                charts
            }
        }
        .overlay(alignment: .leading) {
            if !arranging { backButton }
        }
        // A swipe to the right goes back, as the arrow does: as soon as the
        // swipe is clearly sideways, not once the finger lifts. Not while the
        // charts are arranged, where rows are dragged about.
        .simultaneousGesture(
            DragGesture(minimumDistance: 10).onChanged { drag in
                if drag.translation.width > 30, drag.translation.width > abs(drag.translation.height) * 1.5 {
                    onBack()
                }
            },
            including: arranging ? .subviews : .all
        )
        .background(Theme.background)
    }

    private var charts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.spacing) {
                if points.count < 2 {
                    note(L("evolution.needMore"))
                } else if layout.shown.isEmpty {
                    note(L("evolution.noneShown"))
                } else {
                    let metrics = layout.shown
                    ForEach(Array(metrics.enumerated()), id: \.element) { index, metric in
                        let isLast = index == metrics.count - 1
                        chart(metric, colour: colour(for: metric), showsRounds: isLast)
                            .frame(height: chartHeight + (isLast ? Self.roundAxisHeight : 0))
                    }
                    if points.contains(where: \.isNineHoles) {
                        Text("* \(L("onCourse.nineHoleRound"))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Self.spacing)
            .padding(.leading, Self.backStripWidth)
            .padding(.trailing, Theme.Spacing.edge)
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded(.down) } action: { height in
            viewportHeight = height
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textMuted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    /// Three lines in the corner into arranging the charts, a tick out of it.
    private var toolbar: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { arranging.toggle() }
            } label: {
                Image(systemName: arranging ? "checkmark" : "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 44, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L(arranging ? "evolution.doneArranging" : "evolution.arrange"))
        }
        .padding(.trailing, Theme.Spacing.edge)
    }

    /// The charts by name, to put in order, take out and bring back. Only the
    /// names move, not the charts, so a long stack is arranged at a glance.
    private var chartArranger: some View {
        List {
            Section(L("evolution.shown")) {
                ForEach(layout.shown) { metric in
                    arrangerName(metric)
                        .listRowBackground(Theme.surface)
                }
                .onMove { source, destination in layout = layout.moving(from: source, to: destination) }
                .onDelete { offsets in layout = layout.hiding(at: offsets) }
            }
            if !layout.hidden.isEmpty {
                Section(L("evolution.hidden")) {
                    ForEach(layout.hidden) { metric in
                        HStack(spacing: 12) {
                            Button {
                                withAnimation { layout = layout.showing(metric) }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .green)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(format: L("evolution.add"), L(metric.titleKey)))
                            arrangerName(metric)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    private func arrangerName(_ metric: PlayingStatsMetric) -> some View {
        Text(L(metric.titleKey))
            .font(.system(size: 13, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(colour(for: metric))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// A third of the screen each, less the gaps between them, but never
    /// flatter than the minimum.
    private var chartHeight: CGFloat {
        guard viewportHeight > 0 else { return 160 }
        let free = viewportHeight - Theme.Spacing.xs - Self.spacing * Self.chartsPerScreen
        return max(Self.minimumChartHeight, (free / Self.chartsPerScreen).rounded(.down))
    }

    // MARK: - Pieces

    private func chart(_ metric: PlayingStatsMetric, colour: Color, showsRounds: Bool) -> some View {
        let series = points.compactMap { point in
            point.values[metric].map { (index: point.id, value: shown($0, metric)) }
        }
        let average = series.isEmpty ? nil : series.reduce(0) { $0 + $1.value } / Double(series.count)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(L(metric.titleKey))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(colour)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if let average {
                    Text("Ø \(text(average, metric))")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(colour)
                }
            }

            let domain = yDomain(series.map(\.value), metric)
            let everyPoint = points.count <= Self.everyPointLimit
            EvolutionChart(
                series: series,
                rounds: points.count,
                domain: domain,
                ticks: yTicks(domain),
                gridRounds: roundTicks,
                nineHoleRounds: Set(points.filter(\.isNineHoles).map(\.id)),
                colour: colour,
                average: average,
                axisText: { text($0, metric, onAxis: true) },
                // A number at every point leaves no room for a unit after
                // each; the axis already gives it.
                pointText: { text($0, metric, withUnit: !everyPoint) },
                labelsEveryPoint: everyPoint,
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

    /// One colour per figure, tied to the figure rather than its place so a
    /// chart keeps its colour however the stack is arranged. The holes by
    /// score wear the score colours the rest of the app uses; the others are
    /// bright on the dark theme and deeper on the light.
    private func colour(for metric: PlayingStatsMetric) -> Color {
        func tone(_ dark: UInt32, _ light: UInt32) -> Color {
            Color(hex: ThemeManager.shared.isDark ? dark : light)
        }
        switch metric {
        case .sg: return tone(0xF5D547, 0x8C7400)         // yellow
        case .pcg: return tone(0xD8E2EA, 0x46596A)        // silver
        case .score: return tone(0x4DD4FF, 0x0A7FA3)      // cyan: green is par's
        case .birdies: return ScoreCategory.birdie.color
        case .pars: return ScoreCategory.par.color
        case .bogeys: return ScoreCategory.bogey.color
        case .doubles: return ScoreCategory.double.color
        case .gir: return tone(0x6FA8FF, 0x1D5FCC)        // blue
        case .conversion: return tone(0xFF5C6C, 0xD62839) // red
        case .scramble: return tone(0xFFB84D, 0xB86A0A)   // amber
        case .totalPutts: return tone(0x8C9EFF, 0x3A4DB8) // indigo
        case .puttsGir: return tone(0x5BE7C4, 0x0E8F73)   // teal
        case .puttsNoGir: return tone(0xB08CFF, 0x6A3FC4) // violet
        case .threePutts: return tone(0xFF9E7D, 0xC24A26) // orange
        case .lipOuts: return tone(0xF28AC8, 0xB0357A)    // pink
        case .proximity: return tone(0xB6E36A, 0x5E8A12)  // lime
        }
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
        case .sg, .pcg: minimumSpan = 2
        case .totalPutts: minimumSpan = 4
        case .birdies, .pars, .bogeys, .doubles: minimumSpan = 2
        case .gir, .conversion, .scramble: minimumSpan = 20
        case .puttsGir, .puttsNoGir: minimumSpan = 0.5
        case .threePutts, .lipOuts: minimumSpan = 2
        case .proximity: minimumSpan = useFeet ? 3 : 1
        }
        let span = max(high - low, minimumSpan)
        let middle = (low + high) / 2
        var lower = middle - span * 0.6
        var upper = middle + span * 0.6
        // Strokes gained and the score run either side of nothing; the
        // rest never go below it.
        if ![.score, .sg, .pcg].contains(metric), lower < 0 {
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
    private func text(_ value: Double, _ metric: PlayingStatsMetric, onAxis: Bool = false, withUnit: Bool = true) -> String {
        let whole = abs(value - value.rounded()) < 0.001
        switch metric {
        case .sg, .pcg:
            if abs(value) < 0.05 { return onAxis ? "0" : "0.0" }
            let number = onAxis && whole ? String(Int(value.rounded())) : String(format: "%.1f", value)
            return value > 0 ? "+\(number)" : number
        case .score:
            if abs(value) < 0.05 { return "E" }
            let number = whole ? String(Int(value.rounded())) : String(format: "%.1f", value)
            return value > 0 ? "+\(number)" : number
        case .gir, .conversion, .scramble:
            return "\(Int(value.rounded()))%"
        case .puttsGir, .puttsNoGir:
            return String(format: onAxis ? "%.1f" : "%.2f", value)
        case .totalPutts, .birdies, .pars, .bogeys, .doubles, .threePutts, .lipOuts:
            return whole ? String(Int(value.rounded())) : String(format: "%.1f", value)
        case .proximity:
            let number = onAxis && whole ? String(Int(value.rounded())) : String(format: "%.1f", value)
            return withUnit ? number + (useFeet ? " ft" : " m") : number
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
    /// The rounds played over nine holes, drawn as an asterisk.
    let nineHoleRounds: Set<Int>
    let colour: Color
    /// Drawn across the chart as a dashed line in the chart's colour.
    let average: Double?
    let axisText: (Double) -> String
    let pointText: (Double) -> String
    /// Every point's number, or only the highest's and the lowest's.
    let labelsEveryPoint: Bool
    let roundLabels: [(index: Int, text: String)]

    /// The band at the left edge the values sit in.
    private static let valueBand: CGFloat = 30
    /// Above and below the line: room for a number over its highest point
    /// and under its lowest, the text's full height clear of the chart's
    /// edge. Less than that, and a nought at the foot of a chart was cut off.
    private static let markRoom: CGFloat = 20
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

            // The average under the line, dashed and a little fainter, so the
            // rounds above and below it read at a glance.
            if let average {
                let y = yPosition(average)
                var line = Path()
                line.move(to: CGPoint(x: plot.minX, y: y))
                line.addLine(to: CGPoint(x: plot.maxX, y: y))
                context.stroke(line, with: .color(colour.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
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
                if nineHoleRounds.contains(item.index) {
                    // The asterisk a nine-hole round carries in the lists: three
                    // crossed strokes, on a rim of the background so the line
                    // running into it doesn't blur it.
                    var star = Path()
                    for degrees in [90.0, 30.0, -30.0] {
                        let radians = degrees * .pi / 180
                        let reach = CGSize(width: cos(radians) * 5.5, height: sin(radians) * 5.5)
                        star.move(to: CGPoint(x: point.x - reach.width, y: point.y - reach.height))
                        star.addLine(to: CGPoint(x: point.x + reach.width, y: point.y + reach.height))
                    }
                    context.stroke(star, with: .color(Theme.background), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    context.stroke(star, with: .color(colour), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                } else {
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)), with: .color(colour))
                }
            }

            // Numbers at the points, kept clear of the chart's sides. Each one
            // goes on the open side of its point — over a peak, under a
            // dip — so the line never runs through it.
            var marks: [(item: (index: Int, value: Double), above: Bool)] = []
            if labelsEveryPoint {
                for (position, item) in series.enumerated() {
                    let neighbours = [position - 1, position + 1]
                        .filter { series.indices.contains($0) }
                        .map { series[$0].value }
                    let around = neighbours.isEmpty ? item.value : neighbours.reduce(0, +) / Double(neighbours.count)
                    marks.append((item, item.value >= around))
                }
            } else if let highest = series.max(by: { $0.value < $1.value }) {
                marks.append((highest, true))
                if let lowest = series.min(by: { $0.value < $1.value }), lowest.value < highest.value {
                    marks.append((lowest, false))
                }
            }
            for mark in marks {
                let x = min(max(xPosition(mark.item.index), plot.minX + 12), size.width - 14)
                let y = yPosition(mark.item.value)
                context.draw(
                    Text(pointText(mark.item.value)).font(.system(size: labelsEveryPoint ? 9.5 : 10, weight: .bold)).foregroundStyle(colour),
                    at: CGPoint(x: x, y: mark.above ? y - 6 : y + 6),
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
