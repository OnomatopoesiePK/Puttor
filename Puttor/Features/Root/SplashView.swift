//
//  SplashView.swift
//  Puttor
//
//  The title screen, held for a moment after the app is up. iOS shows
//  LaunchScreen.storyboard until the first frame is drawn and cannot animate
//  it; this view repeats that screen exactly — same colour, same wordmark, same
//  place — so the two read as one, and then fades into the app.
//
//  Because the flag driving it lives in the App struct, it is created once per
//  process: a cold start shows it, coming back from the background does not.
//

import SwiftUI

struct SplashView: View {
    /// Matches LaunchScreen.storyboard, so the handover doesn't blink.
    private static let background = Color(red: 0.051, green: 0.106, blue: 0.165)
    /// The share of the screen's width the storyboard gives the wordmark.
    private static let wordmarkWidth: CGFloat = 0.61

    static let hold: Double = 1.5
    static let fade: Double = 0.4

    var body: some View {
        GeometryReader { geometry in
            Self.background
                .overlay {
                    Image("PuttorWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * Self.wordmarkWidth)
                }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}
