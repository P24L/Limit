//
//  ComputedTimelineFeed.swift
//  Limit
//
//  Created by Claude on 03.07.2025.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ComputedTimelineFeed {
    
    // MARK: - State
    private(set) var posts: [TimelinePostWrapper] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var lastLoadTime: Date?
    
    // Track if we've loaded posts in this session to avoid unnecessary reloads
    private var hasLoadedInSession = false
    
    // MARK: - Session-level cache for navigation persistence
    private var sessionCachedPosts: [TimelinePostWrapper] = []
    private var sessionCacheValid = false
    
    // MARK: - Public Methods
    
    /// Loads computed timeline posts. Won't reload if already loaded in session unless forced.
    func loadPosts(client: BlueskyClient, forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        
        // If we already have posts and it's not a force refresh, don't reload
        if !forceRefresh && !posts.isEmpty && hasLoadedInSession {
            DevLogger.shared.log("ComputedTimelineFeed - loadPosts - using existing session data")
            return
        }
        
        // Check session cache first
        if !forceRefresh && sessionCacheValid && !sessionCachedPosts.isEmpty {
            DevLogger.shared.log("ComputedTimelineFeed - loadPosts - using session cache")
            posts = sessionCachedPosts
            hasLoadedInSession = true
            return
        }
        
        isLoading = true
        error = nil
        
        await client.login()
        
        let result = await client.getCachedOrRefreshHotPosts()
        
        posts = result
        lastLoadTime = Date()
        hasLoadedInSession = true
        error = nil
        
        // Store in session cache
        if !sessionCacheValid {
            sessionCachedPosts = result
            sessionCacheValid = true
            DevLogger.shared.log("ComputedTimelineFeed - loadPosts - stored in session cache")
        }
        
        DevLogger.shared.log("ComputedTimelineFeed - loadPosts - loaded \(result.count) posts")
        
        isLoading = false
    }
    
    /// Fast refresh: immediately shows available posts, generates new ones in background
    func fastRefresh(client: BlueskyClient) async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        await client.login()
        
        // Try to get cached posts immediately
        let result = await client.getCachedOrRefreshHotPosts()
        
        posts = result
        lastLoadTime = Date()
        hasLoadedInSession = true
        error = nil
        
        // Update session cache with current posts
        sessionCachedPosts = result
        sessionCacheValid = true
        
        // Start background refresh for next time
        client.prepareHotPostCacheInBackground()
        
        DevLogger.shared.log("ComputedTimelineFeed - fastRefresh - loaded \(result.count) posts")
        
        isLoading = false
    }
    
    /// Forces a refresh of computed timeline posts, invalidating session cache
    func refresh(client: BlueskyClient) async {
        guard !isLoading else { return }
        
        DevLogger.shared.log("ComputedTimelineFeed - refresh - invalidating session cache")
        sessionCacheValid = false
        sessionCachedPosts = []
        
        isLoading = true
        error = nil
        
        await client.login()
        
        // Force fresh fetch by using maxAge=0
        let result = await client.getCachedOrRefreshHotPosts(maxAge: 0)
        
        posts = result
        lastLoadTime = Date()
        hasLoadedInSession = true
        error = nil
        
        // Store new results in session cache
        sessionCachedPosts = result
        sessionCacheValid = true
        
        DevLogger.shared.log("ComputedTimelineFeed - refresh - refreshed with \(result.count) posts")
        
        isLoading = false
    }
    
    /// Clears the session state (call when user logs out or app starts fresh)
    func clearSession() {
        posts = []
        hasLoadedInSession = false
        lastLoadTime = nil
        error = nil
        isLoading = false
        sessionCachedPosts = []
        sessionCacheValid = false
        DevLogger.shared.log("ComputedTimelineFeed - session cleared")
    }
}