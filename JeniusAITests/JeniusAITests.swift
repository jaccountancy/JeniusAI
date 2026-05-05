//
//  JeniusAITests.swift
//  JeniusAITests
//
//  Created by Jay Wilson on 05/05/2026.
//

import Foundation
import Testing
@testable import JeniusAI

struct JeniusAITests {
    @Test func xeroAuthorizationURLUsesRailwayStartFlow() throws {
        let configuration = AppConfiguration(
            railwayBaseURL: URL(string: "https://jeniusai-production.up.railway.app")!,
            appCallbackURI: URL(string: "jeniusai://xero/callback")!
        )
        let service = XeroAuthService(
            configuration: configuration,
            defaults: UserDefaults(suiteName: "JeniusAITests.Xero")!
        )

        let url = try service.authorizationURL()
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(url.absoluteString.contains("/auth/xero/start"))
        #expect(queryItems.contains(where: { $0.name == "app_callback" && $0.value == "jeniusai://xero/callback" }))
    }
}
