//
//  XeroAuthService.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import CryptoKit
import Foundation

struct AppConfiguration {
    static let shared = AppConfiguration()

    let xeroClientID: String
    let xeroRedirectURI: URL
    let railwayBaseURL: URL?
    let xeroScopes: [String]

    init(
        xeroClientID: String = ProcessInfo.processInfo.environment["XERO_CLIENT_ID"] ?? "",
        xeroRedirectURI: URL = URL(string: ProcessInfo.processInfo.environment["XERO_REDIRECT_URI"] ?? "jeniusai://xero/callback")!,
        railwayBaseURL: URL? = ProcessInfo.processInfo.environment["RAILWAY_BASE_URL"].flatMap(URL.init(string:)),
        xeroScopes: [String] = ["openid", "profile", "email", "offline_access", "accounting.transactions"]
    ) {
        self.xeroClientID = xeroClientID
        self.xeroRedirectURI = xeroRedirectURI
        self.railwayBaseURL = railwayBaseURL
        self.xeroScopes = xeroScopes
    }
}

struct XeroAuthResult: Codable {
    let tenantName: String?
    let message: String
}

enum XeroAuthError: LocalizedError {
    case missingClientID
    case missingVerifier
    case invalidCallback
    case missingCode

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Set `XERO_CLIENT_ID` before starting the Xero login flow."
        case .missingVerifier:
            return "The PKCE verifier is missing. Restart the Xero login flow."
        case .invalidCallback:
            return "The callback URL was not recognised."
        case .missingCode:
            return "Xero returned without an authorization code."
        }
    }
}

final class XeroAuthService {
    private let configuration: AppConfiguration
    private let urlSession: URLSession
    private let defaults: UserDefaults
    private let verifierKey = "xero.pkce.verifier"
    private let stateKey = "xero.pkce.state"
    private let sessionKey = "xero.session.result"

    init(
        configuration: AppConfiguration = .shared,
        urlSession: URLSession = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.defaults = defaults
    }

    func authorizationURL() throws -> URL {
        guard configuration.xeroClientID.isEmpty == false else {
            throw XeroAuthError.missingClientID
        }

        let verifier = Self.randomString(length: 64)
        let challenge = Self.codeChallenge(from: verifier)
        let state = UUID().uuidString

        defaults.set(verifier, forKey: verifierKey)
        defaults.set(state, forKey: stateKey)

        var components = URLComponents(string: "https://login.xero.com/identity/connect/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.xeroClientID),
            URLQueryItem(name: "redirect_uri", value: configuration.xeroRedirectURI.absoluteString),
            URLQueryItem(name: "scope", value: configuration.xeroScopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        return components?.url ?? configuration.xeroRedirectURI
    }

    func handleCallback(_ url: URL) async throws -> XeroAuthResult {
        let callbackPrefix = configuration.xeroRedirectURI.absoluteString.components(separatedBy: "?").first ?? configuration.xeroRedirectURI.absoluteString
        guard url.absoluteString.hasPrefix(callbackPrefix) else {
            throw XeroAuthError.invalidCallback
        }

        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw XeroAuthError.missingCode
        }

        guard let verifier = defaults.string(forKey: verifierKey) else {
            throw XeroAuthError.missingVerifier
        }

        let expectedState = defaults.string(forKey: stateKey)
        let callbackState = components.queryItems?.first(where: { $0.name == "state" })?.value
        if expectedState != nil, callbackState != expectedState {
            throw XeroAuthError.invalidCallback
        }

        let result = try await exchangeCode(code: code, verifier: verifier)
        if let data = try? JSONEncoder().encode(result) {
            defaults.set(data, forKey: sessionKey)
        }
        defaults.removeObject(forKey: verifierKey)
        defaults.removeObject(forKey: stateKey)
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
        defaults.removeObject(forKey: verifierKey)
        defaults.removeObject(forKey: stateKey)
        defaults.removeObject(forKey: sessionKey)
    }

    private func exchangeCode(code: String, verifier: String) async throws -> XeroAuthResult {
        guard let baseURL = configuration.railwayBaseURL else {
            return XeroAuthResult(
                tenantName: nil,
                message: "Xero returned a code successfully. Set `RAILWAY_BASE_URL` and implement `/auth/xero/exchange` to complete the login."
            )
        }

        var request = URLRequest(url: baseURL.appending(path: "auth/xero/exchange"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(XeroExchangeRequest(
            code: code,
            codeVerifier: verifier,
            redirectURI: configuration.xeroRedirectURI.absoluteString
        ))

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            return XeroAuthResult(tenantName: nil, message: message)
        }

        if let result = try? JSONDecoder().decode(XeroAuthResult.self, from: data) {
            return result
        }

        return XeroAuthResult(tenantName: nil, message: "Backend connected to Xero.")
    }

    private static func randomString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private static func codeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct XeroExchangeRequest: Codable {
    let code: String
    let codeVerifier: String
    let redirectURI: String
}
