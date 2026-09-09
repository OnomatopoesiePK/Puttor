//
//  SplashView.swift
//  Puttor
//
//  What the launch screen turns into. The storyboard iOS shows first cannot
//  animate, so it holds the wordmark still on the same background this view
//  starts from — same colour, same size, same place — and this one carries on
//  with the ball rolling in. Handled that way the join is invisible: the only
//  thing that appears is the animation underneath.
//

import SwiftUI

struct SplashView: View {
    /// Matches LaunchScreen.storyboard exactly, so the handover doesn't blink.
    private static let background = Color(red: 0.051, green: 0.106, blue: 0.165)
    private static let wordmark = Color(red: 0.239, green: 0.729, blue: 0.435)

    /// One full roll-and-drop, which is what the loader's own loop takes.
    static let duration: Double = 1.55
    /// Nothing to watch when motion is off, so it gets out of the way sooner.
    static let reducedDuration: Double = 0.5

    private let tile: CGFloat = 150

    var body: some View {
        ZStack {
            Self.background.ignoresSafeArea()

            Text("PUTTOR")
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(Self.wordmark)

            PuttorLoaderView(size: tile)
                .clipShape(RoundedRectangle(cornerRadius: tile * 0.22, style: .continuous))
                // Below the wordmark, which stays where the storyboard put it:
                // half the label, the gap, then half the tile.
                .offset(y: 20 + 26 + tile / 2)
        }
    }
}

#Preview {
    SplashView()
}
