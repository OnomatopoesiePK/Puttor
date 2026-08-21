//
//  PuttorApp.swift
//  Puttor
//
//  Created by Paul Kaineder on 23.07.26.
//

import SwiftUI
import SwiftData

@main
struct PuttorApp: App {
    let container: ModelContainer = {
        let schema = Schema([Putter.self, Round.self, Putt.self, GameSession.self, GameAttempt.self])
        let config = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    SGRecalculation.recomputeIfNeeded(in: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}
