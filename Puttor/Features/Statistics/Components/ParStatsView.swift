//
//  ParStatsView.swift
//  Puttor
//
//  The holes by their par: three bar charts, swiped between, each with a bar
//  for the par 3s, the par 4s and the par 5s — the average score against
//  par, the greens hit in regulation, and the putts per hole. Read wherever
//  the pars were given, in putt 0 or from the course's scorecard.
//

import SwiftUI

struct ParStatsView: View {
    let stats: RoundStats

    enum Page: Int, CaseIterable {
        case score, gir, putts

        var titleKey: String {
            switch self {
            case .score: return "stats.par.score"
            case .gir: return "stats.par.gir"
            case .putts: return "stats.par.putts"
            }
        }
    }

    @State private var page = Page.score
    /// Which way the last swipe went, so the next chart comes in from that side.
    @State private var forward = true

    var body: some View {
        VStack(spacing: 10) {
            Text(L(page.titleKey))
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .animation(nil, value: page)

            ZStack {
                chart(page)
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading),
                        removal: .move(edge: forward ? .leading : .trailing)
                    ))
            }
            .frame(height: 190)
            .clipped()
            .contentShape(Rectangle())
            .gesture(HorizontalSwipe(
                onLeft: Page(rawValue: page.rawValue + 1).map { next in { show(next) } },
                onRight: Page(rawValue: page.rawValue - 1).map { previous in { show(previous) } }
            ))

            dots
        }
    }

    private func show(_ next: Page) {
        guard next != page else { return }
        forward = next.rawValue > page.rawValue
        withAnimation(.easeInOut(duration: 0.3)) { page = next }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(Page.allCases, id: \.self) { item in
                Circle()
                    .fill(item == page ? Theme.primary : Theme.textMuted.opacity(0.5))
                    .frame(width: item == page ? 9 : 6, height: item == page ? 9 : 6)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
                    .onTapGesture { show(item) }
            }
        }
        .animation(.easeOut(duration: 0.18), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: L("dispersion.page"), page.rawValue + 1, Page.allCases.count))
    }

    // MARK: - Charts

    private func chart(_ page: Page) -> some View {
        let bars: [Bar] = HoleDetails.pars.map { par in
            switch page {
            case .score:
                let value = stats.averageScoreToPar(onPar: par)
                return Bar(par: par, value: value, text: value.map(scoreText) ?? "—",
                           colour: value.map(scoreColour) ?? Theme.textMuted, holes: stats.parHoles[par] ?? 0)
            case .gir:
                let value = stats.girPercent(onPar: par)
                return Bar(par: par, value: value, text: value.map { "\(Int($0.rounded()))%" } ?? "—",
                           colour: Theme.primary, holes: stats.parPlayedHoles[par] ?? 0)
            case .putts:
                let value = stats.averagePutts(onPar: par)
                return Bar(par: par, value: value, text: value.map { String(format: "%.2f", $0) } ?? "—",
                           colour: Theme.accent, holes: stats.parPuttedHoles[par] ?? 0)
            }
        }
        return BarChart(bars: bars, domain: domain(page, bars.compactMap(\.value)))
    }

    /// Scores run from level par to either side, but only as far as there are
    /// scores: all over par, the chart has no room below it. Shares run to a
    /// hundred, putts from none.
    private func domain(_ page: Page, _ values: [Double]) -> ClosedRange<Double> {
        switch page {
        case .score:
            var lower = min(0, values.min() ?? 0)
            var upper = max(0, values.max() ?? 0)
            if upper - lower < 1 {
                if lower < 0 && upper == 0 { lower = -1 }
                else if upper > 0 && lower == 0 { upper = 1 }
                else { lower = min(lower, -0.5); upper = max(upper, 0.5) }
            }
            return lower * 1.15...upper * 1.15
        case .gir:
            return 0...100
        case .putts:
            return 0...max(2.5, (values.max() ?? 0) * 1.15)
        }
    }

    private func scoreText(_ value: Double) -> String {
        if abs(value) < 0.005 { return "E" }
        return String(format: value > 0 ? "+%.2f" : "%.2f", value)
    }

    private func scoreColour(_ value: Double) -> Color {
        value < -0.005 ? Theme.primary : (value > 0.005 ? Theme.error : Theme.text)
    }
}

private struct Bar: Identifiable {
    let par: Int
    let value: Double?
    let text: String
    let colour: Color
    let holes: Int

    var id: Int { par }
}

/// Three bars from a line at nothing, up for more and down for less, with
/// the figure beside the end of each and the par and its holes under it.
private struct BarChart: View {
    let bars: [Bar]
    let domain: ClosedRange<Double>

    private let labelHeight: CGFloat = 34
    private let valueHeight: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            let plotHeight = proxy.size.height - labelHeight
            let span = domain.upperBound - domain.lowerBound
            let zeroY = valueHeight + (plotHeight - 2 * valueHeight) * CGFloat(domain.upperBound / span)
            let scale = (plotHeight - 2 * valueHeight) / CGFloat(span)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: proxy.size.width, height: 1)
                    .offset(y: zeroY)

                HStack(alignment: .top, spacing: 18) {
                    ForEach(bars) { bar in
                        column(bar, zeroY: zeroY, scale: scale, plotHeight: plotHeight)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func column(_ bar: Bar, zeroY: CGFloat, scale: CGFloat, plotHeight: CGFloat) -> some View {
        let value = bar.value ?? 0
        let length = max(bar.value == nil ? 0 : 3, abs(CGFloat(value) * scale))
        let top = value >= 0 ? zeroY - length : zeroY
        // The figure above an upward bar and below a downward one.
        let textY = value >= 0 ? top - valueHeight : zeroY + length + 2

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5)
                .fill(bar.colour.opacity(bar.value == nil ? 0 : 0.85))
                .frame(height: length)
                .offset(y: top)
            Text(bar.text)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(bar.value == nil ? Theme.textMuted : bar.colour)
                .frame(height: valueHeight)
                .offset(y: textY)
            VStack(spacing: 1) {
                Text(String(format: L("input.holePar.value"), bar.par))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(String(format: L("setup.scorecardHoles"), bar.holes))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
            }
            .offset(y: plotHeight + 2)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(format: L("input.holePar.value"), bar.par)): \(bar.text)")
    }
}
