//
//  MissGridView.swift
//  Puttor
//
//  The misses of the dispersion plot as shares of a grid of where they
//  finished, each field reddening with its share the way the miss tendency
//  ring does. The hole sits in the middle, between the rows that reached it
//  and the rows that did not, and the fields around it are dented to make room
//  for it. The rows are as deep as what they hold, so the narrow band that is
//  just short of the hole looks as narrow as it is.
//

import SwiftUI

struct MissGridView: View {
    let putts: [Putt]
    let filter: DispersionFilter
    var distanceRange: ClosedRange<Double>?
    var useFeet = false

    private static let labelWidth: CGFloat = 92
    private static let spacing: CGFloat = 6
    private static let headerHeight: CGFloat = 14
    /// Long and way short reach as far as a putt can; the two bands around the
    /// hole are drawn to their real depth, 60 cm and 30.
    private static let openRowHeight: CGFloat = 54
    private static let justPastHeight: CGFloat = 32
    private static let justShortHeight: CGFloat = 20
    /// The cup, and the room the fields around it leave it.
    private static let holeSize: CGFloat = 22
    private static let dentSize: CGFloat = 30

    private static func height(_ row: MissGridRow) -> CGFloat {
        switch row {
        case .long, .wayShort: return openRowHeight
        case .justPast: return justPastHeight
        case .justShort: return justShortHeight
        }
    }

    /// Down from the top of the fields: between just past and just short.
    private static var holeCentre: CGFloat {
        headerHeight + spacing + openRowHeight + spacing + justPastHeight + spacing / 2
    }

    var body: some View {
        let grid = MissGrid(putts: putts, filter: filter, distanceRange: distanceRange)
        let strongest = MissGridCell.allCases.map(grid.percent).max() ?? 0

        return VStack(spacing: Self.spacing) {
            if grid.total == 0 {
                Text(L("dispersion.noData"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: Self.openRowHeight * 3)
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
            label(L("dispersion.grid.long"), limit: nil, row: .long)
            label(L("dispersion.grid.justPast"), limit: "≤ \(threshold(feet: 2, metres: MissGrid.justPastM))", row: .justPast)
            label(L("dispersion.grid.justShort"), limit: "≤ \(threshold(feet: 1, metres: MissGrid.justShortM))", row: .justShort)
            label(L("dispersion.grid.wayShort"), limit: nil, row: .wayShort)
        }
        .frame(width: Self.labelWidth, alignment: .leading)
    }

    /// The row's name and, where it has one, how far it reaches — on one line,
    /// since the bands around the hole are too shallow for two.
    private func label(_ text: String, limit: String?, row: MissGridRow) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            if let limit {
                Text(limit)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(width: Self.labelWidth, height: Self.height(row), alignment: .leading)
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
                columnLabel("dispersion.grid.farLeft")
                columnLabel("dispersion.left")
                columnLabel("dispersion.right")
                columnLabel("dispersion.grid.farRight")
            }
            .frame(height: Self.headerHeight)

            ForEach(MissGridRow.allCases, id: \.self) { row in
                HStack(spacing: Self.spacing) {
                    ForEach(row.cells, id: \.self) { cell in
                        field(grid.percent(cell), strongest: strongest, row: row)
                    }
                }
                .frame(height: Self.height(row))
            }
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

    private func columnLabel(_ key: String) -> some View {
        Text(L(key))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }

    private func field(_ percent: Double, strongest: Double, row: MissGridRow) -> some View {
        let intensity = strongest > 0 ? percent / strongest : 0
        return Text("\(Int(percent.rounded()))%")
            .font(.system(size: Self.height(row) < 28 ? 12 : 17, weight: .heavy))
            .foregroundStyle(percent > 0 ? Theme.text : Theme.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    // Floored, so a single miss still clearly tints its field.
                    .fill(percent > 0 ? Theme.error.opacity(0.18 + 0.72 * intensity) : Theme.surfaceElevated)
            )
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.border, lineWidth: 1))
    }
}
