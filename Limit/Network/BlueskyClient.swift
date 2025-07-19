// MARK: - Load Older Timeline Posts

/// Loads older posts for infinite scrolling or pagination.
/// Finds the oldest TimelinePost, extracts its fetchedWithCursor, and loads more posts using that cursor.
/// Inserts new posts if they do not already exist.
//
//  BlueskyClient.swift
//  Created by Zdenek Indra on 15.05.2025.
//
import Foundation
import ATProtoKit
import SwiftData
import SwiftUI
import Observation

// MARK: - BlueskyClient Errors

enum BlueskyClientError: LocalizedError {
    case notAuthenticated
    case invalidSession
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidSession:
            return "Invalid session"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

@Observable
@MainActor
final class BlueskyClient { // Přidáno Sendable pro bezpečné použití v konkurentních kontextech
    // MARK: - Caching for Hot Posts
    private var cachedHotPosts: [TimelinePostWrapper] = []
    private var hotPostIDsTimestamp: Date = .distantPast
    internal private(set) var isRefreshingHotPosts = false
    
    // MARK: - Konfigurace

    /// URL adresa Personal Data Serveru (PDS).
    /// Pro Bluesky je to obvykle "bsky.social".
    let pdsURL: URL // Použijeme let, pokud se URL po inicializaci nemění

    /// Inicializace klienta s URL PDS.

    init(pdsURL: URL = URL(string: "https://bsky.social")!) {
        self.pdsURL = pdsURL
        self.handle = ""
        self.appPassword = ""
        self.configuration = ATProtocolConfiguration(pdsURL: pdsURL.absoluteString)
        self.protoClient = nil // Will be initialized asynchronously in login()
        self.bskyClient = nil // Will be initialized asynchronously in login()
        self.isLoading = false

    }

    // MARK: - Interní stav klienta

    /// Instance ATProtoKit klienta pro komunikaci s PDS.
    /// Je nil, pokud uživatel není přihlášen.

    internal private(set) var configuration: ATProtocolConfiguration
    internal private(set) var protoClient: ATProtoKit?
    internal private(set) var bskyClient: ATProtoBluesky?

    var handle: String
    var appPassword: String



    // MARK: - Stav klienta pro UI

    
    internal private(set) var isAuthenticated: Bool = false   // Aktuální stav připojení/přihlášení.
    internal private(set) var currentDID: String? = nil
    internal private(set) var userSession: UserSession?

    internal private(set) var isLoading: Bool = true

    // MARK: pro Preview
    static public func preview() -> BlueskyClient {
      .init()
    }

    // MARK: - Připojení a přihlášení

    /// Metoda pro pokus o přihlášení uživatele.
    /// - Parameters:
    ///   - handleOrDID: Handle nebo DID uživatele.
    ///   - password: Heslo uživatele.
    //@MainActor // Metody, které aktualizují @Published vlastnosti, by měly běžet na hlavním vlákně
    // func login(handleOrDID: String, password: String) async {
    @MainActor
    func login() async {
        guard !isAuthenticated else { return }

        do {
            // Vytvoření nové instance klienta pro přihlášení
            try await configuration.authenticate(with: handle, password: appPassword)
            // Po úspěšném přihlášení uložíme klienta a aktualizujeme stav
            self.protoClient = await ATProtoKit(sessionConfiguration: configuration)
            if let protoClient = protoClient {
                self.bskyClient = ATProtoBluesky(atProtoKitInstance: protoClient)
                self.userSession = try await protoClient.getUserSession()
                self.currentDID = userSession?.didDocument?.id
            }
            isAuthenticated = true
            DevLogger.shared.log("BlueskyClient.swift - Login successful")
            if protoClient != nil {
                DevLogger.shared.log("BlueskyClient.swift - ProtoClient initialized successfully")
            } else {
                DevLogger.shared.log("BlueskyClient.swift - ProtoClient initialization failed")
            }
        } catch {
            // On error, set error message and update state
            self.isAuthenticated = false
            DevLogger.shared.log("BlueskyClient.swift - Login error: \(error.localizedDescription)")
        }
    }

    /// Logout method.
    @MainActor
    func logout() async {
        do {
            try await configuration.deleteSession()
        } catch {
            DevLogger.shared.log("BlueskyClient.swift - Logout error: \(error.localizedDescription)")
        }

        self.protoClient = nil
        self.bskyClient = nil
        self.isAuthenticated = false
        self.userSession = nil
        self.handle = ""
        self.appPassword = ""

        cachedHotPosts = []
        hotPostIDsTimestamp = .distantPast


        DevLogger.shared.log("BlueskyClient.swift - User logged out.")
    }

    // MARK: - fetchUserTimeline - AT Posts
    func fetchTimeline() async -> (posts: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?) {
        guard isAuthenticated, let client = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - user not authenticated - fetchUserTimeline")
            return ([], nil)
        }

        DevLogger.shared.log("BlueskyClient.swift - fetchUserTimeline - Fetching timeline")
        
        let result = await performAuthenticatedRequest {
            try await client.getTimeline(limit: 25)
        }
        
        guard let response = result else {
            DevLogger.shared.log("BlueskyClient.swift - fetchUserTimeline - Failed to get response")
            return ([], nil)
        }
        
        DevLogger.shared.log("BlueskyClient.swift - fetchUserTimeline - Finished fetching timeline")
        return (response.feed, response.cursor)
    }
    
    
    // MARK: - fetchUserTimeline - AT Posts SINCE (Multi-URI approach)
    func fetchTimeline(since knownURIs: Set<String>) async -> (posts: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?) {
        guard isAuthenticated, let client = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - not authenticated - fetchUserTimeline since URIs")
            return ([], nil)
        }

        DevLogger.shared.log("BlueskyClient.swift - fetchUserTimeline - since URIs - Fetching timeline (checking \(knownURIs.count) known URIs)")

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
                DevLogger.shared.log("BlueskyClient.swift - failed to get timeline response in loop \(loopIndex)")
                break loop
            }
            
            let feed = response.feed
            if feed.isEmpty { break loop }

            for post in feed {
                // Found overlap with existing posts
                if knownURIs.contains(post.post.uri) { 
                    DevLogger.shared.log("BlueskyClient.swift - found known URI match in loop \(loopIndex), collected \(allNewPosts.count) new posts")
                    break loop 
                }
                
                // Add new post (avoid duplicates)
                if !allNewPosts.contains(where: { $0.post.uri == post.post.uri }) {
                    allNewPosts.append(post)
                }
            }

            // Limit maximum fetched posts
            if allNewPosts.count >= 1000 { break loop }

            if let newCursor = response.cursor {
                cursor = newCursor
                lastCursor = newCursor
            } else {
                break loop
            }
        }
        
        DevLogger.shared.log("BlueskyClient.swift - fetchUserTimeline since URIs - completed with \(allNewPosts.count) new posts")
        return (allNewPosts, lastCursor)
    }

    // MARK: - fetchUserTimeline - AT Posts SINCE (Legacy single URI - DEPRECATED)
    func fetchTimeline(since lastPost: String) async -> (posts: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?) {
        guard isAuthenticated, let client = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - not authenticated - fetchUserTimeline since")
            return ([], nil)
        }

        DevLogger.shared.log("BlueskyClient.swift - fetchUserTimeline - since - Fetching timeline")

        var allNewPosts: [AppBskyLexicon.Feed.FeedViewPostDefinition] = []
        var cursor: String? = nil
        var lastCursor: String? = nil

        isLoading = true
        defer { isLoading = false }

        loop: for _ in 0..<maxTimelineFetchLoops {
            let result = await performAuthenticatedRequest {
                try await client.getTimeline(limit: 100, cursor: cursor)
            }
            
            guard let response = result else {
                DevLogger.shared.log("BlueskyClient.swift - failed to get timeline response")
                break loop
            }
            
            let feed = response.feed
            if feed.isEmpty { break loop }

            for post in feed {
                if post.post.uri == lastPost { break loop }
                if allNewPosts.contains(where: { $0.post.uri == post.post.uri }) { continue }
                allNewPosts.append(post)
            }

            // Limit maximum fetched posts
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

    // MARK: Helpery

    // MARK: - In-memory fetch for TimelinePostWrapper (without ModelContext/SwiftData)
    /// Returns wrapped TimelinePostWrapper directly from API for given post IDs, without saving to SwiftData.
    /// Use only for in-memory usage in ComputedTimeline or during prototyping.
    /// Uses batch processing to handle API limit of 25 posts per call.
    nonisolated func fetchPostWrappersByID(for ids: [String]) async -> [TimelinePostWrapper] {
        let client = await MainActor.run { protoClient }
        guard let client = client else {
            DevLogger.shared.log("BlueskyClient.swift - fetchPostWrappersByID - no protoClient")
            return []
        }
        
        guard !ids.isEmpty else { return [] }
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { self.isLoading = false } } }
        
        // Split IDs into batches of 25 (API limit)
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
            DevLogger.shared.log("BlueskyClient.swift - fetchPostWrappersByID - \(error)")
            return []
        }
    }

    // MARK: - In-memory thread fetch for TimelinePostWrapper (without ModelContext/SwiftData)
    @MainActor
    func fetchThreadWrapped(for postID: String) async -> [TimelinePostWrapper] {
        guard let client = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - fetchThreadWrapped - No protoClient available")
            return []
        }
        isLoading = true
        defer { isLoading = false }

        let result = await performAuthenticatedRequest {
            try await client.getPostThread(from: postID)
        }
        
        guard let output = result else {
            DevLogger.shared.log("BlueskyClient.swift - fetchThreadWrapped - Failed to get thread")
            return []
        }
        guard case let .threadViewPost(rootThread) = output.thread else {
            DevLogger.shared.log("BlueskyClient.swift - fetchThreadWrapped - No valid threadViewPost")
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

        // Build full list (same as fetchThread)
        collectParents(from: rootThread, depth: 0, maxDepth: 20)
        allNodes.append(rootThread)
        collectReplies(from: rootThread, depth: 0, maxDepth: 40)

        // Convert to TimelinePostWrapper (in-memory only, no SwiftData)
        let timelineWrappers: [TimelinePostWrapper] = allNodes.compactMap { node in
            TimelinePostWrapper(from: node.post)
        }
        return timelineWrappers
    }

    func getProfile(for actor: String) async -> AppBskyLexicon.Actor.ProfileViewDetailedDefinition? {
        do {
            return try await protoClient?.getProfile(for: actor)
        } catch {
            DevLogger.shared.log("BlueskyClient.swift - getProfile - actor: \(actor), error: \(error)")
        }
        return nil
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
    
    nonisolated func fetchHotPosts(
        within timeInterval: TimeInterval = 86400, // last 24 hours (was 10h)
        maxResults: Int = 150,
        sampleAccountsCount: Int = 75, // reduced from 150 for speed
        postsPerAccount: Int = 50 // reduced from 75 for speed
    ) async -> [TimelinePostWrapper] {
        
        let (authenticated, myDID, protoClient) = await MainActor.run {
            (isAuthenticated, currentDID, self.protoClient)
        }
        
        guard authenticated else { return []}

        struct ScoredPost {
            let id: String
            let createdAt: Date
            let score: Int
        }

        // Constants for optimization - reduced for 10-12s target
        let maxFollowersToFetch = 100  // fetch more to sample from
        let maxFollowersToExpand = 20  // reduced from 30
        let maxFollowsPerUser = 50
        let maxFollowersPerUser = 50
        let secondHopSampleSize = 5  // reduced from 10 for faster 2nd hop

        guard let myDID = myDID else {
            DevLogger.shared.log("BlueskyClient.swift - fetchHotPostIDs - No currentDID available")
            return []
        }
        guard let protoClient = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - fetchHotPostIDs - No protoClient available")
            return []
        }

        do {
            DevLogger.shared.log("BlueskyClient.swift - fetchHotPostIDs - 1 - getting my followers")
            let followersResponse = try await protoClient.getFollows(from: myDID, limit: maxFollowersToFetch)
            
            // Randomly sample followers for better diversity
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
                            DevLogger.shared.log("fetchHotPostIDs - error for \(follower.actorDID): \(error)")
                        }
                        return result
                    }
                }

                for try await result in group {
                    relatedAccounts.formUnion(result)
                }
            }
            
            // 2nd hop exploration for greater diversity
            let firstHopAccounts = Array(relatedAccounts)
            let secondHopSample = Array(firstHopAccounts.shuffled().prefix(secondHopSampleSize))
            
            try await withThrowingTaskGroup(of: Set<String>.self) { group in
                for account in secondHopSample {
                    group.addTask {
                        var result = Set<String>()
                        do {
                            // Explore 2nd hop with smaller limits to balance performance
                            let theirFollows = try await protoClient.getFollows(from: account, limit: 20)
                            result.formUnion(theirFollows.follows.map { $0.actorDID })
                        } catch {
                            // Silent fail for 2nd hop to not slow down main algorithm
                        }
                        return result
                    }
                }
                
                for try await result in group {
                    relatedAccounts.formUnion(result)
                }
            }

            let sampledAccounts = Array(relatedAccounts.shuffled().prefix(sampleAccountsCount))
            
            DevLogger.shared.log("fetchHotPostIDs - 2 - found \(relatedAccounts.count) accounts, sampling \(sampledAccounts.count)")

            var scoredPosts: [ScoredPost] = []
            let now = Date()

            try await withThrowingTaskGroup(of: [ScoredPost].self) { group in
                let concurrentLimit = 25  // reduced from 35 for stability
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
                            let _ = posts.feed.count
                            for post in posts.feed {
                                let age = now.timeIntervalSince(post.post.indexedAt)
                                
                                // Hard time limit - skip posts older than 7 days
                                if age > 7 * 24 * 3600 { continue }
                                
                                // Basic engagement score
                                let engagementScore = (post.post.likeCount ?? 0) + (post.post.repostCount ?? 0) + (post.post.replyCount ?? 0)
                                
                                // Exponential time decay - stronger preference for fresh content
                                let ageInDays = age / 86400.0
                                let timeFactor = max(0.01, exp(-ageInDays / 2.0)) // 2-day half-life
                                
                                let finalScore = Int(Double(engagementScore) * timeFactor)
                                
                                // Score threshold - ignore very low scored posts
                                if finalScore < 3 { continue }
                                
                                localPosts.append(ScoredPost(id: post.id, createdAt: post.post.indexedAt, score: finalScore))
                            }
                        } catch {
                            DevLogger.shared.log("fetchHotPostIDs - error for feed \(accountDID): \(error)")
                            if let profile = try? await protoClient.getProfile(for: accountDID) {
                                DevLogger.shared.log("fetchHotPostIDs - error for handle \(profile.actorHandle): \(error)")
                            }
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

            DevLogger.shared.log("fetchHotPostIDs - 3 - collected \(scoredPosts.count) scored posts")
            
            let weightedPosts = scoredPosts.flatMap { post in
                let clampedScore = max(1, min(post.score, 20))
                return Array(repeating: post, count: clampedScore)
            }
            let topPostIDs = Array(weightedPosts.shuffled().prefix(maxResults).map { $0.id })
            
            DevLogger.shared.log("fetchHotPostIDs - 4 - selected \(topPostIDs.count) post IDs for final fetch")
            
            let topPosts = await fetchPostWrappersByID(for: topPostIDs)
            
            DevLogger.shared.log("fetchHotPostIDs - 5 - final result: \(topPosts.count) posts")
            
            return topPosts
        } catch {
            DevLogger.shared.log("BlueskyClient.swift - fetchHotPostIDs - Error during processing \(error)")
        }

        return []
    }

    // MARK: - Cached Hot Post IDs with Background Refresh
    // Shared logic for refreshing cache
    private func prepareFreshHotPostsCache(timeInterval: TimeInterval) async {
        let freshPosts = await self.fetchHotPosts(within: timeInterval)
        
        // Switch to MainActor for safe update of @MainActor variables
        await MainActor.run {
            self.cachedHotPosts = freshPosts
            self.hotPostIDsTimestamp = Date()
            self.isRefreshingHotPosts = false
            DevLogger.shared.log("getCachedOrRefreshHotPostIDs - background refresh complete")
        }
    }

    /// Public method to trigger background preparation without waiting
    @MainActor
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
    
    nonisolated func getCachedOrRefreshHotPosts(
        within timeInterval: TimeInterval = 36000,
        maxAge: TimeInterval = 600
    ) async -> [TimelinePostWrapper] {
        let (authenticated, timestamp, cached, refreshing) = await MainActor.run {
            (isAuthenticated, hotPostIDsTimestamp, cachedHotPosts, isRefreshingHotPosts)
        }
        
        guard authenticated else { return []}

        let now = Date()

        if now.timeIntervalSince(timestamp) < maxAge {
            DevLogger.shared.log("getCachedOrRefreshHotPostIDs - returning cached result")

            if !refreshing {
                await MainActor.run { isRefreshingHotPosts = true }
                Task.detached { [weak self] in
                    guard let self else { return }
                    await self.prepareFreshHotPostsCache(timeInterval: timeInterval)
                }
            }
            return cached
        }

        DevLogger.shared.log("getCachedOrRefreshHotPostIDs - cache expired, fetching fresh")
        await MainActor.run { isRefreshingHotPosts = true }
        let fresh = await fetchHotPosts(within: timeInterval)
        await MainActor.run {
            cachedHotPosts = fresh
            hotPostIDsTimestamp = Date()
            isRefreshingHotPosts = false
        }

        let stillRefreshing = await MainActor.run { isRefreshingHotPosts }
        if !stillRefreshing {
            await MainActor.run { isRefreshingHotPosts = true }
            Task.detached { [weak self] in
                guard let self else { return }
                await self.prepareFreshHotPostsCache(timeInterval: timeInterval)
            }
        }

        return fresh
    }
    
    
    @MainActor
    func loadOlderPosts(from oldestCursor: String) async -> (posts: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?) {
        guard let client = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - loadOlderPosts - No protoClient available")
            return ([], nil)
        }

        guard !isLoading else {
            DevLogger.shared.log("BlueskyClient.swift - loadOlderPosts - Already loading")
            return ([], nil)
        }

        isLoading = true

        defer { isLoading = false }

        do {
            let response = try await client.getTimeline(limit: 30, cursor: oldestCursor)
            return (response.feed, response.cursor)
        } catch {
            DevLogger.shared.log("BlueskyClient.swift - loadOlderPosts - error: \(error)")
            return ([], nil)
        }
    }

    /// Helper to perform an authenticated request, handling ExpiredToken by retrying after login.
    func performAuthenticatedRequest<T>(
        _ operation: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await operation()
        } catch let error as ATAPIError {
            if case .badRequest(let httpError) = error, httpError.error == "ExpiredToken" {
                DevLogger.shared.log("performAuthenticatedRequest - ExpiredToken, retrying after login")
                isAuthenticated = false
                await login()
                do {
                    return try await operation()
                } catch {
                    DevLogger.shared.log("performAuthenticatedRequest - failed after retry: \(error)")
                }
            } else {
                DevLogger.shared.log("performAuthenticatedRequest - API error: \(error)")
            }
        } catch {
            DevLogger.shared.log("performAuthenticatedRequest - General error: \(error)")
        }
        return nil
    }
    
    // MARK: - Lists Management
    
    /// Creates a new list with the specified name
    @MainActor
    func createList(name: String) async -> String? {
        guard isAuthenticated, let bskyClient = bskyClient else {
            DevLogger.shared.log("BlueskyClient.swift - user not authenticated - createList")
            return nil
        }
        
        let result = await performAuthenticatedRequest {
            try await bskyClient.createListRecord(
                named: name,
                ofType: .curation
            )
        }
        
        guard let listURI = result?.recordURI else {
            DevLogger.shared.log("BlueskyClient.swift - createList - Failed to create list: \(name)")
            return nil
        }
        
        DevLogger.shared.log("BlueskyClient.swift - createList - Successfully created list: \(name)")
        
        return listURI
    }
    
    /// Deletes a list by its URI
    @MainActor
    func deleteList(listURI: String) async -> Bool {
        guard isAuthenticated, let protoClient = protoClient, let currentDID = currentDID else {
            DevLogger.shared.log("BlueskyClient.swift - user not authenticated - deleteList")
            return false
        }
        
        // Extract recordKey from URI format: "at://did:plc:user/app.bsky.graph.list/recordkey"
        guard let recordKey = extractRecordKey(from: listURI) else {
            DevLogger.shared.log("BlueskyClient.swift - deleteList - Invalid listURI format: \(listURI)")
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
            DevLogger.shared.log("BlueskyClient.swift - deleteList - Successfully deleted list: \(listURI)")
        } else {
            DevLogger.shared.log("BlueskyClient.swift - deleteList - Failed to delete list: \(listURI)")
        }
        
        return success
    }
    
    /// Adds an actor to a list
    @MainActor
    func addActorToList(listURI: String, actorDID: String) async -> Bool {
        guard isAuthenticated, let bskyClient = bskyClient else {
            DevLogger.shared.log("BlueskyClient.swift - user not authenticated - addActorToList")
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
            DevLogger.shared.log("BlueskyClient.swift - addActorToList - Successfully added actor \(actorDID) to list \(listURI)")
        } else {
            DevLogger.shared.log("BlueskyClient.swift - addActorToList - Failed to add actor \(actorDID) to list \(listURI)")
        }
        
        return success
    }
    
    /// Removes an actor from a list
    @MainActor
    func removeActorFromList(listURI: String, actorDID: String) async -> Bool {
        guard isAuthenticated, let protoClient = protoClient, let currentDID = currentDID else {
            DevLogger.shared.log("BlueskyClient.swift - user not authenticated - removeActorFromList")
            return false
        }
        
        // First, get the list to find the specific list item record
        let listOutput = await performAuthenticatedRequest {
            try await protoClient.getList(from: listURI)
        }
        
        guard let output = listOutput else {
            DevLogger.shared.log("BlueskyClient.swift - removeActorFromList - Failed to get list: \(listURI)")
            return false
        }
        
        // Find the list item for the specific actor
        guard let listItem = output.items.first(where: { $0.subject.actorDID == actorDID }) else {
            DevLogger.shared.log("BlueskyClient.swift - removeActorFromList - Actor \(actorDID) not found in list \(listURI)")
            return false
        }
        
        // Extract recordKey from listItemURI format: "at://did:plc:user/app.bsky.graph.listitem/recordkey"
        guard let recordKey = extractRecordKey(from: listItem.listItemURI) else {
            DevLogger.shared.log("BlueskyClient.swift - removeActorFromList - Invalid listItemURI format: \(listItem.listItemURI)")
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
            DevLogger.shared.log("BlueskyClient.swift - removeActorFromList - Successfully removed actor \(actorDID) from list \(listURI)")
        } else {
            DevLogger.shared.log("BlueskyClient.swift - removeActorFromList - Failed to remove actor \(actorDID) from list \(listURI)")
        }
        
        return success
    }
    
    /// Checks if an actor is in a specific list
    nonisolated func checkActorInList(listURI: String, actorDID: String) async -> Bool {
        let (authenticated, protoClient) = await MainActor.run {
            (isAuthenticated, self.protoClient)
        }
        
        guard authenticated, let client = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - user not authenticated - checkActorInList")
            return false
        }
        
        do {
            let output = try await client.getList(from: listURI)
            let isInList = output.items.contains { (listItem: AppBskyLexicon.Graph.ListItemViewDefinition) in
                listItem.subject.actorDID == actorDID
            }
            DevLogger.shared.log("BlueskyClient.swift - checkActorInList - Actor \(actorDID) in list \(listURI): \(isInList)")
            return isInList
        } catch {
            DevLogger.shared.log("BlueskyClient.swift - checkActorInList - Error: \(error)")
            return false
        }
    }
    
    
    // MARK: - Helper Methods
    
    /// Extracts recordKey from AT URI format
    /// URI format: "at://did:plc:user/collection/recordkey"
    private func extractRecordKey(from uri: String) -> String? {
        let components = uri.components(separatedBy: "/")
        return components.count >= 5 ? components.last : nil
    }
    
    // MARK: - Notification Methods
    
    /// Fetches the count of unread notifications
    @MainActor
    func getUnreadNotificationCount() async -> Int {
        guard let client = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - getUnreadNotificationCount - no protoClient")
            return 0
        }
        
        // Try the API call but handle the known seenAt parameter error gracefully
        do {
            let result = try await client.getUnreadCount(priority: nil)
            return result.count
        } catch let error as ATAPIError {
            if case .badRequest(let httpError) = error, 
               httpError.error == "InvalidRequest" && 
               httpError.message.contains("seenAt parameter is unsupported") {
                DevLogger.shared.log("BlueskyClient.swift - getUnreadNotificationCount - seenAt parameter error (known issue), returning 0")
                return 0
            } else {
                DevLogger.shared.log("BlueskyClient.swift - getUnreadNotificationCount - API error: \(error)")
                return 0
            }
        } catch {
            DevLogger.shared.log("BlueskyClient.swift - getUnreadNotificationCount - error: \(error)")
            return 0
        }
    }
    
    /// Fetches notifications with pagination support
    @MainActor
    func fetchNotifications(limit: Int = 50, cursor: String? = nil) async -> (notifications: [NotificationWrapper], cursor: String?) {
        guard let client = protoClient else {
            DevLogger.shared.log("BlueskyClient.swift - fetchNotifications - no protoClient")
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
    
    // MARK: - Post Creation
    
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
            DevLogger.shared.log("BlueskyClient.swift - createPost - no bskyClient")
            throw BlueskyClientError.notAuthenticated
        }
        
        DevLogger.shared.log("BlueskyClient.swift - createPost - Creating post with text: \(text.prefix(50))...")
        
        do {
            let result = try await bsky.createPostRecord(
                text: text,
                locales: languages,
                replyTo: replyTo,
                embed: embed,
                creationDate: Date()
            )
            
            DevLogger.shared.log("BlueskyClient.swift - createPost - Success! URI: \(result.recordURI)")
            return result
        } catch {
            DevLogger.shared.log("BlueskyClient.swift - createPost - Failed: \(error)")
            throw error
        }
    }
    
    /// Gets the current session for creating reply references
    var currentSession: UserSession? {
        return userSession
    }
    
}

// MARK: - Helper Extensions
extension Array {
    func batched(size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

