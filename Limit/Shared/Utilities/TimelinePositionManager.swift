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
    private let timelineKeyPrefix = "LastTopVisiblePostID_timeline"
    
    private init() {}
    
    // MARK: - Account-aware keys
    private func timelineKey(for accountDID: String? = nil) -> String {
        let did = accountDID ?? AccountManager.shared.currentAccount?.did ?? "default"
        return "\(timelineKeyPrefix).\(did)"
    }
    
    private func listKey(for listURI: String, accountDID: String? = nil) -> String {
        let did = accountDID ?? AccountManager.shared.currentAccount?.did ?? "default"
        return "LastTopVisiblePostID_\(listURI).\(did)"
    }
    
    // MARK: - Timeline Position
    func saveTimelinePosition(_ postID: String) {
        userDefaults.set(postID, forKey: timelineKey())
    }
    
    func getTimelinePosition() -> String? {
        return userDefaults.string(forKey: timelineKey())
    }
    
    // MARK: - List Position
    func saveListPosition(_ postID: String, for listURI: String) {
        userDefaults.set(postID, forKey: listKey(for: listURI))
    }
    
    func getListPosition(for listURI: String) -> String? {
        return userDefaults.string(forKey: listKey(for: listURI))
    }
    
    // MARK: - Generic Position (pro budoucí rozšíření)
    func savePosition(_ postID: String, for identifier: String) {
        let did = AccountManager.shared.currentAccount?.did ?? "default"
        let key = "LastTopVisiblePostID_\(identifier).\(did)"
        userDefaults.set(postID, forKey: key)
    }
    
    func getPosition(for identifier: String) -> String? {
        let did = AccountManager.shared.currentAccount?.did ?? "default"
        let key = "LastTopVisiblePostID_\(identifier).\(did)"
        return userDefaults.string(forKey: key)
    }
    
    // MARK: - Cleanup
    func clearAllPositions() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix("LastTopVisiblePostID_") {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    // MARK: - Account-specific cleanup
    func clearPositionsForAccount(_ accountDID: String) {
        let keys = userDefaults.dictionaryRepresentation().keys
        let suffix = ".\(accountDID)"
        for key in keys where key.hasPrefix("LastTopVisiblePostID_") && key.hasSuffix(suffix) {
            userDefaults.removeObject(forKey: key)
        }
    }
}