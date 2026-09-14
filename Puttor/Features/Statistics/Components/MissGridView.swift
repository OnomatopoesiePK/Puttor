//
//  MissGridView.swift
//  Puttor
//
//  The misses of the dispersion plot as shares of a grid of where they
//  finished, each field reddening with its share the way the miss tendency
//  ring does. Past the hole there are only left and right, side by side. The
//  hole sits between the rows that reached it and the rows that did not, and
//  the fields around it are dented to make room for it.
//

import SwiftUI

struct MissGridView: View {
    let putts: [Putt]
    let filter: DispersionFilter
    var distanceRange: ClosedRange<Double>?
    var useFeet = false

    private static let labelWidth: CGFloat = 76
    private static let rowHeight: CGFloat = 52
    private static let spacing: CGFloat = 6
    private static let headerHeight: CGFloat = 14
    /// The cup, and the room the fields around it leave it.
    private static let holeSize: CGFloat = 30
    private static let dentSize: CGFloat = 44

    /// Down from the top of the fields: between just past and just short.
    private static var holeCentre: CGFloat {
        headerHeight + spacing + rowHeight + spacing + rowHeight + spacing / 2
    }

    var body: some View {
        let grid = MissGrid(putts: putts, filter: filter, distanceRange: distanceRange)
        let strongest = MissGridCell.allCases.map(grid.percent).max() ?? 0

        return VStack(spacing: Self.spacing) {
            if grid.total == 0 {
                Text(L("dispersion.noData"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight * 4)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surfaceElevated))
            } else {
                HStack(alignment: .top, spacing: Self.spacing) {
                    labels
                    fields(grid, strongest)
                }
            }

            Text(L("dispersion.grid.caption"))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    // MARK: - Labels

    private var labels: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            Color.clear.frame(height: Self.headerHeight)
            label(L("dispersion.grid.long"), limit: nil)
            label(L("dispersion.grid.justPast"), limit: "≤ \(threshold(feet: 2, metres: MissGrid.justPastM))")
            label(L("dispersion.grid.justShort"), limit: "≤ \(threshold(feet: 1, metres: MissGrid.justShortM))")
            label(L("dispersion.grid.short"), limit: nil)
        }
        .frame(width: Self.labelWidth, alignment: .leading)
    }

    /// The row's name, and under it how far it reaches, where it has a limit.
    private func label(_ text: String, limit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let limit {
                Text(limit)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(height: Self.rowHeight)
    }

    /// A foot or two, in the unit in use: the usual distance format rounds
    /// anything this small into "<0.5 m".
    private func threshold(feet: Int, metres: Double) -> String {
        useFeet ? "\(feet) ft" : "\(Int((metres * 100).rounded())) cm"
    }

    // MARK: - Fields

    private func fields(_ grid: MissGrid, _ strongest: Double) -> some View {
        VStack(spacing: Self.spacing) {
            HStack(spacing: Self.spacing) {
                Text(L("dispersion.left")).frame(maxWidth: .infinity)
                Text(L("dispersion.right")).frame(maxWidth: .infinity)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.textMuted)
            .frame(height: Self.headerHeight)

            fieldRow([.leftLong, .rightLong], grid, strongest)
            fieldRow([.leftJustPast, .rightJustPast], grid, strongest)
            fieldRow([.leftJustShort, .centreJustShort, .rightJustShort], grid, strongest)
            fieldRow([.leftShort, .centreShort, .rightShort], grid, strongest)
        }
        // A round dent out of every field that touches the hole.
        .mask {
            Rectangle()
                .overlay(alignment: .top) {
                    Circle()
                        .frame(width: Self.dentSize, height: Self.dentSize)
                        .offset(y: Self.holeCentre - Self.dentSize / 2)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
        .overlay(alignment: .top) {
            Circle()
                .fill(Theme.background)
                .overlay(Circle().stroke(Theme.text, lineWidth: 2))
                .frame(width: Self.holeSize, height: Self.holeSize)
                .offset(y: Self.holeCentre - Self.holeSize / 2)
                .accessibilityHidden(true)
        }
    }

    private func fieldRow(_ cells: [MissGridCell], _ grid: MissGrid, _ strongest: Double) -> some View {
        HStack(spacing: Self.spacing) {
            ForEach(cells, id: \.self) { cell in
                field(grid.percent(cell), strongest: strongest)
            }
        }
        .frame(height: Self.rowHeight)
    }

    private func field(_ percent: Double, strongest: Double) -> some View {
        let intensity = strongest > 0 ? percent / strongest : 0
        return Text("\(Int(percent.rounded()))%")
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(percent > 0 ? Theme.text : Theme.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    // Floored, so a single miss still clearly tints its field.
                    .fill(percent > 0 ? Theme.error.opacity(0.18 + 0.72 * intensity) : Theme.surfaceElevated)
            )
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.border, lineWidth: 1))
    }
}
