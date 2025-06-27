//
//  DevLogger.swift
//  Limit
//
//  Created by Zdenek Indra on 20.05.2025.
//

import Foundation
import SwiftUI


@Observable
final class DevLogger {
    static let shared = DevLogger()
    
    private(set) var logs: [String] = []
    
    func log(_ message: String) {
        let timestamp = DateFormatterCache.shared.logTimestampFormatter.string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        logs.append(entry)
        print(entry)
    }
    
    func clear() {
        logs.removeAll()
    }
}
