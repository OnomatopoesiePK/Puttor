//
//  PickUpScoreCard.swift
//  Puttor
//
//  Shown on a hole the ball was picked up on. There is no putting to edit, but
//  the hole can still carry a score — the one that would have gone on the card
//  had it been played out. It cannot be better than a double bogey: a hole
//  worth finishing was finished.
//
//  Left blank, the hole is written down as a double bogey and the round stays
//  out of the score statistics. Filled in, the score counts everywhere.
//

import SwiftUI

struct PickUpScoreCard: View {
    /// The score chosen for the hole, or nil while none has been.
    let category: ScoreCategory?
    let onChange: (ScoreCategory?) -> Void

    /// A picked-up hole is at least a double bogey, so the better categories
    /// are not on offer.
    private let options: [ScoreCategory] = [.double, .plus3, .plus4, .plus5, .plus6]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                PickUpBallIcon()
                    .foregroundStyle(Theme.accent)
                    .frame(width: 16, height: 16)
                Text(L("input.pickedUpHole"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            Text(L("input.pickUpScore"))
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textMuted)

            HStack(spacing: 6) {
                pill(title: L("input.pickUpNoScore"), selected: category == nil) { onChange(nil) }
                ForEach(options) { option in
                    pill(title: L(option.shortLabelKey), selected: category == option) { onChange(option) }
                }
            }

            Text(L("input.pickUpHint"))
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

    private func pill(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(selected ? .white : Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(selected ? Theme.accent : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(selected ? Theme.accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
