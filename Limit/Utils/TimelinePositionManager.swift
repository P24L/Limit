//
//  TimelinePositionManager.swift
//  Limit
//
//  Created by Zdenek Indra on 29.06.2025.
//

import Foundation

@MainActor
class TimelinePositionManager {
    static let shared = TimelinePositionManager()
    
    private let userDefaults = UserDefaults.standard
    private let timelineKey = "LastTopVisiblePostID_timeline"
    
    private init() {}
    
    // MARK: - Timeline Position
    func saveTimelinePosition(_ postID: String) {
        userDefaults.set(postID, forKey: timelineKey)
    }
    
    func getTimelinePosition() -> String? {
        return userDefaults.string(forKey: timelineKey)
    }
    
    // MARK: - List Position
    func saveListPosition(_ postID: String, for listURI: String) {
        let key = "LastTopVisiblePostID_\(listURI)"
        userDefaults.set(postID, forKey: key)
    }
    
    func getListPosition(for listURI: String) -> String? {
        let key = "LastTopVisiblePostID_\(listURI)"
        return userDefaults.string(forKey: key)
    }
    
    // MARK: - Generic Position (pro budoucí rozšíření)
    func savePosition(_ postID: String, for identifier: String) {
        let key = "LastTopVisiblePostID_\(identifier)"
        userDefaults.set(postID, forKey: key)
    }
    
    func getPosition(for identifier: String) -> String? {
        let key = "LastTopVisiblePostID_\(identifier)"
        return userDefaults.string(forKey: key)
    }
    
    // MARK: - Cleanup
    func clearAllPositions() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix("LastTopVisiblePostID_") {
            userDefaults.removeObject(forKey: key)
        }
    }
}