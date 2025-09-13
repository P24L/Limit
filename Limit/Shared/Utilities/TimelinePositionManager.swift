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
    
    // In-memory cache for positions
    private var positionCache: [String: String] = [:]
    
    // Track which keys have pending changes
    private var pendingChanges: Set<String> = []
    
    // Debounce task for delayed saves
    private var debounceTask: Task<Void, Never>?
    
    // Debounce interval (2 seconds)
    private let debounceInterval: TimeInterval = 2.0
    
    private init() {
        loadInitialPositions()
    }
    
    // MARK: - Initial Load
    private func loadInitialPositions() {
        // Load all existing positions from UserDefaults into memory cache
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix("LastTopVisiblePostID_") {
            if let value = userDefaults.string(forKey: key) {
                positionCache[key] = value
            }
        }
        DevLogger.shared.log("TimelinePositionManager - Loaded \(positionCache.count) positions into memory cache")
    }
    
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
        let key = timelineKey()
        
        // Immediately save to memory cache
        positionCache[key] = postID
        pendingChanges.insert(key)
        
        DevLogger.shared.log("TimelinePositionManager - Cached position: \(postID) for key: \(key)")
        
        // Schedule debounced save to UserDefaults
        scheduleDebouncedSave()
    }
    
    func getTimelinePosition() -> String? {
        let key = timelineKey()
        
        // Read from memory cache first
        if let cached = positionCache[key] {
            DevLogger.shared.log("TimelinePositionManager - Getting cached position: \(cached) for key: \(key)")
            return cached
        }
        
        // Fallback to UserDefaults (shouldn't happen after initial load)
        let position = userDefaults.string(forKey: key)
        if let position {
            positionCache[key] = position // Update cache
            DevLogger.shared.log("TimelinePositionManager - Getting position from UserDefaults: \(position) for key: \(key)")
        }
        return position
    }
    
    // MARK: - List Position
    func saveListPosition(_ postID: String, for listURI: String) {
        let key = listKey(for: listURI)
        
        // Immediately save to memory cache
        positionCache[key] = postID
        pendingChanges.insert(key)
        
        DevLogger.shared.log("TimelinePositionManager - Cached list position: \(postID) for key: \(key)")
        
        // Schedule debounced save to UserDefaults
        scheduleDebouncedSave()
    }
    
    func getListPosition(for listURI: String) -> String? {
        let key = listKey(for: listURI)
        
        // Read from memory cache first
        if let cached = positionCache[key] {
            return cached
        }
        
        // Fallback to UserDefaults
        let position = userDefaults.string(forKey: key)
        if let position {
            positionCache[key] = position // Update cache
        }
        return position
    }
    
    // MARK: - Generic Position (pro budoucí rozšíření)
    func savePosition(_ postID: String, for identifier: String) {
        let did = AccountManager.shared.currentAccount?.did ?? "default"
        let key = "LastTopVisiblePostID_\(identifier).\(did)"
        
        // Immediately save to memory cache
        positionCache[key] = postID
        pendingChanges.insert(key)
        
        // Schedule debounced save to UserDefaults
        scheduleDebouncedSave()
    }
    
    func getPosition(for identifier: String) -> String? {
        let did = AccountManager.shared.currentAccount?.did ?? "default"
        let key = "LastTopVisiblePostID_\(identifier).\(did)"
        
        // Read from memory cache first
        if let cached = positionCache[key] {
            return cached
        }
        
        // Fallback to UserDefaults
        let position = userDefaults.string(forKey: key)
        if let position {
            positionCache[key] = position // Update cache
        }
        return position
    }
    
    // MARK: - Debounced Save
    private func scheduleDebouncedSave() {
        // Cancel existing task
        debounceTask?.cancel()
        
        // Create new debounced task
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(self?.debounceInterval ?? 2.0) * 1_000_000_000)
                
                // Check if task wasn't cancelled
                if !Task.isCancelled {
                    self?.flushPendingChanges()
                }
            } catch {
                // Task was cancelled, ignore
            }
        }
    }
    
    // MARK: - Flush Changes
    func flushPendingChanges() {
        guard !pendingChanges.isEmpty else { return }
        
        DevLogger.shared.log("TimelinePositionManager - Flushing \(pendingChanges.count) pending changes to UserDefaults")
        
        for key in pendingChanges {
            if let value = positionCache[key] {
                userDefaults.set(value, forKey: key)
            }
        }
        
        pendingChanges.removeAll()
        
        // Cancel any pending debounce task
        debounceTask?.cancel()
        debounceTask = nil
    }
    
    // MARK: - Cleanup
    func clearAllPositions() {
        // Clear memory cache
        positionCache.removeAll()
        pendingChanges.removeAll()
        debounceTask?.cancel()
        
        // Clear UserDefaults
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix("LastTopVisiblePostID_") {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    // MARK: - Account-specific cleanup
    func clearPositionsForAccount(_ accountDID: String) {
        let suffix = ".\(accountDID)"
        
        // Clear from memory cache
        positionCache = positionCache.filter { !$0.key.hasPrefix("LastTopVisiblePostID_") || !$0.key.hasSuffix(suffix) }
        
        // Clear from pending changes
        pendingChanges = pendingChanges.filter { !$0.hasPrefix("LastTopVisiblePostID_") || !$0.hasSuffix(suffix) }
        
        // Clear from UserDefaults
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix("LastTopVisiblePostID_") && key.hasSuffix(suffix) {
            userDefaults.removeObject(forKey: key)
        }
    }
}