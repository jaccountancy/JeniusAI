//
//  ContentView.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LoginHistoryRecord.timestamp, order: .reverse) private var loginHistory: [LoginHistoryRecord]
    @State private var appModel = AppModel()

    var body: some View {
        ZStack {
            AppBackground()

            if appModel.requiresAuthentication {
                LoginGateView(appModel: $appModel)
            } else {
                AuthenticatedShell(appModel: $appModel, loginHistory: loginHistory)
            }
        }
        .preferredColorScheme(.light)
        .task {
            await appModel.restoreConnection(using: modelContext)
        }
        .onOpenURL { url in
            Task {
                await appModel.handleIncomingURL(url, using: modelContext)
            }
        }
    }
}

private struct AuthenticatedShell: View {
    @Binding var appModel: AppModel
    let loginHistory: [LoginHistoryRecord]

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 1200

            VStack(spacing: 20) {
                BrowserBar(appModel: $appModel)
                CommandHeader(appModel: $appModel)

                if isCompact {
                    ScrollView {
                        VStack(spacing: 18) {
                            MainContent(appModel: $appModel, loginHistory: loginHistory, isCompact: true)
                            SupportRail()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        MainContent(appModel: $appModel, loginHistory: loginHistory, isCompact: false)
                            .frame(maxWidth: .infinity)

                        SupportRail()
                            .frame(width: min(geometry.size.width * 0.28, 360))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .padding(18)
        }
    }
}

private struct BrowserBar: View {
    @Binding var appModel: AppModel

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1.0, green: 0.72, blue: 0.52)).frame(width: 10, height: 10)
                Circle().fill(Color(red: 1.0, green: 0.86, blue: 0.50)).frame(width: 10, height: 10)
                Circle().fill(Color(red: 0.43, green: 0.84, blue: 0.49)).frame(width: 10, height: 10)
            }

            Image("JaccountancyBlueHorizontal_1")
                .resizable()
                .scaledToFit()
                .frame(width: 180)

            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Search client, invoice, conversation")
                Spacer()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(red: 0.55, green: 0.57, blue: 0.64))
            .padding(.horizontal, 16)
            .frame(maxWidth: 320)
            .frame(height: 40)
            .background(Color.white.opacity(0.84), in: Capsule())

            Spacer()

            HStack(spacing: 10) {
                ToolbarGlyph(symbol: "clock.arrow.circlepath")
                ToolbarGlyph(symbol: "square.and.arrow.up")
                ToolbarGlyph(symbol: "plus")
                ToolbarGlyph(symbol: "square.on.square")
            }

            ConnectionPill(connection: appModel.xeroConnection)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        }
    }
}

private struct CommandHeader: View {
    @Binding var appModel: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Jenius Command")
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.16))

                Text("Xero-first practice command centre for synced financial activity, client operations and internal coordination.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0.44, green: 0.46, blue: 0.54))
            }

            Spacer()

            HStack(spacing: 10) {
                CapsuleAction(title: "AI plugins")
                CapsuleAction(title: "Export PDF")
                CapsuleAction(title: "Sync Xero", filled: true)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct MainContent: View {
    @Binding var appModel: AppModel
    let loginHistory: [LoginHistoryRecord]
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TopNavigation(selectedSection: $appModel.selectedSection)

            switch appModel.selectedSection {
            case .dashboard:
                DashboardView(appModel: $appModel, isCompact: isCompact)
            case .folders:
                ClientWorkspaceView(items: appModel.folderItems)
            case .workflows:
                OperationsView(items: appModel.workflowItems)
            case .inbox:
                CommunicationView(items: appModel.inboxItems)
            case .people:
                TeamView(items: appModel.peopleItems)
            case .settings:
                SettingsView(appModel: $appModel, loginHistory: loginHistory)
            }
        }
    }
}

private struct DashboardView: View {
    @Binding var appModel: AppModel
    let isCompact: Bool

    private let trendBars: [Double] = [0.38, 0.58, 0.42, 0.76, 0.50, 0.70, 0.62, 0.82, 0.56, 0.88, 0.64, 0.92]
    private let trendBarsSecondary: [Double] = [0.28, 0.48, 0.34, 0.61, 0.39, 0.57, 0.44, 0.65, 0.41, 0.72, 0.49, 0.75]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if isCompact {
                VStack(spacing: 18) {
                    MainRatesCard(trendBars: trendBars, trendBarsSecondary: trendBarsSecondary)
                    PositionCard()
                    LowerMetricsGrid()
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    MainRatesCard(trendBars: trendBars, trendBarsSecondary: trendBarsSecondary)
                        .frame(maxWidth: .infinity)

                    PositionCard()
                        .frame(width: 292)
                }

                LowerMetricsGrid()
            }
        }
    }
}

private struct MainRatesCard: View {
    let trendBars: [Double]
    let trendBarsSecondary: [Double]

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Xero Sync Snapshot")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.16))
                        Text("Updated from your connected Xero organisation")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.58, green: 0.60, blue: 0.67))
                    }

                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.63, green: 0.66, blue: 0.73))
                }

                HStack(spacing: 26) {
                    StatColumn(title: "Revenue", value: "£68.4k", delta: "+12%")
                    StatColumn(title: "Receivables", value: "£17.5k", delta: "-4%")
                    StatColumn(title: "Margin", value: "31.8%", delta: "+2.5%")
                }

                TrendChart(primary: trendBars, secondary: trendBarsSecondary)
            }
        }
    }
}

private struct PositionCard: View {
    private let metrics: [(String, String, String)] = [
        ("Invoice Queue", "24", "+6"),
        ("Meetings Closed", "12", "+2"),
        ("Tasks Completed", "41", "+9"),
        ("Client Health", "88%", "+4")
    ]

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Position")
                            .font(.system(size: 21, weight: .semibold))
                        Text("Live company activity")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.58, green: 0.60, blue: 0.67))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.63, green: 0.66, blue: 0.73))
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("#24")
                        .font(.system(size: 42, weight: .medium, design: .rounded))
                    Text("Top tier")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.59, green: 0.54, blue: 0.99))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.94, green: 0.92, blue: 1.0), in: Capsule())
                }

                VStack(spacing: 12) {
                    ForEach(metrics, id: \.0) { metric in
                        HStack {
                            Text(metric.0)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(red: 0.30, green: 0.32, blue: 0.38))
                            Spacer()
                            Text(metric.1)
                                .font(.system(size: 22, weight: .medium))
                            Text(metric.2)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(red: 0.61, green: 0.56, blue: 0.98))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private struct LowerMetricsGrid: View {
    var body: some View {
        HStack(spacing: 18) {
            MetricMiniCard(
                title: "Rate Submissions",
                subtitle: "This month",
                primaryValue: "38",
                primaryLabel: "Approved",
                secondaryValue: "5",
                secondaryLabel: "Declined",
                accent: .coral
            )

            MetricMiniCard(
                title: "Cashflow Trends",
                subtitle: "This month",
                primaryValue: "44",
                primaryLabel: "Average",
                secondaryValue: "10",
                secondaryLabel: "Highest",
                accent: .violet
            )

            GaugeCard()
        }
    }
}

private struct ClientWorkspaceView: View {
    let items: [WorkspaceItem]

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Client command space", subtitle: "A softer client overview layout replacing the old file-list approach.")
                ForEach(items) { item in
                    SoftListRow(item: item)
                }
            }
        }
    }
}

private struct OperationsView: View {
    let items: [WorkspaceItem]

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Operations stream", subtitle: "Workflow visibility and synced finance actions in a card-based run queue.")
                ForEach(items) { item in
                    SoftListRow(item: item)
                }
            }
        }
    }
}

private struct CommunicationView: View {
    let items: [WorkspaceItem]

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Communication desk", subtitle: "Inbox, alerts and client prompts collected in a single conversational feed.")
                ForEach(items) { item in
                    SoftListRow(item: item)
                }
            }
        }
    }
}

private struct TeamView: View {
    let items: [WorkspaceItem]

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "People and entities", subtitle: "Internal team, client-side contacts and connected organisations.")
                ForEach(items) { item in
                    SoftListRow(item: item)
                }
            }
        }
    }
}

private struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Binding var appModel: AppModel
    let loginHistory: [LoginHistoryRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelCard {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "Integration control", subtitle: "Session state, callback wiring and persistent audit trail.")

                    HStack(spacing: 24) {
                        LabeledValue(label: "Status", value: appModel.xeroConnection.status.label, tint: appModel.xeroConnection.status.tint)
                        LabeledValue(label: "Tenant", value: appModel.xeroConnection.tenantName ?? "Awaiting sync")
                        LabeledValue(label: "Railway", value: AppConfiguration.shared.railwayBaseURL?.host() ?? "Not configured")
                    }

                    if let message = appModel.xeroConnection.lastMessage {
                        Text(message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.50, green: 0.53, blue: 0.60))
                    }

                    HStack(spacing: 12) {
                        Button {
                            connectToXero()
                        } label: {
                            Label("Re-authenticate", systemImage: "arrow.clockwise.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button {
                            appModel.clearConnection(using: modelContext)
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }

            PanelCard {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "Login history", subtitle: "Persisted auth events in the local database.")
                    ForEach(loginHistory.prefix(8)) { record in
                        LoginHistoryRow(record: record)
                    }
                }
            }
        }
    }

    private func connectToXero() {
        do {
            let url = try appModel.beginXeroLogin(using: modelContext)
            openURL(url)
        } catch {
            appModel.setXeroFailure(error.localizedDescription, using: modelContext)
        }
    }
}

private struct SupportRail: View {
    private let prompts: [SupportPrompt] = [
        .init(title: "Cashflow", subtitle: "What changed in receivables this week?", tint: .violet),
        .init(title: "Forecast", subtitle: "Show likely payment slippage risks", tint: .coral),
        .init(title: "Actions", subtitle: "Summarise clients needing follow-up", tint: .gold)
    ]

    private let feed: [SupportFeedMessage] = [
        .init(name: "Ethan Caldwell", text: "What changed in overdue invoices for this quarter?", time: "20, 10:16"),
        .init(name: "Lucas Bennett", text: "Rates vary by client, tax status and renewal stage.", time: "20, 10:20"),
        .init(name: "Sophia Monroe", text: "Check these accounts matching your billing priorities below.", time: "22, 10:22")
    ]

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    HStack(spacing: 10) {
                        ChatTab(title: "Forum chats", tint: .coral, isActive: true)
                        ChatTab(title: "Loan Talk", tint: .violet, isActive: false)
                    }
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.70, green: 0.72, blue: 0.78))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Get quick answers here")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.64, green: 0.66, blue: 0.72))
                    Text("Support and guidance here!")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.11, green: 0.12, blue: 0.16))
                }

                HStack(spacing: 10) {
                    ForEach(prompts) { prompt in
                        SupportPromptCard(prompt: prompt)
                    }
                }

                Divider()
                    .overlay(Color(red: 0.93, green: 0.94, blue: 0.97))

                VStack(spacing: 16) {
                    ForEach(feed) { message in
                        SupportFeedRow(message: message)
                    }
                }

                HStack(spacing: 10) {
                    ComposerTool(title: "Files")
                    ComposerTool(title: "Images")
                    ComposerTool(title: "Audio Chat")
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.37, green: 0.39, blue: 0.46))

                HStack {
                    Text("Create a post to share the news")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.67, green: 0.69, blue: 0.75))
                    Spacer()
                    Image(systemName: "paperplane")
                        .foregroundStyle(Color(red: 0.63, green: 0.65, blue: 0.72))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(red: 0.98, green: 0.98, blue: 1.0), in: Capsule())
            }
        }
    }
}

private struct TopNavigation: View {
    @Binding var selectedSection: NavigationSection

    var body: some View {
        HStack(spacing: 10) {
            ToolbarGlyph(symbol: "magnifyingglass")
            ToolbarGlyph(symbol: "calendar")

            ForEach(NavigationSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Text(section.commandTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selectedSection == section ? Color(red: 0.12, green: 0.13, blue: 0.18) : Color(red: 0.54, green: 0.56, blue: 0.62))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            selectedSection == section
                                ? Color.white
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            NotificationDot()
            NotificationDot()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(.white.opacity(0.5), in: Capsule())
    }
}

private struct LoginGateView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Binding var appModel: AppModel

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 1100

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 26) {
                    Image("JaccountancyBlueHorizontal_1")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240)

                    Text("Jenius Command")
                        .font(.system(size: 54, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.16))

                    Text("A rethought, Xero-first practice command centre. Sign in with Xero to unlock the synced dashboard, live finance panels and persistent audit trail.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.43, green: 0.45, blue: 0.52))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        InfoChip(title: "Login Gate", value: "Xero required")
                        InfoChip(title: "Persistence", value: "SwiftData enabled")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if let message = appModel.xeroConnection.lastMessage {
                            Text(message)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(appModel.xeroConnection.status.tint)
                        }

                        Button {
                            connectToXero()
                        } label: {
                            Label("Login with Xero", systemImage: "link.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                    .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isCompact {
                    LoginPreviewSurface()
                        .frame(width: min(geometry.size.width * 0.46, 620), height: 520)
                }
            }
            .padding(40)
        }
    }

    private func connectToXero() {
        do {
            let url = try appModel.beginXeroLogin(using: modelContext)
            openURL(url)
        } catch {
            appModel.setXeroFailure(error.localizedDescription, using: modelContext)
        }
    }
}

private struct LoginPreviewSurface: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.88),
                            Color(red: 0.96, green: 0.95, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(Color(red: 1.0, green: 0.72, blue: 0.52)).frame(width: 9, height: 9)
                        Circle().fill(Color(red: 1.0, green: 0.86, blue: 0.50)).frame(width: 9, height: 9)
                        Circle().fill(Color(red: 0.43, green: 0.84, blue: 0.49)).frame(width: 9, height: 9)
                    }
                    Spacer()
                }

                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Mortgage Command")
                                    .font(.system(size: 26, weight: .medium, design: .rounded))
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.98, green: 0.98, blue: 1.0))
                                    .frame(height: 220)
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.9))
                                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.9))
                                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.9))
                                }
                                .frame(height: 140)
                            }
                            .padding(24)
                        }

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .frame(width: 210)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Support and guidance here!")
                                    .font(.system(size: 24, weight: .medium, design: .rounded))
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(red: 0.92, green: 0.88, blue: 1.0))
                                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(red: 1.0, green: 0.88, blue: 0.84))
                                }
                                .frame(height: 74)
                                Spacer()
                            }
                            .padding(20)
                        }
                }
            }
            .padding(22)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 18)
    }
}

private struct PanelCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.16))
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.58, green: 0.60, blue: 0.67))
        }
    }
}

private struct SoftListRow: View {
    let item: WorkspaceItem

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.95, green: 0.95, blue: 1.0))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: item.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.53, green: 0.47, blue: 0.98))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(item.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.52, green: 0.54, blue: 0.60))
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .foregroundStyle(Color(red: 0.68, green: 0.70, blue: 0.76))
        }
        .padding(16)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct StatColumn: View {
    let title: String
    let value: String
    let delta: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.58, green: 0.60, blue: 0.67))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.17))
                Text(delta)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.97, green: 0.56, blue: 0.58))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 1.0, green: 0.91, blue: 0.92), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrendChart: View {
    let primary: [Double]
    let secondary: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(primary.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: 3) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(red: 0.78, green: 0.75, blue: 1.0))
                            .frame(width: 5, height: 120 * value)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(red: 1.0, green: 0.63, blue: 0.59))
                            .frame(width: 5, height: 120 * secondary[index])
                    }
                    Text(shortMonth(index))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.62, green: 0.64, blue: 0.70))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 160, alignment: .bottom)
    }

    private func shortMonth(_ index: Int) -> String {
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][index]
    }
}

private struct MetricMiniCard: View {
    let title: String
    let subtitle: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let accent: AccentTone

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 20, weight: .semibold))
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.58, green: 0.60, blue: 0.67))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(Color(red: 0.68, green: 0.70, blue: 0.76))
                }

                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryValue)
                            .font(.system(size: 38, weight: .medium, design: .rounded))
                        Text(primaryLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.60, green: 0.62, blue: 0.69))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(secondaryValue)
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                        Text(secondaryLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.60, green: 0.62, blue: 0.69))
                    }
                }

                AccentScale(accent: accent)
            }
        }
    }
}

private struct GaugeCard: View {
    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Conditional Liabilities")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Active")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.58, green: 0.60, blue: 0.67))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(Color(red: 0.68, green: 0.70, blue: 0.76))
                }

                HStack(spacing: 18) {
                    SmallMetric(value: "10", title: "Assessment")
                    SmallMetric(value: "24", title: "Finalisation")
                    SmallMetric(value: "5", title: "Approval")
                }

                ZStack {
                    Circle()
                        .trim(from: 0.12, to: 0.88)
                        .stroke(Color(red: 0.93, green: 0.93, blue: 0.98), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(180))

                    Circle()
                        .trim(from: 0.12, to: 0.68)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.65, blue: 0.60),
                                    Color(red: 0.81, green: 0.79, blue: 1.0)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(180))

                    VStack(spacing: 4) {
                        Text("85%")
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                        Text("Confidence")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.58, green: 0.60, blue: 0.67))
                    }
                }
                .frame(height: 170)
            }
        }
    }
}

private struct SmallMetric: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 32, weight: .medium, design: .rounded))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.60, green: 0.62, blue: 0.69))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AccentScale: View {
    let accent: AccentTone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0.94, green: 0.95, blue: 0.98))

                    Capsule()
                        .fill(accent.lineGradient)
                        .frame(width: geometry.size.width * accent.fill)
                }
            }
            .frame(height: 4)

            HStack {
                ForEach(accent.labels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.62, green: 0.64, blue: 0.70))
                    Spacer()
                }
            }
        }
    }
}

private struct SupportPrompt: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let tint: AccentTone
}

private struct SupportPromptCard: View {
    let prompt: SupportPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prompt.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text(prompt.subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(prompt.tint.cardGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SupportFeedMessage: Identifiable {
    let id = UUID()
    let name: String
    let text: String
    let time: String
}

private struct SupportFeedRow: View {
    let message: SupportFeedMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.76, blue: 0.63), Color(red: 0.86, green: 0.94, blue: 0.73)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 34)
                .overlay {
                    Text(String(message.name.prefix(1)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(message.name)
                    .font(.system(size: 14, weight: .semibold))
                Text(message.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.42, green: 0.44, blue: 0.51))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Image(systemName: "link")
                    Image(systemName: "heart")
                    Image(systemName: "scribble")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.71, green: 0.72, blue: 0.79))
            }

            Spacer()

            Text(message.time)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.66, green: 0.68, blue: 0.74))
        }
    }
}

private struct ToolbarGlyph: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(red: 0.44, green: 0.46, blue: 0.53))
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.74), in: Circle())
    }
}

private struct ConnectionPill: View {
    let connection: XeroConnection

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connection.status.tint)
                .frame(width: 8, height: 8)
            Text(connection.tenantName ?? connection.status.label)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.18))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.78), in: Capsule())
    }
}

private struct NotificationDot: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)
            Circle()
                .fill(Color(red: 1.0, green: 0.62, blue: 0.62))
                .frame(width: 14, height: 14)
        }
    }
}

private struct ChatTab: View {
    let title: String
    let tint: AccentTone
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint.lineGradient)
                .frame(width: 24, height: 24)
                .overlay {
                    Text(isActive ? "1" : "2")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(isActive ? 0.9 : 0.5), in: Capsule())
    }
}

private struct ComposerTool: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: title == "Audio Chat" ? "mic" : "doc")
            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.75), in: Capsule())
    }
}

private struct InfoChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.59, green: 0.61, blue: 0.68))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.18))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CapsuleAction: View {
    let title: String
    var filled = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(filled ? .white : Color(red: 0.45, green: 0.47, blue: 0.54))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                filled
                    ? Color(red: 0.56, green: 0.54, blue: 0.99)
                    : Color.white.opacity(0.78),
                in: Capsule()
            )
    }
}

private struct LoginHistoryRow: View {
    let record: LoginHistoryRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LoginEventType(rawValue: record.eventTypeRawValue)?.title ?? record.eventTypeRawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
                Text(record.message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.50, green: 0.53, blue: 0.60))
            }
            Spacer()
            Text(record.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.64, green: 0.66, blue: 0.72))
        }
        .padding(14)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String
    var tint: Color = Color(red: 0.12, green: 0.13, blue: 0.18)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.61, green: 0.63, blue: 0.69))
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.58, green: 0.53, blue: 0.99),
                        Color(red: 0.40, green: 0.68, blue: 0.99)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.20))
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.94, blue: 1.0),
                    Color(red: 0.98, green: 0.97, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.90, green: 0.88, blue: 1.0).opacity(0.55))
                .frame(width: 460, height: 460)
                .blur(radius: 80)
                .offset(x: -260, y: -220)

            Circle()
                .fill(Color(red: 1.0, green: 0.92, blue: 0.91).opacity(0.55))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 320, y: -180)
        }
    }
}

private enum AccentTone {
    case coral
    case violet
    case gold

    var lineGradient: LinearGradient {
        switch self {
        case .coral:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.63, blue: 0.60), Color(red: 0.99, green: 0.77, blue: 0.56)], startPoint: .leading, endPoint: .trailing)
        case .violet:
            return LinearGradient(colors: [Color(red: 0.72, green: 0.70, blue: 1.0), Color(red: 0.54, green: 0.50, blue: 0.98)], startPoint: .leading, endPoint: .trailing)
        case .gold:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.83, blue: 0.58), Color(red: 1.0, green: 0.68, blue: 0.48)], startPoint: .leading, endPoint: .trailing)
        }
    }

    var cardGradient: LinearGradient {
        switch self {
        case .coral:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.82), Color(red: 0.99, green: 0.69, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .violet:
            return LinearGradient(colors: [Color(red: 0.91, green: 0.88, blue: 1.0), Color(red: 0.77, green: 0.73, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gold:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.92, blue: 0.79), Color(red: 0.98, green: 0.78, blue: 0.64)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var fill: CGFloat {
        switch self {
        case .coral:
            return 0.38
        case .violet:
            return 0.52
        case .gold:
            return 0.68
        }
    }

    var labels: [String] {
        switch self {
        case .coral:
            return ["Processing", "Lender", "Submission"]
        case .violet:
            return ["Borrower", "Rate Adjustments", "Planning Reviews"]
        case .gold:
            return ["Assessment", "Allocation", "Confidence"]
        }
    }
}

private extension NavigationSection {
    var commandTitle: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .folders:
            return "Clients"
        case .workflows:
            return "Operations"
        case .inbox:
            return "Communication"
        case .people:
            return "Growth Hub"
        case .settings:
            return "Control"
        }
    }
}

#Preview {
    ContentView()
}
