//
//  DashboardDataService.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import Foundation

struct DashboardSnapshot: Decodable {
    let tenantName: String?
    let backendStatus: String
    let databaseStatus: String
    let xeroConnected: Bool
    let ignitionConnected: Bool
    let metrics: DashboardMetrics
    let supportPrompts: [SupportPromptData]
    let feed: [SupportFeedData]
    let syncStatus: SyncStatus
}

struct DashboardMetrics: Decodable {
    let revenue: String
    let receivables: String
    let margin: String
    let invoiceQueue: String
    let meetingsClosed: String
    let tasksCompleted: String
    let clientHealth: String
    let approvedCount: String
    let declinedCount: String
    let cashflowAverage: String
    let cashflowPeak: String
    let assessments: String
    let finalisations: String
    let approvals: String
}

struct SupportPromptData: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tone: String
}

struct SupportFeedData: Decodable, Identifiable {
    let id: String
    let name: String
    let text: String
    let time: String
}

struct SyncStatus: Decodable {
    let ignitionClientsCount: Int
    let ignitionInvoicesCount: Int
    let latestAuditMessage: String?
}

enum DashboardDataError: LocalizedError {
    case missingBackend
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingBackend:
            return "Missing Railway backend URL."
        case .invalidResponse:
            return "The backend returned an invalid dashboard response."
        }
    }
}

final class DashboardDataService {
    private let configuration: AppConfiguration
    private let session: URLSession

    init(
        configuration: AppConfiguration = .shared,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func fetchDashboard() async throws -> DashboardSnapshot {
        guard let baseURL = configuration.railwayBaseURL else {
            throw DashboardDataError.missingBackend
        }

        let url = baseURL.appending(path: "api/dashboard")
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw DashboardDataError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(DashboardSnapshot.self, from: data)
        } catch {
            throw DashboardDataError.invalidResponse
        }
    }
}
