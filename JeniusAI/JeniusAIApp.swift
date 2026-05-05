//
//  JeniusAIApp.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import SwiftData
import SwiftUI

@main
struct JeniusAIApp: App {
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PersistedSession.self,
            LoginHistoryRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
