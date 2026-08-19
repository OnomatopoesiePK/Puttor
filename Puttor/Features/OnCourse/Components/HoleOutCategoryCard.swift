//
//  HoleOutCategoryCard.swift
//  Puttor
//
//  Shown when the hole on screen was holed out from off the green. There is no
//  putt to edit, but the score it was holed out for still matters: it decides
//  the hole's score, and whether it counts as a green in regulation or as a
//  scramble save. Adding a real putt from the slot above supersedes it.
//

import SwiftUI

struct HoleOutCategoryCard: View {
    let category: ScoreCategory
    let onChange: (ScoreCategory) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("🎯 \(L("summary.holedOut"))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)

            ScoreCategoryRow(
                selection: Binding(get: { category }, set: { onChange($0) }),
                titleKey: "input.holedOutFor"
            )

            Text(L("input.holeOutHint"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.accent.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }
}
