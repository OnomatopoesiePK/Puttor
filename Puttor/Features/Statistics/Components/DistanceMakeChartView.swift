//
//  DistanceMakeChartView.swift
//  Puttor
//
//  Ported from the prototype's DistanceMakeChart.tsx.
//

import SwiftUI

struct DistanceMakeChartView: View {
    let data: [DistanceBracket]
    var pcgDivisor: Int = 1
    var title: String? = nil
    var showPCG: Bool = true
    /// Off when the surrounding section header already names the chart.
    var showsTitle: Bool = true

    private var visible: [DistanceBracket] { data.filter { $0.total > 0 } }
    private let barsWidth: CGFloat = 84

    var body: some View {
        if visible.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 4) {
                if showsTitle {
                    Text(title ?? L("chart.makeVsTour"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textMuted)
                }

                headerRow

                ForEach(visible) { bracket in
                    row(bracket)
                }

                HStack(spacing: 12) {
                    legend(color: Color(hex: 0x3A5570), label: L("chart.tour"))
                    legend(color: Theme.primary, label: L("chart.youAheadOfTour"))
                    legend(color: Theme.error, label: L("chart.youBehindTour"))
                }
                .padding(.top, 6)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text("").frame(width: 44, alignment: .leading)
            Text(L("chart.tourToYou")).frame(width: barsWidth)
            Text(L("chart.made")).frame(width: 38, alignment: .trailing)
            Text(L("chart.you")).frame(width: 34, alignment: .trailing)
            Text(L("chart.tourAbbr")).frame(width: 34, alignment: .trailing)
            if showPCG {
                Text(L("stats.pcg")).frame(width: 36, alignment: .trailing)
            }
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(Theme.textMuted)
    }

    private func row(_ b: DistanceBracket) -> some View {
        let playerPct = b.total > 0 ? Double(b.made) / Double(b.total) * 100 : 0
        let ahead = playerPct >= b.tourMakePct
        let playerColor = ahead ? Theme.primary : Theme.error
        let pcg = b.pcgTotal / Double(max(1, pcgDivisor))
        let pcgColor = pcg > 0 ? Theme.primary : (pcg < 0 ? Theme.error : Theme.textSecondary)

        return HStack(alignment: .center, spacing: 6) {
            Text(b.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.8).frame(width: 44, alignment: .leading)

            VStack(spacing: 4) {
                barTrack(pct: b.tourMakePct, color: Color(hex: 0x3A5570))
                barTrack(pct: playerPct, color: playerColor)
            }
            .frame(width: barsWidth)

            Text("\(b.made)/\(b.total)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.8).frame(width: 38, alignment: .trailing)
            Text("\(Int(playerPct.rounded()))%").font(.system(size: 12, weight: .heavy)).foregroundStyle(playerColor)
                .lineLimit(1).minimumScaleFactor(0.8).frame(width: 34, alignment: .trailing)
            Text("\(Int(b.tourMakePct.rounded()))%").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.8).frame(width: 34, alignment: .trailing)
            if showPCG {
                Text("\(pcg >= 0 ? "+" : "")\(String(format: "%.1f", pcg))").font(.system(size: 11, weight: .semibold)).foregroundStyle(pcgColor)
                    .lineLimit(1).minimumScaleFactor(0.8).frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private func barTrack(pct: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.borderLight)
                RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(color)
                    .frame(width: geo.size.width * max(0, min(1, pct / 100)))
            }
        }
        .frame(height: 8)
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
        }
    }
}
