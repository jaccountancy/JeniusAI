//
//  ContentView.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var appModel = AppModel()

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.98)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let isCompact = geometry.size.width < 940

                    if isCompact {
                        VStack(spacing: 0) {
                            TopBar(connectionStatus: appModel.xeroConnection.status, isCompact: true)
                            Picker("Section", selection: $appModel.selectedSection) {
                                ForEach(NavigationSection.allCases) { section in
                                    Text(section.title).tag(section)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white)

                            SectionDetailView(appModel: $appModel, isCompact: true)
                        }
                    } else {
                        VStack(spacing: 0) {
                            TopBar(connectionStatus: appModel.xeroConnection.status, isCompact: false)

                            HStack(spacing: 0) {
                                Sidebar(selectedSection: $appModel.selectedSection)
                                    .frame(width: 255)

                                SectionDetailView(appModel: $appModel, isCompact: false)
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .task {
            await appModel.restoreConnection()
        }
        .onOpenURL { url in
            Task {
                await appModel.handleIncomingURL(url)
            }
        }
    }
}

private struct TopBar: View {
    let connectionStatus: XeroConnectionStatus
    let isCompact: Bool

    var body: some View {
        HStack(spacing: 18) {
            Image("JaccountancyBlueHorizontal_1")
                .resizable()
                .scaledToFit()
                .frame(width: isCompact ? 170 : 220)

            Spacer()

            if !isCompact {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.secondary)
                    Text("Search files")
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .frame(width: 240, height: 34)
                .background(Color.white, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color(red: 0.80, green: 0.83, blue: 0.89), lineWidth: 1)
                }

                Spacer()
            }

            HStack(spacing: 18) {
                Text("Help")
                Text("Apps")
                Text("Log Out")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(red: 0.37, green: 0.39, blue: 0.44))

            HStack(spacing: 8) {
                Image(systemName: connectionStatus.symbolName)
                Text(connectionStatus.label)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(connectionStatus.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red: 0.96, green: 0.98, blue: 1.0), in: Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.25, green: 0.50, blue: 0.95))
                .frame(height: 2)
        }
    }
}

private struct Sidebar: View {
    @Binding var selectedSection: NavigationSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 4) {
                ForEach(NavigationSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.iconName)
                                .frame(width: 18)
                            Text(section.title)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if selectedSection == section {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .foregroundStyle(selectedSection == section ? Color(red: 0.12, green: 0.16, blue: 0.25) : Color(red: 0.40, green: 0.43, blue: 0.49))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(selectedSection == section ? Color(red: 0.96, green: 0.97, blue: 1.0) : .clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 22)

            Spacer()

            InfoTile(
                title: "Phase 1 Focus",
                message: "Navigation, structure, auth entry point and backend handoff are prepared.",
                accent: Color(red: 0.31, green: 0.42, blue: 0.63)
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(red: 0.89, green: 0.91, blue: 0.94))
                .frame(width: 1)
        }
    }
}

private struct SectionDetailView: View {
    @Binding var appModel: AppModel
    let isCompact: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch appModel.selectedSection {
                case .dashboard:
                    DashboardView(appModel: $appModel, isCompact: isCompact)
                case .folders:
                    WorkspaceListView(
                        title: "Folders",
                        subtitle: "Document collections for accounts, payroll, tax and client delivery.",
                        items: appModel.folderItems
                    )
                case .workflows:
                    WorkspaceListView(
                        title: "Automated Workflows",
                        subtitle: "Operational flows styled to match the ShareFile workflow table.",
                        items: appModel.workflowItems
                    )
                case .inbox:
                    WorkspaceListView(
                        title: "Inbox",
                        subtitle: "Shared intake for uploads, approvals and integration messages.",
                        items: appModel.inboxItems
                    )
                case .people:
                    WorkspaceListView(
                        title: "People",
                        subtitle: "Team members, clients and external finance systems connected to the workspace.",
                        items: appModel.peopleItems
                    )
                case .settings:
                    SettingsView(appModel: $appModel)
                }
            }
            .padding(24)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
    }
}

private struct DashboardView: View {
    @Binding var appModel: AppModel
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeroPanel()

            if isCompact {
                VStack(alignment: .leading, spacing: 20) {
                    CardPanel(title: "Recent Files and Folders", subtitle: "Modeled after the ShareFile dashboard pattern.") {
                        VStack(spacing: 12) {
                            ForEach(appModel.recentItems) { item in
                                RecentRow(item: item)
                            }
                        }
                    }

                    CardPanel(title: "Shortcuts", subtitle: "Fast actions for common operating tasks.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(appModel.shortcuts) { shortcut in
                                ShortcutCell(shortcut: shortcut)
                            }
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    CardPanel(title: "Recent Files and Folders", subtitle: "Modeled after the ShareFile dashboard pattern.") {
                        VStack(spacing: 12) {
                            ForEach(appModel.recentItems) { item in
                                RecentRow(item: item)
                            }
                        }
                    }

                    CardPanel(title: "Shortcuts", subtitle: "Fast actions for common operating tasks.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(appModel.shortcuts) { shortcut in
                                ShortcutCell(shortcut: shortcut)
                            }
                        }
                    }
                }
            }

            CardPanel(title: "Quick Setup", subtitle: "Backend and integration readiness, inspired by the GitHub onboarding panel.") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(appModel.setupSteps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(step.isComplete ? Color.green : Color(red: 0.18, green: 0.47, blue: 0.82))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
                                Text(step.detail)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

private struct HeroPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hello James")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color(red: 0.18, green: 0.20, blue: 0.24))

            Text("A first-round finance operations shell that combines dashboard navigation, client workspaces and Xero connection entry points.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.44, green: 0.47, blue: 0.53))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label("Client hubs", systemImage: "folder")
                Label("Workflow control", systemImage: "point.3.connected.trianglepath.dotted")
                Label("Xero ready", systemImage: "link")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(red: 0.21, green: 0.43, blue: 0.86))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.white)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.90, green: 0.92, blue: 0.95))
                .frame(height: 1)
        }
    }
}

private struct WorkspaceListView: View {
    let title: String
    let subtitle: String
    let items: [WorkspaceItem]

    var body: some View {
        CardPanel(title: title, subtitle: subtitle) {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.76))
                            .frame(width: 34, height: 34)
                            .background(Color(red: 0.91, green: 0.96, blue: 1.0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
                            Text(item.subtitle)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(red: 0.92, green: 0.93, blue: 0.95), lineWidth: 1)
                    }
                }
            }
        }
    }
}

private struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Binding var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CardPanel(title: "Xero Integration", subtitle: "OAuth entry point with Railway exchange handoff.") {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledValue(label: "Status", value: appModel.xeroConnection.status.label, tint: appModel.xeroConnection.status.tint)
                    LabeledValue(label: "App Callback", value: AppConfiguration.shared.appCallbackURI.absoluteString)
                    LabeledValue(label: "Xero Web Redirect", value: AppConfiguration.shared.xeroWebRedirectURI?.absoluteString ?? "Set `RAILWAY_BASE_URL` to generate the Railway callback")
                    LabeledValue(label: "Railway Backend", value: AppConfiguration.shared.railwayBaseURL?.absoluteString ?? "Not configured")

                    if let message = appModel.xeroConnection.lastMessage {
                        Text(message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            connectToXero()
                        } label: {
                            Label("Login with Xero", systemImage: "link.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button {
                            appModel.clearConnection()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }

            CardPanel(title: "Backend Setup", subtitle: "Recommended service boundaries for the next Railway deployment.") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appModel.backendRecommendations, id: \.self) { item in
                        Label(item, systemImage: "server.rack")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.22))
                    }
                }
            }
        }
    }
}

private extension SettingsView {
    func connectToXero() {
        do {
            let url = try appModel.beginXeroLogin()
            openURL(url)
        } catch {
            appModel.setXeroFailure(error.localizedDescription)
        }
    }
}

private struct CardPanel<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.22, blue: 0.26))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
        )
    }
}

private struct InfoTile: View {
    let title: String
    let message: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.84))
        }
        .padding(16)
        .background(accent.opacity(0.92), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct RecentRow: View {
    let item: WorkspaceItem

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.95, green: 0.76, blue: 0.22))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: item.iconName)
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .bold))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
                Text(item.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.92, blue: 0.95), lineWidth: 1)
        }
    }
}

private struct ShortcutCell: View {
    let shortcut: Shortcut

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: shortcut.iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.13, green: 0.58, blue: 0.32))
                .frame(width: 56, height: 56)
                .background(Color(red: 0.94, green: 0.98, blue: 0.94), in: Circle())

            Text(shortcut.title)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.92, blue: 0.95), lineWidth: 1)
        }
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String
    var tint: Color = Color(red: 0.08, green: 0.12, blue: 0.20)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .textSelection(.enabled)
        }
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Color(red: 0.10, green: 0.50, blue: 0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
            .background(Color(red: 0.92, green: 0.95, blue: 0.98), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

#Preview {
    ContentView()
}
