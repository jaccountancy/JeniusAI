//
//  AppModel.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import Foundation
import Observation
import SwiftUI
import SwiftData

enum NavigationSection: String, CaseIterable, Identifiable {
    case dashboard
    case folders
    case workflows
    case inbox
    case people
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .folders:
            return "Folders"
        case .workflows:
            return "Workflows"
        case .inbox:
            return "Inbox"
        case .people:
            return "People"
        case .settings:
            return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard:
            return "house"
        case .folders:
            return "folder"
        case .workflows:
            return "point.3.connected.trianglepath.dotted"
        case .inbox:
            return "tray"
        case .people:
            return "person.2"
        case .settings:
            return "gearshape"
        }
    }
}

struct WorkspaceItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let iconName: String
}

struct Shortcut: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
}

struct SetupStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isComplete: Bool
}

enum XeroConnectionStatus: String {
    case disconnected
    case connecting
    case connected
    case failed

    var label: String {
        switch self {
        case .disconnected:
            return "Xero not connected"
        case .connecting:
            return "Waiting for Xero"
        case .connected:
            return "Xero connected"
        case .failed:
            return "Xero connection issue"
        }
    }

    var symbolName: String {
        switch self {
        case .disconnected:
            return "bolt.horizontal.circle"
        case .connecting:
            return "ellipsis.circle"
        case .connected:
            return "checkmark.seal.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .disconnected:
            return .orange
        case .connecting:
            return .blue
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}

struct XeroConnection {
    var status: XeroConnectionStatus = .disconnected
    var tenantName: String?
    var lastMessage: String?
}

enum LoginEventType: String {
    case launch
    case loginStarted
    case loginSucceeded
    case loginFailed
    case sessionRestored
    case sessionCleared

    var title: String {
        switch self {
        case .launch:
            return "App launch"
        case .loginStarted:
            return "Login started"
        case .loginSucceeded:
            return "Login succeeded"
        case .loginFailed:
            return "Login failed"
        case .sessionRestored:
            return "Session restored"
        case .sessionCleared:
            return "Session cleared"
        }
    }
}

@Observable
@MainActor
final class AppModel {
    var selectedSection: NavigationSection = .dashboard
    var xeroConnection = XeroConnection()
    var isRestoring = true

    let recentItems: [WorkspaceItem] = [
        WorkspaceItem(title: "Year-end accounts pack", subtitle: "Personal Folders", iconName: "doc.text"),
        WorkspaceItem(title: "VAT evidence bundle", subtitle: "Shared Folders", iconName: "folder"),
        WorkspaceItem(title: "Payroll approvals April", subtitle: "Inbox", iconName: "tray.full")
    ]

    let shortcuts: [Shortcut] = [
        Shortcut(title: "Share Files", iconName: "square.and.arrow.up"),
        Shortcut(title: "Request Files", iconName: "arrow.down.doc"),
        Shortcut(title: "Create Client", iconName: "person.badge.plus"),
        Shortcut(title: "Personal Folders", iconName: "folder"),
        Shortcut(title: "Shared Folders", iconName: "person.3"),
        Shortcut(title: "Favorites", iconName: "star")
    ]

    let folderItems: [WorkspaceItem] = [
        WorkspaceItem(title: "Client Accounts", subtitle: "Working papers, ledgers and signed statements.", iconName: "folder"),
        WorkspaceItem(title: "Bookkeeping Intake", subtitle: "Uploads from clients, bank exports and source documents.", iconName: "tray.and.arrow.down"),
        WorkspaceItem(title: "Compliance Archive", subtitle: "Tax, payroll and confirmation history.", iconName: "archivebox")
    ]

    let workflowItems: [WorkspaceItem] = [
        WorkspaceItem(title: "Onboarding Runbook", subtitle: "Capture authority, connect Xero and collect prior records.", iconName: "checklist"),
        WorkspaceItem(title: "Month-End Close", subtitle: "Review feeds, reconcile balances and issue management pack.", iconName: "calendar"),
        WorkspaceItem(title: "Approval Routing", subtitle: "Partner sign-off for payroll, VAT and submissions.", iconName: "person.text.rectangle")
    ]

    let inboxItems: [WorkspaceItem] = [
        WorkspaceItem(title: "Unsorted Uploads", subtitle: "14 items pending classification.", iconName: "tray"),
        WorkspaceItem(title: "Integration Alerts", subtitle: "Xero sync results and token health warnings.", iconName: "bell"),
        WorkspaceItem(title: "Client Questions", subtitle: "Waiting on bookkeeping clarifications.", iconName: "message")
    ]

    let peopleItems: [WorkspaceItem] = [
        WorkspaceItem(title: "James Wilson", subtitle: "Administrator", iconName: "person.crop.circle"),
        WorkspaceItem(title: "Blue Horizon Team", subtitle: "Internal operations and delivery.", iconName: "person.3.sequence"),
        WorkspaceItem(title: "Xero Organisations", subtitle: "Connected tenants will appear here.", iconName: "building.2")
    ]

    let backendRecommendations: [String] = [
        "Use Railway for `/auth/xero/start` and `/auth/xero/callback`, with server-side token storage and tenant discovery.",
        "Store tokens server-side only; keep the iOS app limited to session state and display data.",
        "Expose a compact dashboard API for workspaces, recent activity and workflow counts."
    ]

    var setupSteps: [SetupStep] {
        [
            SetupStep(title: "Front-end navigation shell", detail: "Dashboard, sidebar, responsive layout and settings panel are implemented in SwiftUI.", isComplete: true),
            SetupStep(title: "Xero sign-in trigger", detail: "The app opens Railway, which starts Xero auth and returns to the app by deep link.", isComplete: true),
            SetupStep(title: "Railway callback flow", detail: "Set Xero to call Railway at `/auth/xero/callback` so the backend can exchange tokens securely.", isComplete: AppConfiguration.shared.railwayBaseURL != nil),
            SetupStep(title: "Persistent audit trail", detail: "Login status, history and session metadata are saved locally in SwiftData.", isComplete: true)
        ]
    }

    private let xeroAuthService = XeroAuthService()

    var requiresAuthentication: Bool {
        isRestoring || xeroConnection.status != .connected
    }

    func beginXeroLogin(using modelContext: ModelContext) throws -> URL {
        xeroConnection.status = .connecting
        xeroConnection.lastMessage = "Opening Xero sign-in..."
        persistSession(using: modelContext)
        appendHistory(.loginStarted, message: "Started Xero sign-in flow.", tenantName: nil, using: modelContext)
        return try xeroAuthService.authorizationURL()
    }

    func handleIncomingURL(_ url: URL, using modelContext: ModelContext) async {
        do {
            let result = try await xeroAuthService.handleCallback(url)
            xeroConnection.status = .connected
            xeroConnection.tenantName = result.tenantName
            xeroConnection.lastMessage = result.message
            selectedSection = .settings
            persistSession(using: modelContext)
            appendHistory(.loginSucceeded, message: result.message, tenantName: result.tenantName, using: modelContext)
        } catch {
            xeroConnection.status = .failed
            xeroConnection.lastMessage = error.localizedDescription
            selectedSection = .settings
            persistSession(using: modelContext)
            appendHistory(.loginFailed, message: error.localizedDescription, tenantName: nil, using: modelContext)
        }
    }

    func restoreConnection(using modelContext: ModelContext) async {
        appendHistory(.launch, message: "App launched.", tenantName: nil, using: modelContext)

        if let session = fetchSession(using: modelContext) {
            xeroConnection.status = XeroConnectionStatus(rawValue: session.statusRawValue) ?? .disconnected
            xeroConnection.tenantName = session.tenantName
            xeroConnection.lastMessage = session.lastMessage

            if xeroConnection.status == .connected {
                appendHistory(.sessionRestored, message: session.lastMessage ?? "Restored persisted Xero session.", tenantName: session.tenantName, using: modelContext)
            }
            isRestoring = false
            return
        }

        if let restored = xeroAuthService.restoreSession() {
            xeroConnection.status = .connected
            xeroConnection.tenantName = restored.tenantName
            xeroConnection.lastMessage = restored.message
            persistSession(using: modelContext)
            appendHistory(.sessionRestored, message: restored.message, tenantName: restored.tenantName, using: modelContext)
        }
        isRestoring = false
    }

    func clearConnection(using modelContext: ModelContext) {
        xeroAuthService.clearSession()
        xeroConnection = XeroConnection(status: .disconnected, tenantName: nil, lastMessage: "Connection reset. Ready to start again.")
        persistSession(using: modelContext)
        appendHistory(.sessionCleared, message: "Session cleared by user.", tenantName: nil, using: modelContext)
    }

    func setXeroFailure(_ message: String, using modelContext: ModelContext) {
        xeroConnection.status = .failed
        xeroConnection.lastMessage = message
        persistSession(using: modelContext)
        appendHistory(.loginFailed, message: message, tenantName: nil, using: modelContext)
    }

    private func fetchSession(using modelContext: ModelContext) -> PersistedSession? {
        let descriptor = FetchDescriptor<PersistedSession>(
            predicate: #Predicate<PersistedSession> { $0.key == "primary" }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func persistSession(using modelContext: ModelContext) {
        let session = fetchSession(using: modelContext) ?? {
            let newSession = PersistedSession()
            modelContext.insert(newSession)
            return newSession
        }()

        session.statusRawValue = xeroConnection.status.rawValue
        session.tenantName = xeroConnection.tenantName
        session.lastMessage = xeroConnection.lastMessage
        session.lastUpdatedAt = .now
        session.lastAuthenticatedAt = xeroConnection.status == .connected ? .now : session.lastAuthenticatedAt

        try? modelContext.save()
    }

    private func appendHistory(_ eventType: LoginEventType, message: String, tenantName: String?, using modelContext: ModelContext) {
        modelContext.insert(LoginHistoryRecord(
            eventTypeRawValue: eventType.rawValue,
            message: message,
            tenantName: tenantName
        ))
        try? modelContext.save()
    }
}
