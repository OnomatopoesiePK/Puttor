//
//  MetricValue.swift
//  Puttor
//
//  One way of writing the two numbers this app is built on. Strokes gained and
//  conversion gain turn up on nine different screens, and a figure that reads
//  "SG +0.42" in one place and "+0.42" in another is two figures as far as the
//  reader is concerned. So: the number, then what it is, always in that order
//  and always on one line — with the spread, where there is one, tucked under
//  the number rather than pushed alongside its name.
//

import SwiftUI

struct MetricValue: View {
    enum Metric {
        case sg, pcg

        var labelKey: String {
            switch self {
            case .sg: return "summary.sg"
            case .pcg: return "stats.pcg"
            }
        }
    }

    let value: Double
    let metric: Metric
    /// Standard deviation, printed as ± under the number.
    var spread: Double?
    var size: CGFloat = 14
    /// Overrides the sign colouring where a screen has its own thresholds.
    var colour: Color?
    var decimals: Int = 2

    private var tint: Color {
        colour ?? (value > 0 ? Theme.primary : (value < 0 ? Theme.error : Theme.textSecondary))
    }

    private var text: String {
        "\(value > 0 ? "+" : "")\(String(format: "%.\(decimals)f", value))"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let spread {
                    Text("±\(String(format: "%.2f", spread))")
                        .font(.system(size: max(9, size * 0.42), weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            Text(L(metric.labelKey))
                .font(.system(size: max(9, size * 0.55), weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
    }
}
