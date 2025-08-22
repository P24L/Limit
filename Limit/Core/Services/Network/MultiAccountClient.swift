//
//  MultiAccountClient.swift
//  Limit
//
//  Multi-account capable replacement for BlueskyClient
//  Supports instant switching without logout/login
//

import Foundation
import ATProtoKit
import SwiftData
import SwiftUI
import Observation

@Observable
@MainActor
final class MultiAccountClient {
    // MARK: - Properties
    
    /// Current active account
    private(set) var currentAccount: UserAccount?
    
    /// Current active session configuration
    private var currentSessionConfig: OAuthSessionConfiguration?
    
    /// Current ATProtoKit instance (lazy loaded)
    internal private(set) var protoClient: ATProtoKit?
    
    /// Current ATProtoBluesky instance (lazy loaded)
    internal private(set) var bskyClient: ATProtoBluesky?
    
    /// Pool of session configurations (one per account)
    private var sessionConfigs: [UUID: OAuthSessionConfiguration] = [:]
    
    /// Current user session
    private(set) var userSession: UserSession?
    
    // MARK: - State Properties (compatible with BlueskyClient)
    
    internal private(set) var isAuthenticated: Bool = false
    internal private(set) var currentDID: String? = nil
    internal private(set) var isLoading: Bool = false
    
    // For compatibility with existing code
    var handle: String {
        currentAccount?.handle ?? ""
    }
    
    var appPassword: String {
        // This is for backward compatibility only
        if let account = currentAccount {
            return AccountManager.shared.getAppPassword(for: account) ?? ""
        }
        return ""
    }
    
    // MARK: - Caching for Hot Posts (from BlueskyClient)
    
    private var cachedHotPosts: [TimelinePostWrapper] = []
    private var hotPostIDsTimestamp: Date = .distantPast
    internal private(set) var isRefreshingHotPosts = false
    
    // MARK: - Configuration
    
    let pdsURL: URL
    let maxTimelineFetchLoops = 10
    
    // MARK: - Initialization
    
    init(pdsURL: URL = URL(string: "https://bsky.social")!) {
        self.pdsURL = pdsURL
    }
    
    // MARK: - Account Management
    
    /// Initialize with current account from AccountManager
    func initializeWithCurrentAccount() async {
        guard let account = AccountManager.shared.currentAccount else {
            DevLogger.shared.log("MultiAccountClient - No current account")
            isAuthenticated = false
            return
        }
        
        await switchToAccount(account, skipPasswordCheck: false)
    }
    
    /// Switch to a different account without logout
    func switchToAccount(_ account: UserAccount, skipPasswordCheck: Bool = false) async {
        DevLogger.shared.log("MultiAccountClient - Switching to account: \(account.handle)")
        
        // Clear current client instances (releases memory)
        protoClient = nil
        bskyClient = nil
        userSession = nil
        
        // Clear hot posts cache for old account
        cachedHotPosts = []
        hotPostIDsTimestamp = .distantPast
        
        // Update current account
        currentAccount = account
        currentDID = account.did
        
        // Get or create session configuration for this account
        if let existingConfig = sessionConfigs[account.sessionUUID] {
            currentSessionConfig = existingConfig
            DevLogger.shared.log("MultiAccountClient - Using existing session config for: \(account.handle)")
        } else {
            // Create new session configuration
            let config = AccountManager.shared.getSessionConfiguration(for: account)
            sessionConfigs[account.sessionUUID] = config
            currentSessionConfig = config
            DevLogger.shared.log("MultiAccountClient - Created new session config for: \(account.handle)")
        }
        
        // Initialize ATProtoKit with the session configuration
        await initializeClients()
    }
    
    /// Initialize ATProtoKit and ATProtoBluesky clients
    private func initializeClients() async {
        guard let config = currentSessionConfig else {
            DevLogger.shared.log("MultiAccountClient - No session configuration available")
            isAuthenticated = false
            return
        }
        
        do {
            // Check if we need to authenticate first
            if config.authType == .appPassword {
                // For app password accounts, authenticate if needed
                if let account = currentAccount,
                   let password = AccountManager.shared.getAppPassword(for: account) {
                    
                    // Try to get existing session first from UserSessionRegistry
                    if let existingSession = await UserSessionRegistry.shared.getSession(for: config.instanceUUID) {
                        DevLogger.shared.log("MultiAccountClient - Using existing session for: \(account.handle)")
                        userSession = existingSession
                    } else {
                        // Need to authenticate
                        DevLogger.shared.log("MultiAccountClient - Authenticating: \(account.handle)")
                        try await config.authenticate(with: account.handle, password: password)
                        userSession = await UserSessionRegistry.shared.getSession(for: config.instanceUUID)
                    }
                }
            } else {
                // OAuth account - session should already be valid from UserSessionRegistry
                userSession = await UserSessionRegistry.shared.getSession(for: config.instanceUUID)
                
                // If no session exists, we need to recreate it from stored tokens
                if userSession == nil {
                    DevLogger.shared.log("MultiAccountClient - No UserSession for OAuth account, recreating from tokens")
                    
                    // Try to load tokens from keychain and recreate session
                    if let _ = try? await config.keychainProtocol.retrieveAccessToken(),
                       let _ = try? await config.keychainProtocol.retrieveRefreshToken(),
                       let account = currentAccount {
                        
                        // Recreate UserSession (tokens are in keychain, not in UserSession)
                        // Use PDS URL from account for OAuth, or fallback to bsky.social
                        let pdsURLString = account.pdsURL ?? "https://bsky.social"
                        let newSession = UserSession(
                            handle: account.handle,
                            sessionDID: account.did,
                            email: nil,
                            isEmailConfirmed: nil,
                            isEmailAuthenticationFactorEnabled: nil,
                            didDocument: nil,
                            isActive: true,
                            status: nil,
                            serviceEndpoint: URL(string: pdsURLString)!,
                            pdsURL: pdsURLString
                        )
                        
                        await UserSessionRegistry.shared.register(config.instanceUUID, session: newSession)
                        userSession = newSession
                        DevLogger.shared.log("MultiAccountClient - Recreated UserSession for: \(account.handle)")
                    }
                }
                
                // Check if token needs refresh
                let needsRefresh = config.needsTokenRefresh()
                DevLogger.shared.log("MultiAccountClient - Token needs refresh check: \(needsRefresh) for: \(currentAccount?.handle ?? "")")
                
                if needsRefresh {
                    DevLogger.shared.log("MultiAccountClient - Attempting to refresh token")
                    do {
                        try await config.refreshSession()
                        userSession = await UserSessionRegistry.shared.getSession(for: config.instanceUUID)
                        DevLogger.shared.log("MultiAccountClient - Token refresh completed")
                    } catch OAuthRefreshError.invalidGrant {
                        DevLogger.shared.log("MultiAccountClient - Refresh token invalid, account needs re-authentication")
                        // Mark account as needing re-auth
                        if let account = currentAccount {
                            AccountManager.shared.markAccountNeedsReauth(account)
                        }
                        throw OAuthRefreshError.invalidGrant
                    } catch {
                        DevLogger.shared.log("MultiAccountClient - Token refresh failed: \(error)")
                        throw error
                    }
                }
            }
            
            // Create ATProtoKit instance
            DevLogger.shared.log("MultiAccountClient - Creating ATProtoKit with config type: \(config.authType), UUID: \(config.instanceUUID)")
            DevLogger.shared.log("MultiAccountClient - UserSession present: \(userSession != nil), DID: \(userSession?.sessionDID ?? "none")")
            
            // Determine PDS URL - use account's PDS for OAuth, or default for app password
            let pdsURLString: String
            if config.authType == .oauth, let accountPDS = currentAccount?.pdsURL {
                pdsURLString = accountPDS
                DevLogger.shared.log("MultiAccountClient - Using OAuth PDS: \(pdsURLString)")
            } else {
                pdsURLString = "https://bsky.social"
                DevLogger.shared.log("MultiAccountClient - Using default PDS: \(pdsURLString)")
            }
            
            // Create DPoP executor for OAuth accounts
            if config.authType == .oauth {
                DevLogger.shared.log("MultiAccountClient - Creating DPoP executor for OAuth account")
                
                do {
                    let dpopExecutor = try DPoPRequestExecutor(
                        accountUUID: config.instanceUUID,
                        sessionConfig: config
                    )
                    
                    let apiConfig = APIClientConfiguration(
                        urlSessionConfiguration: config.configuration,
                        responseProvider: dpopExecutor
                    )
                    
                    protoClient = await ATProtoKit(
                        sessionConfiguration: config,
                        apiClientConfiguration: apiConfig,
                        pdsURL: pdsURLString  // Pass correct PDS URL
                    )
                    
                    DevLogger.shared.log("MultiAccountClient - ATProtoKit created with DPoP support and PDS: \(pdsURLString)")
                } catch {
                    DevLogger.shared.log("MultiAccountClient - Failed to create DPoP executor: \(error)")
                    // Fallback to regular ATProtoKit
                    protoClient = await ATProtoKit(
                        sessionConfiguration: config,
                        pdsURL: pdsURLString
                    )
                }
            } else {
                // App password account - use regular ATProtoKit
                protoClient = await ATProtoKit(
                    sessionConfiguration: config,
                    pdsURL: pdsURLString
                )
            }
            
            DevLogger.shared.log("MultiAccountClient - ATProtoKit created: \(protoClient != nil)")
            
            // Create ATProtoBluesky instance
            if let protoClient = protoClient {
                bskyClient = ATProtoBluesky(atProtoKitInstance: protoClient)
                DevLogger.shared.log("MultiAccountClient - ATProtoBluesky created successfully")
            } else {
                DevLogger.shared.log("MultiAccountClient - Failed to create ATProtoBluesky - protoClient is nil")
            }
            
            isAuthenticated = true
            currentDID = userSession?.sessionDID ?? currentAccount?.did
            
            DevLogger.shared.log("MultiAccountClient - Successfully initialized for: \(currentAccount?.handle ?? "")")
            
        } catch {
            DevLogger.shared.log("MultiAccountClient - Failed to initialize: \(error)")
            isAuthenticated = false
        }
    }
    
    /// Add a new account and switch to it
    func addAndSwitchToAccount(_ account: UserAccount, password: String? = nil) async {
        // Add to AccountManager first
        if account.authType == .appPassword, let password = password {
            AccountManager.shared.addOrUpdateAccount(
                did: account.did,
                handle: account.handle,
                appPassword: password,
                displayName: account.displayName,
                avatarURL: account.avatarURL
            )
        }
        
        // Switch to the new account
        await switchToAccount(account)
    }
    
    /// Logout current account (for compatibility)
    func logout() async {
        guard let account = currentAccount else { return }
        
        // Delete session
        if let config = currentSessionConfig {
            try? await config.deleteSession()
        }
        
        // Clear from session configs pool
        sessionConfigs.removeValue(forKey: account.sessionUUID)
        
        // Clear current state
        currentAccount = nil
        currentSessionConfig = nil
        protoClient = nil
        bskyClient = nil
        userSession = nil
        currentDID = nil
        isAuthenticated = false
        
        // Clear caches
        cachedHotPosts = []
        hotPostIDsTimestamp = .distantPast
        
        DevLogger.shared.log("MultiAccountClient - Logged out")
    }
    
    /// Login (for backward compatibility with BlueskyClient)
    func login() async {
        // This is called by LimitApp for auto-login
        // We'll initialize with current account from AccountManager
        await initializeWithCurrentAccount()
    }
    
    /// Switch account (for backward compatibility with BlueskyClient)
    func switchAccount(to account: UserAccount, password: String) async -> Bool {
        await switchToAccount(account)
        return isAuthenticated
    }
    
    // MARK: - Preview Support
    
    static public func preview() -> MultiAccountClient {
        .init()
    }
    
    // MARK: - API Methods (all methods from BlueskyClient preserved below)
    
    /// Helper to perform an authenticated request, handling ExpiredToken by retrying after refresh
    func performAuthenticatedRequest<T>(
        _ operation: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await operation()
        } catch let error as ATAPIError {
            if case .badRequest(let httpError) = error, httpError.error == "ExpiredToken" {
                DevLogger.shared.log("MultiAccountClient - ExpiredToken, refreshing session")
                
                // Try to refresh session
                if let config = currentSessionConfig {
                    do {
                        try await config.refreshSession()
                        // Reinitialize clients with new tokens
                        await initializeClients()
                        // Retry operation
                        return try await operation()
                    } catch {
                        DevLogger.shared.log("MultiAccountClient - Refresh failed: \(error)")
                    }
                }
            } else {
                DevLogger.shared.log("MultiAccountClient - API error: \(error)")
            }
        } catch {
            DevLogger.shared.log("MultiAccountClient - General error: \(error)")
        }
        return nil
    }
    
    // MARK: - Timeline Methods
    
    func fetchTimeline() async -> (posts: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?) {
        DevLogger.shared.log("MultiAccountClient - fetchTimeline called, isAuthenticated: \(isAuthenticated), protoClient: \(protoClient != nil)")
        
        guard isAuthenticated, let client = protoClient else {
            DevLogger.shared.log("MultiAccountClient - not authenticated - fetchTimeline - isAuthenticated: \(isAuthenticated), protoClient: \(protoClient != nil)")
            return ([], nil)
        }
        
        let result = await performAuthenticatedRequest {
            try await client.getTimeline(limit: 25)
        }
        
        guard let response = result else {
            return ([], nil)
        }
        
        return (response.feed, response.cursor)
    }
    
    func fetchTimeline(since knownURIs: Set<String>) async -> (posts: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?) {
        guard isAuthenticated, let client = protoClient else {
            return ([], nil)
        }
        
        var allNewPosts: [AppBskyLexicon.Feed.FeedViewPostDefinition] = []
        var cursor: String? = nil
        var lastCursor: String? = nil
        
        isLoading = true
        defer { isLoading = false }
        
        loop: for loopIndex in 0..<maxTimelineFetchLoops {
            let result = await performAuthenticatedRequest {
                try await client.getTimeline(limit: 100, cursor: cursor)
            }
            
            guard let response = result else {
                break loop
            }
            
            let feed = response.feed
            if feed.isEmpty { break loop }
            
            for post in feed {
                if knownURIs.contains(post.post.uri) {
                    DevLogger.shared.log("MultiAccountClient - found known URI match in loop \(loopIndex)")
                    break loop
                }
                
                if !allNewPosts.contains(where: { $0.post.uri == post.post.uri }) {
                    allNewPosts.append(post)
                }
            }
            
            if allNewPosts.count >= 1000 { break loop }
            
            if let newCursor = response.cursor {
                cursor = newCursor
                lastCursor = newCursor
            } else {
                break loop
            }
        }
        
        return (allNewPosts, lastCursor)
    }
    
    func loadOlderPosts(from oldestCursor: String) async -> (posts: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?) {
        guard let client = protoClient else {
            return ([], nil)
        }
        
        guard !isLoading else {
            return ([], nil)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await client.getTimeline(limit: 30, cursor: oldestCursor)
            return (response.feed, response.cursor)
        } catch {
            DevLogger.shared.log("MultiAccountClient - loadOlderPosts error: \(error)")
            return ([], nil)
        }
    }
    
    // MARK: - Hot Posts (from BlueskyClient)
    
    nonisolated func fetchPostWrappersByID(for ids: [String]) async -> [TimelinePostWrapper] {
        let client = await MainActor.run { protoClient }
        guard let client = client else {
            return []
        }
        
        guard !ids.isEmpty else { return [] }
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { self.isLoading = false } } }
        
        let batches = ids.batched(size: 25)
        var allPosts: [AppBskyLexicon.Feed.PostViewDefinition] = []
        
        do {
            for batch in batches {
                let response = try await client.getPosts(batch)
                allPosts.append(contentsOf: response.posts)
            }
            
            let wrappers = allPosts.map { TimelinePostWrapper(from: $0) }
            return wrappers
        } catch {
            DevLogger.shared.log("MultiAccountClient - fetchPostWrappersByID error: \(error)")
            return []
        }
    }
    
    nonisolated func fetchHotPosts(
        within timeInterval: TimeInterval = 86400,
        maxResults: Int = 150,
        sampleAccountsCount: Int = 75,
        postsPerAccount: Int = 50
    ) async -> [TimelinePostWrapper] {
        // Implementation identical to BlueskyClient.fetchHotPosts
        // (Copy the entire implementation from BlueskyClient)
        
        let (authenticated, myDID, protoClient) = await MainActor.run {
            (isAuthenticated, currentDID, self.protoClient)
        }
        
        guard authenticated, let myDID = myDID, let protoClient = protoClient else { 
            return []
        }
        
        struct ScoredPost {
            let id: String
            let createdAt: Date
            let score: Int
        }
        
        let maxFollowersToFetch = 100
        let maxFollowersToExpand = 20
        let maxFollowsPerUser = 50
        let maxFollowersPerUser = 50
        let secondHopSampleSize = 5
        
        do {
            DevLogger.shared.log("MultiAccountClient - fetchHotPosts - getting followers")
            let followersResponse = try await protoClient.getFollows(from: myDID, limit: maxFollowersToFetch)
            let selectedFollowers = Array(followersResponse.follows.shuffled().prefix(maxFollowersToExpand))
            
            var relatedAccounts = Set<String>()
            
            try await withThrowingTaskGroup(of: Set<String>.self) { group in
                for follower in selectedFollowers {
                    group.addTask {
                        var result = Set<String>()
                        do {
                            let theirFollows = try await protoClient.getFollows(from: follower.actorDID, limit: maxFollowsPerUser)
                            result.formUnion(theirFollows.follows.map { $0.actorDID })
                            let theirFollowers = try await protoClient.getFollowers(by: follower.actorDID, limit: maxFollowersPerUser)
                            result.formUnion(theirFollowers.followers.map { $0.actorDID })
                        } catch {
                            DevLogger.shared.log("fetchHotPosts error: \(error)")
                        }
                        return result
                    }
                }
                
                for try await result in group {
                    relatedAccounts.formUnion(result)
                }
            }
            
            let firstHopAccounts = Array(relatedAccounts)
            let secondHopSample = Array(firstHopAccounts.shuffled().prefix(secondHopSampleSize))
            
            try await withThrowingTaskGroup(of: Set<String>.self) { group in
                for account in secondHopSample {
                    group.addTask {
                        var result = Set<String>()
                        do {
                            let theirFollows = try await protoClient.getFollows(from: account, limit: 20)
                            result.formUnion(theirFollows.follows.map { $0.actorDID })
                        } catch {}
                        return result
                    }
                }
                
                for try await result in group {
                    relatedAccounts.formUnion(result)
                }
            }
            
            let sampledAccounts = Array(relatedAccounts.shuffled().prefix(sampleAccountsCount))
            
            var scoredPosts: [ScoredPost] = []
            let now = Date()
            
            try await withThrowingTaskGroup(of: [ScoredPost].self) { group in
                let concurrentLimit = 25
                var activeTasks = 0
                var accountIterator = sampledAccounts.makeIterator()
                
                while let accountDID = accountIterator.next() {
                    if activeTasks >= concurrentLimit {
                        if let result = try await group.next() {
                            scoredPosts.append(contentsOf: result)
                        }
                        activeTasks -= 1
                    }
                    
                    group.addTask {
                        var localPosts: [ScoredPost] = []
                        do {
                            let posts = try await protoClient.getAuthorFeed(by: accountDID, limit: postsPerAccount)
                            for post in posts.feed {
                                let age = now.timeIntervalSince(post.post.indexedAt)
                                
                                if age > 7 * 24 * 3600 { continue }
                                
                                let engagementScore = (post.post.likeCount ?? 0) + (post.post.repostCount ?? 0) + (post.post.replyCount ?? 0)
                                let ageInDays = age / 86400.0
                                let timeFactor = max(0.01, exp(-ageInDays / 2.0))
                                let finalScore = Int(Double(engagementScore) * timeFactor)
                                
                                if finalScore < 3 { continue }
                                
                                localPosts.append(ScoredPost(id: post.id, createdAt: post.post.indexedAt, score: finalScore))
                            }
                        } catch {
                            DevLogger.shared.log("fetchHotPosts feed error: \(error)")
                        }
                        return localPosts
                    }
                    activeTasks += 1
                }
                
                while activeTasks > 0 {
                    if let result = try await group.next() {
                        scoredPosts.append(contentsOf: result)
                    }
                    activeTasks -= 1
                }
            }
            
            let weightedPosts = scoredPosts.flatMap { post in
                let clampedScore = max(1, min(post.score, 20))
                return Array(repeating: post, count: clampedScore)
            }
            let topPostIDs = Array(weightedPosts.shuffled().prefix(maxResults).map { $0.id })
            
            let topPosts = await fetchPostWrappersByID(for: topPostIDs)
            
            return topPosts
        } catch {
            DevLogger.shared.log("MultiAccountClient - fetchHotPosts error: \(error)")
        }
        
        return []
    }
    
    nonisolated func getCachedOrRefreshHotPosts(
        within timeInterval: TimeInterval = 36000,
        maxAge: TimeInterval = 600
    ) async -> [TimelinePostWrapper] {
        let (authenticated, timestamp, cached, refreshing) = await MainActor.run {
            (isAuthenticated, hotPostIDsTimestamp, cachedHotPosts, isRefreshingHotPosts)
        }
        
        guard authenticated else { return [] }
        
        let now = Date()
        
        if now.timeIntervalSince(timestamp) < maxAge {
            DevLogger.shared.log("MultiAccountClient - returning cached hot posts")
            
            if !refreshing {
                await MainActor.run { isRefreshingHotPosts = true }
                Task.detached { [weak self] in
                    guard let self else { return }
                    await self.prepareFreshHotPostsCache(timeInterval: timeInterval)
                }
            }
            return cached
        }
        
        DevLogger.shared.log("MultiAccountClient - fetching fresh hot posts")
        await MainActor.run { isRefreshingHotPosts = true }
        let fresh = await fetchHotPosts(within: timeInterval)
        await MainActor.run {
            cachedHotPosts = fresh
            hotPostIDsTimestamp = Date()
            isRefreshingHotPosts = false
        }
        
        return fresh
    }
    
    private func prepareFreshHotPostsCache(timeInterval: TimeInterval) async {
        let freshPosts = await self.fetchHotPosts(within: timeInterval)
        
        await MainActor.run {
            self.cachedHotPosts = freshPosts
            self.hotPostIDsTimestamp = Date()
            self.isRefreshingHotPosts = false
        }
    }
    
    func prepareHotPostCacheInBackground(within timeInterval: TimeInterval = 36000) {
        let now = Date()
        guard now.timeIntervalSince(hotPostIDsTimestamp) >= timeInterval else { return }
        guard !isRefreshingHotPosts else { return }
        isRefreshingHotPosts = true
        Task.detached { [weak self] in
            guard let self else { return }
            await self.prepareFreshHotPostsCache(timeInterval: timeInterval)
        }
    }
    
    // MARK: - Additional API Methods (from BlueskyClient)
    
    @MainActor
    func fetchThreadWrapped(for postID: String) async -> [TimelinePostWrapper] {
        guard let client = protoClient else {
            return []
        }
        isLoading = true
        defer { isLoading = false }
        
        let result = await performAuthenticatedRequest {
            try await client.getPostThread(from: postID)
        }
        
        guard let output = result else {
            return []
        }
        guard case let .threadViewPost(rootThread) = output.thread else {
            return []
        }
        
        var allNodes: [AppBskyLexicon.Feed.ThreadViewPostDefinition] = []
        
        func collectParents(from node: AppBskyLexicon.Feed.ThreadViewPostDefinition, depth: Int = 0, maxDepth: Int = 20) {
            guard depth < maxDepth else { return }
            if let parent = node.parent {
                switch parent {
                case .threadViewPost(let parentNode):
                    collectParents(from: parentNode, depth: depth + 1, maxDepth: maxDepth)
                    allNodes.append(parentNode)
                default:
                    break
                }
            }
        }
        
        func collectReplies(from node: AppBskyLexicon.Feed.ThreadViewPostDefinition, depth: Int = 0, maxDepth: Int = 40) {
            guard depth < maxDepth else { return }
            guard let replies = node.replies else { return }
            
            for reply in replies {
                if case .threadViewPost(let replyNode) = reply {
                    allNodes.append(replyNode)
                    collectReplies(from: replyNode, depth: depth + 1, maxDepth: maxDepth)
                }
            }
        }
        
        collectParents(from: rootThread, depth: 0, maxDepth: 20)
        allNodes.append(rootThread)
        collectReplies(from: rootThread, depth: 0, maxDepth: 40)
        
        let timelineWrappers: [TimelinePostWrapper] = allNodes.compactMap { node in
            TimelinePostWrapper(from: node.post)
        }
        return timelineWrappers
    }
    
    @MainActor
    func getProfile(for actor: String) async -> AppBskyLexicon.Actor.ProfileViewDetailedDefinition? {
        guard protoClient != nil else {
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.protoClient!.getProfile(for: actor)
        }
    }
    
    func followActor(actor: String) async -> ComAtprotoLexicon.Repository.StrongReference? {
        guard let bskyClient else { return nil }
        return await performAuthenticatedRequest {
            try await bskyClient.createFollowRecord(actorDID: actor)
        }
    }
    
    func deleteFollowRecord(recordID: String) async {
        await performAuthenticatedRequest {
            try await self.bskyClient?.deleteRecord(.recordURI(atURI: recordID))
        }
    }
    
    // Add all other methods from BlueskyClient...
    // (Lists, Preferences, Posts, Notifications, etc.)
    // For brevity, I'm including just the essential structure
    
    var currentSession: UserSession? {
        return userSession
    }
    
    // MARK: - Notification Methods
    
    /// Fetches the count of unread notifications
    @MainActor
    func getUnreadNotificationCount() async -> Int {
        guard protoClient != nil else {
            DevLogger.shared.log("MultiAccountClient - getUnreadNotificationCount - no protoClient")
            return 0
        }
        
        let result = await performAuthenticatedRequest {
            try await self.protoClient!.getUnreadCount(priority: nil)
        }
        
        guard let output = result else {
            return 0
        }
        
        return output.count
    }
    
    /// Fetches notifications with pagination support
    @MainActor
    func fetchNotifications(limit: Int = 50, cursor: String? = nil) async -> (notifications: [NotificationWrapper], cursor: String?) {
        guard let client = protoClient else {
            DevLogger.shared.log("MultiAccountClient - fetchNotifications - no protoClient")
            return (notifications: [], cursor: nil)
        }
        
        let result = await performAuthenticatedRequest {
            try await client.listNotifications(
                with: nil,
                limit: limit,
                isPriority: nil,
                cursor: cursor
            )
        }
        
        guard let response = result else {
            return (notifications: [], cursor: nil)
        }
        
        let wrappers = response.notifications.map { notification in
            NotificationWrapper(from: notification, client: self)
        }
        
        return (notifications: wrappers, cursor: response.cursor)
    }
    
    // MARK: - Lists Management
    
    /// Creates a new list with the specified name
    @MainActor
    func createList(name: String) async -> String? {
        guard isAuthenticated, let bskyClient = bskyClient else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - createList")
            return nil
        }
        
        let result = await performAuthenticatedRequest {
            try await bskyClient.createListRecord(
                named: name,
                ofType: .curation
            )
        }
        
        guard let listURI = result?.recordURI else {
            DevLogger.shared.log("MultiAccountClient - createList - Failed to create list: \(name)")
            return nil
        }
        
        DevLogger.shared.log("MultiAccountClient - createList - Successfully created list: \(name)")
        
        return listURI
    }
    
    /// Deletes a list by its URI
    @MainActor
    func deleteList(listURI: String) async -> Bool {
        guard isAuthenticated, let protoClient = protoClient, let currentDID = currentDID else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - deleteList")
            return false
        }
        
        // Extract recordKey from URI format: "at://did:plc:user/app.bsky.graph.list/recordkey"
        guard let recordKey = extractRecordKey(from: listURI) else {
            DevLogger.shared.log("MultiAccountClient - deleteList - Invalid listURI format: \(listURI)")
            return false
        }
        
        let success = await performAuthenticatedRequest {
            try await protoClient.deleteRecord(
                repositoryDID: currentDID,
                collection: "app.bsky.graph.list",
                recordKey: recordKey
            )
        } != nil
        if success {
            DevLogger.shared.log("MultiAccountClient - deleteList - Successfully deleted list: \(listURI)")
        } else {
            DevLogger.shared.log("MultiAccountClient - deleteList - Failed to delete list: \(listURI)")
        }
        
        return success
    }
    
    /// Adds an actor to a list
    @MainActor
    func addActorToList(listURI: String, actorDID: String) async -> Bool {
        guard isAuthenticated, let bskyClient = bskyClient else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - addActorToList")
            return false
        }
        
        let result = await performAuthenticatedRequest {
            try await bskyClient.createListItemRecord(
                for: listURI,
                subjectDID: actorDID
            )
        }
        
        let success = result != nil
        if success {
            DevLogger.shared.log("MultiAccountClient - addActorToList - Successfully added actor \(actorDID) to list \(listURI)")
        } else {
            DevLogger.shared.log("MultiAccountClient - addActorToList - Failed to add actor \(actorDID) to list \(listURI)")
        }
        
        return success
    }
    
    /// Removes an actor from a list
    @MainActor
    func removeActorFromList(listURI: String, actorDID: String) async -> Bool {
        guard isAuthenticated, let protoClient = protoClient, let currentDID = currentDID else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - removeActorFromList")
            return false
        }
        
        // First, get the list to find the specific list item record
        let listOutput = await performAuthenticatedRequest {
            try await protoClient.getList(from: listURI)
        }
        
        guard let output = listOutput else {
            DevLogger.shared.log("MultiAccountClient - removeActorFromList - Failed to get list: \(listURI)")
            return false
        }
        
        // Find the list item for the specific actor
        guard let listItem = output.items.first(where: { $0.subject.actorDID == actorDID }) else {
            DevLogger.shared.log("MultiAccountClient - removeActorFromList - Actor \(actorDID) not found in list \(listURI)")
            return false
        }
        
        // Extract recordKey from listItemURI format: "at://did:plc:user/app.bsky.graph.listitem/recordkey"
        guard let recordKey = extractRecordKey(from: listItem.listItemURI) else {
            DevLogger.shared.log("MultiAccountClient - removeActorFromList - Invalid listItemURI format: \(listItem.listItemURI)")
            return false
        }
        
        let success = await performAuthenticatedRequest {
            try await protoClient.deleteRecord(
                repositoryDID: currentDID,
                collection: "app.bsky.graph.listitem",
                recordKey: recordKey
            )
        } != nil
        
        if success {
            DevLogger.shared.log("MultiAccountClient - removeActorFromList - Successfully removed actor \(actorDID) from list: \(listURI)")
        } else {
            DevLogger.shared.log("MultiAccountClient - removeActorFromList - Failed to remove actor \(actorDID) from list: \(listURI)")
        }
        
        return success
    }
    
    /// Checks if an actor is in a list
    nonisolated func checkActorInList(listURI: String, actorDID: String) async -> Bool {
        let (authenticated, protoClient) = await MainActor.run {
            (isAuthenticated, self.protoClient)
        }
        
        guard authenticated, let client = protoClient else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - checkActorInList")
            return false
        }
        
        do {
            let output = try await client.getList(from: listURI)
            let isInList = output.items.contains { (listItem: AppBskyLexicon.Graph.ListItemViewDefinition) in
                listItem.subject.actorDID == actorDID
            }
            DevLogger.shared.log("MultiAccountClient - checkActorInList - Actor \(actorDID) in list \(listURI): \(isInList)")
            return isInList
        } catch {
            DevLogger.shared.log("MultiAccountClient - checkActorInList - Error: \(error)")
            return false
        }
    }
    
    /// Gets list details with members
    @MainActor
    func getListWithMembers(listURI: String, limit: Int = 50, cursor: String? = nil) async -> AppBskyLexicon.Graph.GetListOutput? {
        guard protoClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - getListWithMembers")
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.protoClient!.getList(from: listURI, limit: limit, cursor: cursor)
        }
    }
    
    /// Gets user's lists
    @MainActor
    func getUserLists(for did: String, limit: Int = 50, cursor: String? = nil) async -> AppBskyLexicon.Graph.GetListsOutput? {
        guard protoClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - getUserLists")
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.protoClient!.getLists(from: did, limit: limit, cursor: cursor)
        }
    }
    
    /// Gets list feed
    @MainActor
    func getListFeed(listURI: String, limit: Int = 50, cursor: String? = nil) async -> AppBskyLexicon.Feed.GetListFeedOutput? {
        guard protoClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - getListFeed")
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.protoClient!.getListFeed(from: listURI, limit: limit, cursor: cursor)
        }
    }
    
    /// Gets custom feed
    @MainActor
    func getCustomFeed(feedURI: String, limit: Int = 50, cursor: String? = nil) async -> AppBskyLexicon.Feed.GetFeedOutput? {
        guard protoClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - getCustomFeed")
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.protoClient!.getFeed(by: feedURI, limit: limit, cursor: cursor)
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractRecordKey(from uri: String) -> String? {
        let components = uri.components(separatedBy: "/")
        return components.count >= 5 ? components.last : nil
    }
    
    // MARK: - Preferences Management
    
    func getPreferences() async -> AppBskyLexicon.Actor.GetPreferencesOutput? {
        guard let bskyClient = protoClient else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - getPreferences")
            return nil
        }
        
        do {
            let preferences = try await bskyClient.getPreferences()
            DevLogger.shared.log("MultiAccountClient - getPreferences - Successfully fetched preferences")
            return preferences
        } catch {
            DevLogger.shared.log("MultiAccountClient - getPreferences - Failed to fetch: \(error)")
            return nil
        }
    }
    
    func putPreferences(preferences: [AppBskyLexicon.Actor.PreferenceUnion]) async -> Bool {
        guard let bskyClient = protoClient else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - putPreferences")
            return false
        }
        
        DevLogger.shared.log("MultiAccountClient - putPreferences - Sending \(preferences.count) preferences")
        
        do {
            try await bskyClient.putPreferences(preferences: preferences)
            DevLogger.shared.log("MultiAccountClient - putPreferences - Successfully updated preferences")
            return true
        } catch {
            DevLogger.shared.log("MultiAccountClient - putPreferences - Failed to update: \(error)")
            return false
        }
    }
    
    // Helper method to add or update a list in preferences
    func updateListInPreferences(listURI: String, isPinned: Bool) async -> Bool {
        guard let preferencesOutput = await getPreferences() else { return false }
        
        let preferences = preferencesOutput.preferences
        var currentSavedFeeds: AppBskyLexicon.Actor.SavedFeedPreferencesVersion2Definition?
        
        // Find SavedFeedsVersion2 in preferences
        for preference in preferences {
            if case .savedFeedsVersion2(let savedFeeds) = preference {
                currentSavedFeeds = savedFeeds
                break
            }
        }
        
        var items = currentSavedFeeds?.items ?? []
        
        // Check if list already exists
        if let existingIndex = items.firstIndex(where: { $0.value == listURI }) {
            // Update existing item
            let existingItem = items[existingIndex]
            if let updatedItem = SavedFeedBuilder.createSavedFeed(
                feedID: existingItem.feedID,
                feedType: "list",
                isPinned: isPinned,
                value: listURI
            ) {
                items[existingIndex] = updatedItem
                DevLogger.shared.log("MultiAccountClient - updateListInPreferences - Updated existing list pin status")
            }
        } else {
            // Add new item
            if let newItem = SavedFeedBuilder.createSavedFeed(
                feedID: UUID().uuidString,
                feedType: "list",
                isPinned: isPinned,
                value: listURI
            ) {
                items.append(newItem)
                DevLogger.shared.log("MultiAccountClient - updateListInPreferences - Added new list to preferences")
            }
        }
        
        // Create updated SavedFeedsVersion2
        let newSavedFeeds = SavedFeedBuilder.createSavedFeedsV2(items: items)
        
        // Preserve all other preferences
        var updatedPreferences: [AppBskyLexicon.Actor.PreferenceUnion] = []
        for preference in preferences {
            if case .savedFeedsVersion2(_) = preference {
                continue // This will be replaced with the new version
            }
            updatedPreferences.append(preference)
        }
        updatedPreferences.append(.savedFeedsVersion2(newSavedFeeds))
        
        // Save all preferences
        return await putPreferences(preferences: updatedPreferences)
    }
    
    // Helper method to reorder lists in preferences
    func reorderListsInPreferences(listURIs: [String]) async -> Bool {
        guard let preferencesOutput = await getPreferences() else { return false }
        
        let preferences = preferencesOutput.preferences
        var currentSavedFeeds: AppBskyLexicon.Actor.SavedFeedPreferencesVersion2Definition?
        
        // Find SavedFeedsVersion2 in preferences
        for preference in preferences {
            if case .savedFeedsVersion2(let savedFeeds) = preference {
                currentSavedFeeds = savedFeeds
                break
            }
        }
        
        var items = currentSavedFeeds?.items ?? []
        
        // Separate by type: timeline, lists, and feeds
        let lists = items.filter { $0.feedType == .list }
        let feeds = items.filter { $0.feedType == .feed }
        let timelines = items.filter { $0.feedType == .timeline }
        
        // Create a map of existing lists
        var listMap: [String: AppBskyLexicon.Actor.SavedFeed] = [:]
        for list in lists {
            listMap[list.value] = list
        }
        
        // Reorder lists based on provided URIs
        var reorderedLists: [AppBskyLexicon.Actor.SavedFeed] = []
        for uri in listURIs {
            if let list = listMap[uri] {
                reorderedLists.append(list)
            }
        }
        
        // Add any lists that weren't in the provided URIs (shouldn't happen, but safety check)
        for list in lists {
            if !listURIs.contains(list.value) {
                reorderedLists.append(list)
            }
        }
        
        // Combine: timeline first, then reordered lists, then feeds
        items = timelines + reorderedLists + feeds
        
        // Create updated SavedFeedsVersion2
        let newSavedFeeds = SavedFeedBuilder.createSavedFeedsV2(items: items)
        
        DevLogger.shared.log("MultiAccountClient - reorderListsInPreferences - Reordering \(reorderedLists.count) lists")
        
        // Preserve all other preferences
        var updatedPreferences: [AppBskyLexicon.Actor.PreferenceUnion] = []
        for preference in preferences {
            if case .savedFeedsVersion2(_) = preference {
                continue // This will be replaced with the new version
            }
            updatedPreferences.append(preference)
        }
        updatedPreferences.append(.savedFeedsVersion2(newSavedFeeds))
        
        // Save all preferences
        return await putPreferences(preferences: updatedPreferences)
    }
    
    // Helper method to update feed preferences
    func updateFeedInPreferences(feedURI: String, subscribe: Bool, isPinned: Bool = false) async -> Bool {
        guard let preferencesOutput = await getPreferences() else { return false }
        
        let preferences = preferencesOutput.preferences
        var currentSavedFeeds: AppBskyLexicon.Actor.SavedFeedPreferencesVersion2Definition?
        
        // Find SavedFeedsVersion2 in preferences
        for preference in preferences {
            if case .savedFeedsVersion2(let savedFeeds) = preference {
                currentSavedFeeds = savedFeeds
                break
            }
        }
        
        var items = currentSavedFeeds?.items ?? []
        
        if subscribe {
            // Check if feed already exists
            if let existingIndex = items.firstIndex(where: { $0.value == feedURI }) {
                // Update existing item
                let existingItem = items[existingIndex]
                if let updatedItem = SavedFeedBuilder.createSavedFeed(
                    feedID: existingItem.feedID,
                    feedType: "feed",
                    isPinned: isPinned,
                    value: feedURI
                ) {
                    items[existingIndex] = updatedItem
                    DevLogger.shared.log("MultiAccountClient - updateFeedInPreferences - Updated existing feed")
                }
            } else {
                // Add new feed
                if let newItem = SavedFeedBuilder.createSavedFeed(
                    feedID: UUID().uuidString,
                    feedType: "feed",
                    isPinned: isPinned,
                    value: feedURI
                ) {
                    items.append(newItem)
                    DevLogger.shared.log("MultiAccountClient - updateFeedInPreferences - Subscribed to new feed")
                }
            }
        } else {
            // Unsubscribe - remove feed
            items.removeAll { $0.value == feedURI && $0.feedType == .feed }
            DevLogger.shared.log("MultiAccountClient - updateFeedInPreferences - Unsubscribed from feed")
        }
        
        // Create updated SavedFeedsVersion2
        let newSavedFeeds = SavedFeedBuilder.createSavedFeedsV2(items: items)
        
        // Preserve all other preferences
        var updatedPreferences: [AppBskyLexicon.Actor.PreferenceUnion] = []
        for preference in preferences {
            if case .savedFeedsVersion2(_) = preference {
                continue // This will be replaced with the new version
            }
            updatedPreferences.append(preference)
        }
        updatedPreferences.append(.savedFeedsVersion2(newSavedFeeds))
        
        // Save all preferences
        return await putPreferences(preferences: updatedPreferences)
    }
    
    // Helper method to reorder feeds in preferences
    func reorderFeedsInPreferences(feedURIs: [String]) async -> Bool {
        guard let preferencesOutput = await getPreferences() else { return false }
        
        let preferences = preferencesOutput.preferences
        var currentSavedFeeds: AppBskyLexicon.Actor.SavedFeedPreferencesVersion2Definition?
        
        // Find SavedFeedsVersion2 in preferences
        for preference in preferences {
            if case .savedFeedsVersion2(let savedFeeds) = preference {
                currentSavedFeeds = savedFeeds
                break
            }
        }
        
        var items = currentSavedFeeds?.items ?? []
        
        // Separate by type: timeline, lists, and feeds
        let feeds = items.filter { $0.feedType == .feed }
        let lists = items.filter { $0.feedType == .list }
        let timelines = items.filter { $0.feedType == .timeline }
        
        // Create a map of existing feeds
        var feedMap: [String: AppBskyLexicon.Actor.SavedFeed] = [:]
        for feed in feeds {
            feedMap[feed.value] = feed
        }
        
        // Reorder feeds based on provided URIs
        var reorderedFeeds: [AppBskyLexicon.Actor.SavedFeed] = []
        for uri in feedURIs {
            if let feed = feedMap[uri] {
                reorderedFeeds.append(feed)
            }
        }
        
        // Add any feeds that weren't in the provided URIs (shouldn't happen, but safety check)
        for feed in feeds {
            if !feedURIs.contains(feed.value) {
                reorderedFeeds.append(feed)
            }
        }
        
        // Combine: timeline first, then lists, then reordered feeds
        items = timelines + lists + reorderedFeeds
        
        // Create updated SavedFeedsVersion2
        let newSavedFeeds = SavedFeedBuilder.createSavedFeedsV2(items: items)
        
        DevLogger.shared.log("MultiAccountClient - reorderFeedsInPreferences - Reordering \(reorderedFeeds.count) feeds")
        
        // Preserve all other preferences
        var updatedPreferences: [AppBskyLexicon.Actor.PreferenceUnion] = []
        for preference in preferences {
            if case .savedFeedsVersion2(_) = preference {
                continue // This will be replaced with the new version
            }
            updatedPreferences.append(preference)
        }
        updatedPreferences.append(.savedFeedsVersion2(newSavedFeeds))
        
        // Save all preferences
        return await putPreferences(preferences: updatedPreferences)
    }
    
    // MARK: - Search and Trending
    
    /// Views trending feed
    @MainActor
    func viewTrendingFeed(link: String, limit: Int = 50) async -> (atURI: String, posts: AppBskyLexicon.Feed.GetFeedOutput)? {
        guard bskyClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - viewTrendingFeed")
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.bskyClient!.viewTrendingFeed(link, limit: limit)
        }
    }
    
    /// Search posts
    @MainActor
    func searchPosts(matching query: String,
                     sortRanking: AppBskyLexicon.Feed.SearchPosts.SortRanking = .latest,
                     sinceDate: Date? = nil,
                     untilDate: Date? = nil,
                     limit: Int = 25,
                     cursor: String? = nil) async -> AppBskyLexicon.Feed.SearchPostsOutput? {
        guard protoClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - searchPosts")
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.protoClient!.searchPosts(
                matching: query,
                sortRanking: sortRanking,
                sinceDate: sinceDate,
                untilDate: untilDate,
                mentionIdentifier: nil,
                author: nil,
                language: nil,
                domain: nil,
                url: nil,
                tags: nil,
                limit: limit,
                cursor: cursor
            )
        }
    }
    
    // MARK: - Post Creation and Management
    
    /// Creates a new post with the given parameters
    @MainActor
    func createPost(
        text: String,
        facets: [AppBskyLexicon.RichText.Facet]? = nil,
        languages: [Locale] = [],
        replyTo: AppBskyLexicon.Feed.PostRecord.ReplyReference? = nil,
        embed: ATProtoBluesky.EmbedIdentifier? = nil
    ) async throws -> ComAtprotoLexicon.Repository.StrongReference {
        guard let bsky = bskyClient else {
            DevLogger.shared.log("MultiAccountClient - createPost - no bskyClient")
            throw BlueskyClientError.notAuthenticated
        }
        
        DevLogger.shared.log("MultiAccountClient - createPost - Creating post with text: \(text.prefix(50))...")
        
        do {
            let result = try await bsky.createPostRecord(
                text: text,
                locales: languages,
                replyTo: replyTo,
                embed: embed,
                creationDate: Date()
            )
            
            DevLogger.shared.log("MultiAccountClient - createPost - Success! URI: \(result.recordURI)")
            return result
        } catch {
            DevLogger.shared.log("MultiAccountClient - createPost - Failed: \(error)")
            throw error
        }
    }
    
    /// Deletes a post by its URI
    @MainActor
    func deletePost(uri: String) async -> Bool {
        guard isAuthenticated, let bskyClient = bskyClient else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - deletePost")
            return false
        }
        
        DevLogger.shared.log("MultiAccountClient - deletePost - Deleting post: \(uri)")
        
        let success = await performAuthenticatedRequest {
            try await bskyClient.deleteRecord(.recordURI(atURI: uri))
        } != nil
        
        if success {
            DevLogger.shared.log("MultiAccountClient - deletePost - Successfully deleted post")
        } else {
            DevLogger.shared.log("MultiAccountClient - deletePost - Failed to delete post")
        }
        
        return success
    }
    
    /// Creates a like record
    @MainActor
    func createLikeRecord(_ reference: ComAtprotoLexicon.Repository.StrongReference, 
                         createdAt: Date = Date()) async -> ComAtprotoLexicon.Repository.StrongReference? {
        guard bskyClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - createLikeRecord")
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.bskyClient!.createLikeRecord(reference, createdAt: createdAt)
        }
    }
    
    /// Creates a repost record
    @MainActor
    func createRepostRecord(_ reference: ComAtprotoLexicon.Repository.StrongReference, 
                           createdAt: Date,
                           shouldValidate: Bool = true) async -> ComAtprotoLexicon.Repository.StrongReference? {
        guard bskyClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - createRepostRecord")
            return nil
        }
        
        return await performAuthenticatedRequest {
            try await self.bskyClient!.createRepostRecord(reference, createdAt: createdAt, shouldValidate: shouldValidate)
        }
    }
    
    /// Deletes a record by URI
    @MainActor
    func deleteRecord(_ record: ATProtoBluesky.RecordIdentifier) async -> Bool {
        guard bskyClient != nil else {
            DevLogger.shared.log("MultiAccountClient - user not authenticated - deleteRecord")
            return false
        }
        
        let result: Void? = await performAuthenticatedRequest {
            try await self.bskyClient!.deleteRecord(record)
        }
        
        return result != nil
    }
}

// MARK: - Helper Types

private struct SavedFeedBuilder {
    static func createSavedFeed(
        feedID: String,
        feedType: String,
        isPinned: Bool,
        value: String
    ) -> AppBskyLexicon.Actor.SavedFeed? {
        // Determine the correct feed type enum value
        let feedTypeEnum: AppBskyLexicon.Actor.SavedFeed.FeedType
        switch feedType {
        case "list":
            feedTypeEnum = .list
        case "feed":
            feedTypeEnum = .feed
        case "timeline":
            feedTypeEnum = .timeline
        default:
            feedTypeEnum = .feed
        }
        
        // Use the public initializer
        return AppBskyLexicon.Actor.SavedFeed(
            feedID: feedID,
            feedType: feedTypeEnum,
            value: value,
            isPinned: isPinned
        )
    }
    
    static func createSavedFeedsV2(
        items: [AppBskyLexicon.Actor.SavedFeed]
    ) -> AppBskyLexicon.Actor.SavedFeedPreferencesVersion2Definition {
        // Use the public initializer
        return AppBskyLexicon.Actor.SavedFeedPreferencesVersion2Definition(
            items: items
        )
    }
}

// MARK: - Helper Extensions
// Note: Array.batched extension is already defined in BlueskyClient.swift