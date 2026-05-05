//
//  AppModel.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import Foundation
import Observation
import SwiftUI

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

@Observable
final class AppModel {
    var selectedSection: NavigationSection = .dashboard
    var xeroConnection = XeroConnection()

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
        "Use Railway for `/auth/xero/exchange`, refresh-token rotation and tenant discovery.",
        "Store tokens server-side only; keep the iOS app limited to session state and display data.",
        "Expose a compact dashboard API for workspaces, recent activity and workflow counts."
    ]

    var setupSteps: [SetupStep] {
        [
            SetupStep(title: "Front-end navigation shell", detail: "Dashboard, sidebar, responsive layout and settings panel are implemented in SwiftUI.", isComplete: true),
            SetupStep(title: "Xero sign-in trigger", detail: "The app can start the OAuth flow and listen for the callback URL.", isComplete: true),
            SetupStep(title: "Railway token exchange", detail: "Wire your backend endpoint so the app can trade the code for a secure server-side session.", isComplete: AppConfiguration.shared.railwayBaseURL != nil),
            SetupStep(title: "Live workspace data", detail: "Replace static sample content with API-backed folders, workflows and alerts.", isComplete: false)
        ]
    }

    private let xeroAuthService = XeroAuthService()

    func beginXeroLogin() throws -> URL {
        xeroConnection.status = .connecting
        xeroConnection.lastMessage = "Opening Xero sign-in..."
        return try xeroAuthService.authorizationURL()
    }

    func handleIncomingURL(_ url: URL) async {
        do {
            let result = try await xeroAuthService.handleCallback(url)
            xeroConnection.status = .connected
            xeroConnection.tenantName = result.tenantName
            xeroConnection.lastMessage = result.message
            selectedSection = .settings
        } catch {
            xeroConnection.status = .failed
            xeroConnection.lastMessage = error.localizedDescription
            selectedSection = .settings
        }
    }

    func restoreConnection() async {
        if let restored = xeroAuthService.restoreSession() {
            xeroConnection.status = .connected
            xeroConnection.tenantName = restored.tenantName
            xeroConnection.lastMessage = restored.message
        }
    }

    func clearConnection() {
        xeroAuthService.clearSession()
        xeroConnection = XeroConnection(status: .disconnected, tenantName: nil, lastMessage: "Connection reset. Ready to start again.")
    }

    func setXeroFailure(_ message: String) {
        xeroConnection.status = .failed
        xeroConnection.lastMessage = message
    }
}
