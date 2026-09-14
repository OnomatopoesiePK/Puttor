//
//  SuccessFailButtons.swift
//  Puttor
//
//  Shared big ✓ / ✗ pair used across every drill's play screen.
//

import SwiftUI

struct SuccessFailButtons: View {
    var successLabel: String
    var failLabel: String
    var onSuccess: () -> Void
    var onFail: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            button(label: failLabel, icon: "xmark", color: Theme.error, action: onFail)
            button(label: successLabel, icon: "checkmark", color: Theme.primary, action: onSuccess)
        }
    }

    private func button(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 26, weight: .heavy))
                Text(label).font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(color))
        }
        .buttonStyle(.plain)
    }
}


/// Missed left, made, missed right — laid out the way the ball went, for the
/// drills that keep track of which side the misses go.
struct MissSideButtons: View {
    var onMissLeft: () -> Void
    var onMade: () -> Void
    var onMissRight: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            button(label: L("game.missedLeft"), icon: "arrow.left", color: Theme.error, action: onMissLeft)
            button(label: L("game.made"), icon: "checkmark", color: Theme.primary, action: onMade)
            button(label: L("game.missedRight"), icon: "arrow.right", color: Theme.error, action: onMissRight)
        }
    }

    private func button(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 24, weight: .heavy))
                Text(label)
                    .font(.system(size: 13, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(color))
        }
        .buttonStyle(.plain)
    }
}
