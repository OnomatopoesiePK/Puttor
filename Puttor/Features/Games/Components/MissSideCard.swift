//
//  MissSideCard.swift
//  Puttor
//
//  How many misses went left and how many right, with the side that keeps
//  coming up named once there are enough misses to say so.
//

import SwiftUI

struct MissSideCard: View {
    let tally: MissSideTally

    var body: some View {
        VStack(spacing: 10) {
            Text(L("game.side.title"))
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMuted)
            HStack(spacing: Theme.Spacing.sm) {
                side(icon: "arrow.left", label: L("game.missedLeft"), count: tally.left, leading: tally.leaning == -1)
                side(icon: "arrow.right", label: L("game.missedRight"), count: tally.right, leading: tally.leaning == 1)
            }
            Text(sentence)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.border, lineWidth: 1))
    }

    private var sentence: String {
        switch tally.leaning {
        case -1: return String(format: L("game.side.leanLeft"), tally.left, tally.misses)
        case 1: return String(format: L("game.side.leanRight"), tally.right, tally.misses)
        default:
            return tally.misses < MissSideTally.minimumMisses
                ? String(format: L("game.side.tooFew"), MissSideTally.minimumMisses)
                : L("game.side.even")
        }
    }

    private func side(icon: String, label: String, count: Int, leading: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .heavy))
                Text("\(count)").font(.system(size: 24, weight: .heavy))
            }
            .foregroundStyle(leading ? Theme.error : Theme.text)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(leading ? Theme.error.opacity(0.12) : Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(leading ? Theme.error : Theme.border, lineWidth: 1))
    }
}
