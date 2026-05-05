//
//  Item.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import Foundation
import SwiftData

@Model
final class PersistedSession {
    @Attribute(.unique) var key: String
    var statusRawValue: String
    var tenantName: String?
    var lastMessage: String?
    var lastUpdatedAt: Date
    var lastAuthenticatedAt: Date?

    init(
        key: String = "primary",
        statusRawValue: String = XeroConnectionStatus.disconnected.rawValue,
        tenantName: String? = nil,
        lastMessage: String? = nil,
        lastUpdatedAt: Date = .now,
        lastAuthenticatedAt: Date? = nil
    ) {
        self.key = key
        self.statusRawValue = statusRawValue
        self.tenantName = tenantName
        self.lastMessage = lastMessage
        self.lastUpdatedAt = lastUpdatedAt
        self.lastAuthenticatedAt = lastAuthenticatedAt
    }
}

@Model
final class LoginHistoryRecord {
    var timestamp: Date
    var eventTypeRawValue: String
    var message: String
    var tenantName: String?

    init(
        timestamp: Date = .now,
        eventTypeRawValue: String,
        message: String,
        tenantName: String? = nil
    ) {
        self.timestamp = timestamp
        self.eventTypeRawValue = eventTypeRawValue
        self.message = message
        self.tenantName = tenantName
    }
}
