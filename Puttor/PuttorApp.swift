//
//  PuttorApp.swift
//  Puttor
//
//  Created by Paul Kaineder on 23.07.26.
//

import SwiftUI
import SwiftData

#if DEBUG
/// Where the time before the first frame actually goes. Debug only, so a
/// release build carries none of it.
enum LaunchClock {
    private static let start = CFAbsoluteTimeGetCurrent()
    private static var lastMark = CFAbsoluteTimeGetCurrent()

    static func mark(_ label: String) {
        let now = CFAbsoluteTimeGetCurrent()
        print(String(
            format: "⏱ launch — %@: %.0f ms (since start %.0f ms)",
            label, (now - lastMark) * 1000, (now - start) * 1000
        ))
        lastMark = now
    }
}
#endif

@main
struct PuttorApp: App {
    /// Covers the app for one turn of the loader, then fades. The storyboard
    /// launch screen is still on screen underneath it until the first frame,
    /// so what the player sees is one continuous screen.
    @State private var showingSplash = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let container: ModelContainer = {
        let schema = Schema([Putter.self, Round.self, Putt.self, GameSession.self, GameAttempt.self])
        let config = ModelConfiguration(schema: schema)
        let container = try! ModelContainer(for: schema, configurations: [config])
        #if DEBUG
        LaunchClock.mark("store opened")
        #endif
        return container
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                #if DEBUG
                .onAppear { LaunchClock.mark("first screen on") }
                #endif
                .overlay {
                    if showingSplash {
                        SplashView()
                            .transition(.opacity)
                    }
                }
                .task {
                    let seconds = reduceMotion ? SplashView.reducedDuration : SplashView.duration
                    try? await Task.sleep(for: .seconds(seconds))
                    withAnimation(.easeOut(duration: 0.35)) { showingSplash = false }
                }
        }
        .modelContainer(container)
    }
}
