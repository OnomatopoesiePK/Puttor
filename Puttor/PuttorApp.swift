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
    /// Created once per launch, so the title screen shows on a cold start and
    /// never again when the app comes back from the background.
    @State private var showingTitle = true

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
                    if showingTitle {
                        SplashView().transition(.opacity)
                    }
                }
                .task {
                    try? await Task.sleep(for: .seconds(SplashView.hold))
                    withAnimation(.easeInOut(duration: SplashView.fade)) { showingTitle = false }
                }
        }
        .modelContainer(container)
    }
}
