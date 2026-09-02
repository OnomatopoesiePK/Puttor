//
//  LadderMap.swift
//  Puttor
//
//  The ladder drawn as a ladder: the spot you putt from at the bottom, the
//  target windows above it, furthest at the top. The rungs are evenly spaced
//  rather than to scale — at 5 to 20 m a true scale puts the near rungs on top
//  of each other and the whole thing stops being readable.
//

import SwiftUI

struct LadderMap: View {
    let distances: [Double]
    let useFeet: Bool
    /// Drawn a little heavier, for a rung being played.
    var highlighted: Double?

    var body: some View {
        GeometryReader { geo in
            let count = max(distances.count, 1)
            let spacing: CGFloat = 4
            let rungHeight = min(24, max(9, (geo.size.height - 26 - spacing * CGFloat(count)) / CGFloat(count)))

            VStack(spacing: spacing) {
                // Furthest at the top, the way it is walked.
                ForEach(distances.reversed(), id: \.self) { distance in
                    rung(distance, height: rungHeight)
                }
                startMarker
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func rung(_ distance: Double, height: CGFloat) -> some View {
        let isCurrent = highlighted.map { abs($0 - distance) < 0.01 } ?? false
        return ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isCurrent ? Theme.primary.opacity(0.22) : Theme.primary.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isCurrent ? Theme.primary : Theme.primary.opacity(0.4), lineWidth: isCurrent ? 2 : 1)
                )
            Text(UnitConverter.formatDistance(distance, useFeet: useFeet))
                .font(.system(size: min(12, height - 2), weight: .bold))
                .foregroundStyle(isCurrent ? Theme.primary : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(height: height)
    }

    /// Where the balls are struck from: one spot for every rung on the ladder.
    private var startMarker: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.golf")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text(L("game.ladder.startSpot"))
                .font(.system(size: 10, weight: .bold)).tracking(0.6)
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 22)
        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border, lineWidth: 1))
    }
}
