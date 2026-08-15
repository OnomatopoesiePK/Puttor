//
//  SituationComparisonView.swift
//  Puttor
//
//  Replaces the earlier "one full distance-bracket chart per category" design:
//  a single table matching birdie/par/bogey make % at the *same* distances,
//  showing only the distance rows where at least one category has data.
//  e.g. a 4m par putt and a 4.5m birdie putt land in the same "4-5m" row.
//

import SwiftUI

struct SituationComparisonView: View {
    let makeByCategory: [ScoreCategory: [DistanceBracket]]
    var useFeet: Bool = false

    private let categories: [ScoreCategory] = [.birdie, .par, .bogey]

    private struct Row {
        let label: String
        let brackets: [ScoreCategory: DistanceBracket]
    }

    private var rows: [Row] {
        RoundStats.brackets(useFeet: useFeet).enumerated().compactMap { idx, b in
            var found: [ScoreCategory: DistanceBracket] = [:]
            for cat in categories {
                if let list = makeByCategory[cat], idx < list.count, list[idx].total > 0 {
                    found[cat] = list[idx]
                }
            }
            guard !found.isEmpty else { return nil }
            return Row(label: b.label, brackets: found)
        }
    }

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                Text(L("stats.makeBySituation"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)

                headerRow

                ForEach(rows, id: \.label) { row in
                    rowView(row)
                }

                HStack(spacing: 14) {
                    ForEach(categories) { cat in
                        HStack(spacing: 5) {
                            Circle().fill(cat.color).frame(width: 8, height: 8)
                            Text(L(cat.labelKey)).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text("").frame(width: 44, alignment: .leading)
            ForEach(categories) { cat in
                Text(L(cat.shortLabelKey)).frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(Theme.textMuted)
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 6) {
            Text(row.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 44, alignment: .leading)

            ForEach(categories) { cat in
                cell(row.brackets[cat], color: cat.color)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cell(_ bracket: DistanceBracket?, color: Color) -> some View {
        if let bracket, bracket.total > 0 {
            let pct = Int((Double(bracket.made) / Double(bracket.total) * 100).rounded())
            VStack(spacing: 1) {
                Text("\(pct)%").font(.system(size: 13, weight: .heavy)).foregroundStyle(color)
                Text("\(bracket.made)/\(bracket.total)").font(.system(size: 9)).foregroundStyle(Theme.textMuted)
            }
        } else {
            Text("–").font(.system(size: 13)).foregroundStyle(Theme.textMuted)
        }
    }
}
