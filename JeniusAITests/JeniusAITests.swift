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
    @Test func xeroAuthorizationURLUsesPKCE() throws {
        let configuration = AppConfiguration(
            xeroClientID: "demo-client-id",
            xeroRedirectURI: URL(string: "jeniusai://xero/callback")!,
            railwayBaseURL: nil
        )
        let service = XeroAuthService(
            configuration: configuration,
            defaults: UserDefaults(suiteName: "JeniusAITests.Xero")!
        )

        let url = try service.authorizationURL()
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(url.absoluteString.contains("login.xero.com/identity/connect/authorize"))
        #expect(queryItems.contains(where: { $0.name == "client_id" && $0.value == "demo-client-id" }))
        #expect(queryItems.contains(where: { $0.name == "code_challenge_method" && $0.value == "S256" }))
        #expect(queryItems.contains(where: { $0.name == "scope" }))
    }
}
