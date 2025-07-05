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
    
    // MARK: - Batch loading for infinity scroll
    private(set) var nextBatchPosts: [TimelinePostWrapper] = []
    private(set) var isPreparingNextBatch = false
    
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
        
        // Start preparing next batch after loading initial posts
        prepareNextBatch(client: client)
        
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
        
        // Start preparing next batch after refresh
        prepareNextBatch(client: client)
        
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
        
        // Start preparing next batch after refresh
        prepareNextBatch(client: client)
        
        isLoading = false
    }
    
    /// Prepares the session cache in background without blocking UI
    func prepareSessionCacheInBackground(client: BlueskyClient) async {
        // Check cache state on main actor
        let shouldProceed = await MainActor.run {
            // Don't start another background task if we already have valid cache
            guard !sessionCacheValid || sessionCachedPosts.isEmpty else {
                DevLogger.shared.log("ComputedTimelineFeed - prepareSessionCacheInBackground - cache already valid")
                return false
            }
            
            // Don't start if already loading
            guard !isLoading else {
                DevLogger.shared.log("ComputedTimelineFeed - prepareSessionCacheInBackground - already loading")
                return false
            }
            
            DevLogger.shared.log("ComputedTimelineFeed - prepareSessionCacheInBackground - starting background preparation")
            return true
        }
        
        guard shouldProceed else { return }
        
        await client.login()
        let result = await client.getCachedOrRefreshHotPosts()
        
        await MainActor.run {
            // Only update if we don't have valid cache yet
            if !self.sessionCacheValid || self.sessionCachedPosts.isEmpty {
                self.sessionCachedPosts = result
                self.sessionCacheValid = true
                DevLogger.shared.log("ComputedTimelineFeed - prepareSessionCacheInBackground - cached \(result.count) posts")
            }
        }
    }
    
    /// Loads more posts for infinity scroll - adds next batch and prepares another
    func loadMorePosts(client: BlueskyClient) async {
        guard !nextBatchPosts.isEmpty else {
            // If no batch ready, start preparing one
            prepareNextBatch(client: client)
            return
        }
        
        // Add prepared posts to main list
        posts.append(contentsOf: nextBatchPosts)
        
        // Clear the next batch
        nextBatchPosts = []
        
        // Start preparing another batch
        prepareNextBatch(client: client)
    }
    
    /// Prepares next batch of posts in background for infinity scroll
    private func prepareNextBatch(client: BlueskyClient) {
        // Don't start if already preparing
        guard !isPreparingNextBatch else { return }
        
        // Don't prepare if we already have next batch ready
        guard nextBatchPosts.isEmpty else { return }
        
        // Set preparing state synchronously so UI can react immediately
        isPreparingNextBatch = true
        
        Task.detached { [weak self] in
            guard let self else { return }
            
            await client.login()
            // Generate fresh hot posts instead of using cached ones
            let result = await client.fetchHotPosts()
            
            await MainActor.run {
                // Only update if we don't have next batch yet
                if self.nextBatchPosts.isEmpty {
                    self.nextBatchPosts = result
                }
                self.isPreparingNextBatch = false
            }
        }
    }
    
    /// Clears the session state (call when user logs out or app starts fresh)
    func clearSession() {
        posts = []
        nextBatchPosts = []
        isPreparingNextBatch = false
        hasLoadedInSession = false
        lastLoadTime = nil
        error = nil
        isLoading = false
        sessionCachedPosts = []
        sessionCacheValid = false
        DevLogger.shared.log("ComputedTimelineFeed - session cleared")
    }
}