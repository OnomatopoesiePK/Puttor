//
//  MissDonutView.swift
//  Puttor
//
//  Miss tendency as a ring laid out like the dartboard used during play, so a
//  glance shows *where* misses cluster rather than a list of counts. The centre
//  is hollow — holed putts aren't misses — and each sector reddens with how
//  often that direction came up.
//

import SwiftUI

struct MissDonutView: View {
    /// Raw result counts; holed and non-directional results are filtered out here.
    let missCounts: [PuttResult: Int]
    /// Putts that lipped out. Zero leaves the middle hollow, as before — only
    /// the round summary passes a count, where the lip-outs of that round are
    /// still fresh enough to mean something.
    var lipOutCount: Int = 0

    private let size: CGFloat = 260

    private var directional: [PuttResult: Int] {
        var out: [PuttResult: Int] = [:]
        for (result, count) in missCounts where count > 0 {
            guard PolarGeometry.missSectors.contains(where: { $0.result == result }) else { continue }
            out[result] = count
        }
        return out
    }

    /// Misses with no direction attached — Quick-mode entries and hole-highs.
    private var undirected: Int {
        [PuttResult.missedGeneric, .holeHigh].reduce(0) { $0 + (missCounts[$1] ?? 0) }
    }

    private var maxCount: Int { directional.values.max() ?? 0 }
    private var total: Int { directional.values.reduce(0, +) }

    var body: some View {
        VStack(spacing: 8) {
            if total == 0 && undirected == 0 {
                Text(L("dispersion.noData"))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.vertical, 20)
            } else {
                donut
                if undirected > 0 {
                    Text(String(format: L("summary.missNoDirection"), undirected))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var donut: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outerR = min(canvasSize.width, canvasSize.height) / 2 - 2
            let innerR = outerR * 0.38

            for sector in PolarGeometry.missSectors {
                let count = directional[sector.result] ?? 0
                let path = PolarGeometry.annularSector(
                    startDeg: sector.startDeg,
                    endDeg: sector.startDeg + PolarGeometry.sectorSpan,
                    r1: innerR,
                    r2: outerR,
                    center: center
                )
                context.fill(path, with: .color(fill(for: count)))
                context.stroke(path, with: .color(Theme.border), lineWidth: 1)

                guard count > 0 else { continue }

                let mid = sector.startDeg + PolarGeometry.sectorSpan / 2
                let labelPoint = PolarGeometry.point(mid, (innerR + outerR) / 2, center)
                // Once the fill is saturated, white reads better than the theme text.
                let onDarkFill = intensity(for: count) > 0.55
                let tint: Color = onDarkFill ? .white : Theme.text

                // Count large, direction small underneath — one dense line of
                // "13x left" per sector made the ring hard to scan.
                var countLabel = context.resolve(
                    Text("\(count)").font(.system(size: 19, weight: .black))
                )
                countLabel.shading = .color(tint)
                context.draw(countLabel, at: CGPoint(x: labelPoint.x, y: labelPoint.y - 7), anchor: .center)

                var nameLabel = context.resolve(
                    Text(L(sector.result.labelKey)).font(.system(size: 9, weight: .semibold))
                )
                nameLabel.shading = .color(onDarkFill ? .white.opacity(0.85) : Theme.textSecondary)
                context.draw(nameLabel, at: CGPoint(x: labelPoint.x, y: labelPoint.y + 9), anchor: .center)
            }

            // Hollow centre: the total, so the ring still answers "how many".
            // Lip-outs join it there, the way the dartboard keeps them in the
            // middle — the misses that were nearly in.
            let shift: CGFloat = lipOutCount > 0 ? 8 : 0

            var totalLabel = context.resolve(
                Text("\(total)").font(.system(size: 22, weight: .black))
            )
            totalLabel.shading = .color(Theme.text)
            context.draw(totalLabel, at: CGPoint(x: center.x, y: center.y - 8 - shift), anchor: .center)

            var caption = context.resolve(
                Text(L("summary.missesLabel")).font(.system(size: 9, weight: .bold))
            )
            caption.shading = .color(Theme.textMuted)
            context.draw(caption, at: CGPoint(x: center.x, y: center.y + 12 - shift), anchor: .center)

            if lipOutCount > 0 {
                var lip = context.resolve(
                    Text(String(format: L("summary.lipOuts"), lipOutCount))
                        .font(.system(size: 11, weight: .bold))
                )
                lip.shading = .color(Theme.lipOut)
                context.draw(lip, at: CGPoint(x: center.x, y: center.y + 28), anchor: .center)
            }
        }
        .frame(width: size, height: size)
    }

    /// 0 for an unused direction, rising to 1 for the most frequent one.
    private func intensity(for count: Int) -> Double {
        guard count > 0, maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }

    private func fill(for count: Int) -> Color {
        guard count > 0 else { return Theme.surfaceElevated }
        // Floor the alpha so a single miss is still clearly tinted.
        return Theme.error.opacity(0.18 + 0.72 * intensity(for: count))
    }
}

#Preview {
    MissDonutView(missCounts: [.short: 5, .left: 3, .longRight: 1, .holed: 12])
        .padding()
        .background(Theme.background)
}
