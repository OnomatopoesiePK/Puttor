//
//  ScoreCelebrationView.swift
//  Puttor
//
//  The wordmark that lands on screen when a birdie or an eagle drops: the
//  category's own colour, a ring behind it, and three pulses before it goes.
//  Drawn from the theme's tokens, so it reads on the dark card and the light
//  one alike.
//

import SwiftUI

struct ScoreCelebrationView: View {
    let category: ScoreCategory

    @State private var pulse = false
    @State private var entered = false

    /// Three pulses at this length, plus the entry, is about a second and a
    /// half — long enough to register, short enough not to be in the way.
    private static let pulseDuration = 0.28
    static let totalDuration = 1.6

    var body: some View {
        ZStack {
            // A halo rather than a plate: the wordmark keeps the green behind
            // it visible, which is what makes it feel like it belongs there.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [category.color.opacity(0.35), category.color.opacity(0)],
                        center: .center, startRadius: 4, endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .scaleEffect(pulse ? 1.08 : 0.92)

            VStack(spacing: 6) {
                Text(L(category.labelKey).uppercased())
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(category.color)
                    .shadow(color: category.color.opacity(0.55), radius: pulse ? 18 : 8)
                    // A second copy underneath in the surface colour keeps the
                    // letters legible whichever theme is on.
                    .background(
                        Text(L(category.labelKey).uppercased())
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .tracking(6)
                            .foregroundStyle(Theme.background)
                            .blur(radius: 6)
                    )

                Rectangle()
                    .fill(category.color)
                    .frame(width: pulse ? 120 : 70, height: 3)
                    .clipShape(Capsule())
            }
            .scaleEffect(pulse ? 1.06 : 1)
        }
        .scaleEffect(entered ? 1 : 0.6)
        .opacity(entered ? 1 : 0)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { entered = true }
            withAnimation(.easeInOut(duration: Self.pulseDuration).repeatCount(6, autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ScoreCelebrationView(category: .birdie)
    }
}
