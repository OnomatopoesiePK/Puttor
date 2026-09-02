//
//  StreakFlameView.swift
//  Puttor
//
//  The weekly streak: one flame that grows for every week in a row with
//  practice in it. For a drill you either finish or don't, a best time says
//  little and turning up says everything — so this is what stands where a high
//  score would otherwise be.
//

import SwiftUI

struct StreakFlameView: View {
    let weeks: Int
    /// The size the flame starts at; it grows from here with the streak.
    var baseSize: CGFloat = 20

    /// Ten weeks is where the flame stops growing — it still counts up, but a
    /// tile has an edge.
    private var growth: CGFloat { CGFloat(min(weeks, 10)) }
    private var size: CGFloat { baseSize + growth * (baseSize * 0.06) }

    /// Cold at one week, properly alight at ten.
    private var flame: LinearGradient {
        let heat = growth / 10
        return LinearGradient(
            colors: [
                Theme.accent.opacity(0.7 + 0.3 * heat),
                Color(red: 0.95, green: 0.35 + 0.15 * (1 - heat), blue: 0.15),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(spacing: 1) {
            if weeks > 0 {
                // Side by side: the flame reads as the unit belonging to the
                // number rather than as a picture sitting above it.
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: size, weight: .black))
                        .foregroundStyle(flame)
                    Text("\(weeks)")
                        .font(.system(size: size, weight: .black))
                        .foregroundStyle(Theme.text)
                }
                Text(L(weeks == 1 ? "game.streak.week" : "game.streak.weeks"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
            } else {
                Image(systemName: "flame")
                    .font(.system(size: baseSize, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                Text(L("game.streak.none"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
