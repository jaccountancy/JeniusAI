//
//  Item.swift
//  JeniusAI
//
//  Created by Jay Wilson on 05/05/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
