//
//  XeroAuthService.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import Foundation

struct AppConfiguration {
    static let shared = AppConfiguration()

    let railwayBaseURL: URL?
    let appCallbackURI: URL

    init(
        railwayBaseURL: URL? = ProcessInfo.processInfo.environment["RAILWAY_BASE_URL"].flatMap(URL.init(string:)),
        appCallbackURI: URL = URL(string: ProcessInfo.processInfo.environment["APP_CALLBACK_URI"] ?? "jeniusai://xero/callback")!
    ) {
        self.railwayBaseURL = railwayBaseURL
        self.appCallbackURI = appCallbackURI
    }

    var xeroWebRedirectURI: URL? {
        railwayBaseURL?.appending(path: "auth/xero/callback")
    }
}

struct XeroAuthResult: Codable {
    let tenantName: String?
    let message: String
}

enum XeroAuthError: LocalizedError {
    case missingBackend
    case invalidCallback
    case callbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingBackend:
            return "Set `RAILWAY_BASE_URL` before starting the Xero login flow."
        case .invalidCallback:
            return "The callback URL was not recognised."
        case .callbackFailed(let message):
            return message
        }
    }
}

final class XeroAuthService {
    private let configuration: AppConfiguration
    private let defaults: UserDefaults
    private let sessionKey = "xero.session.result"

    init(
        configuration: AppConfiguration = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.defaults = defaults
    }

    func authorizationURL() throws -> URL {
        guard let baseURL = configuration.railwayBaseURL else {
            throw XeroAuthError.missingBackend
        }

        var components = URLComponents(url: baseURL.appending(path: "auth/xero/start"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "app_callback", value: configuration.appCallbackURI.absoluteString)
        ]

        guard let url = components?.url else {
            throw XeroAuthError.missingBackend
        }

        return url
    }

    func handleCallback(_ url: URL) async throws -> XeroAuthResult {
        let callbackPrefix = configuration.appCallbackURI.absoluteString.components(separatedBy: "?").first ?? configuration.appCallbackURI.absoluteString
        guard url.absoluteString.hasPrefix(callbackPrefix) else {
            throw XeroAuthError.invalidCallback
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw XeroAuthError.invalidCallback
        }

        let status = components.queryItems?.first(where: { $0.name == "status" })?.value ?? "error"
        let message = components.queryItems?.first(where: { $0.name == "message" })?.value ?? "Xero did not return a result."
        let tenantName = components.queryItems?.first(where: { $0.name == "tenant_name" })?.value

        if status != "success" {
            throw XeroAuthError.callbackFailed(message)
        }

        let result = XeroAuthResult(tenantName: tenantName, message: message)
        if let data = try? JSONEncoder().encode(result) {
            defaults.set(data, forKey: sessionKey)
        }
        return result
    }

    func restoreSession() -> XeroAuthResult? {
        guard
            let data = defaults.data(forKey: sessionKey),
            let result = try? JSONDecoder().decode(XeroAuthResult.self, from: data)
        else {
            return nil
        }
        return result
    }

    func clearSession() {
        defaults.removeObject(forKey: sessionKey)
    }
}
