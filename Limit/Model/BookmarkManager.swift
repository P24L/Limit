//
//  BookmarkManager.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import Foundation
import SwiftData
import ATProtoKit

@Observable
@MainActor
class BookmarkManager {
    // AT Protocol data from cache
    private(set) var bookmarks: [BookmarkView] = []
    private(set) var bookmarkLists: [BookmarkListView] = []
    
    // Pagination state
    private var currentPage = 0
    private let pageSize = 50
    private var hasMorePages = true
    private var totalBookmarksCount = 0
    
    // Memory limits
    private let maxBookmarksInMemory = 200
    private let maxListsInMemory = 50
    
    // LRU tracking
    private var bookmarkAccessOrder: [String] = [] // Track URI access order
    
    // Cache management
    private var syncEngine: BookmarkSyncEngine
    private var cacheContext: ModelContext
    private var client: BlueskyClient
    
    // Processing queue
    private var processingQueue: BookmarkProcessingQueue
    
    // Migration
    private var migrationManager: BookmarkMigrationManager?
    private var hasMigrated = false
    
    // Status
    var isSyncing = false
    var isLoadingPage = false
    var lastSyncDate: Date?
    var migrationInProgress = false
    
    init(context: ModelContext, client: BlueskyClient, favoritesContext: ModelContext? = nil) {
        self.cacheContext = context
        self.client = client
        self.syncEngine = BookmarkSyncEngine(context: context, client: client)
        self.processingQueue = BookmarkProcessingQueue(client: client, context: context)
        
        // Setup migration if favorites context provided
        if let favoritesContext = favoritesContext {
            self.migrationManager = BookmarkMigrationManager(
                bookmarkManager: self,
                favoritesContext: favoritesContext,
                client: client
            )
        }
        
        Task {
            await startMigrationAndSync()
        }
    }
    
    // MARK: - Migration and Initial Load
    
    private func startMigrationAndSync() async {
        // First, perform migration if needed
        if let migrationManager = migrationManager, !hasMigrated {
            migrationInProgress = true
            do {
                try await migrationManager.performAutomaticMigration()
                hasMigrated = true
            } catch {
                DevLogger.shared.log("BookmarkManager - Migration failed: \(error)")
            }
            migrationInProgress = false
        }
        
        // Then sync with AT Protocol
        await fetchAndSyncBookmarks()
    }
    
    // MARK: - Sync Operations
    
    func fetchAndSyncBookmarks() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // First, load from cache for immediate display
        await loadFromCache()
        
        do {
            // Then sync with AT Protocol in background with retry
            let (_, syncedLists) = try await ATProtoUtils.withRetry(
                maxAttempts: 3,
                delay: 1.0
            ) {
                try await self.syncEngine.performFullSync()
            }
            
            // Update bookmark lists
            self.bookmarkLists = syncedLists
            self.lastSyncDate = Date()
            
            // Reload first page from cache to get updated data
            await resetPagination()
            
            DevLogger.shared.log("BookmarkManager - Sync completed: \(totalBookmarksCount) bookmarks, \(bookmarkLists.count) lists")
            
        } catch {
            DevLogger.shared.log("BookmarkManager - Sync failed: \(error)")
            // We already have cache data loaded, so just log the error
        }
    }
    
    private func loadFromCache() async {
        do {
            // Load first page of bookmarks
            currentPage = 0
            totalBookmarksCount = try await syncEngine.getCachedBookmarksCount()
            hasMorePages = totalBookmarksCount > pageSize
            
            let cachedBookmarks = try await syncEngine.loadCachedBookmarksPage(pageIndex: 0, pageSize: pageSize)
            let cachedLists = try await syncEngine.loadCachedLists()
            
            // Convert cached to view models
            bookmarks = cachedBookmarks.compactMap { cached in
                convertCachedToView(cached)
            }
            
            bookmarkLists = cachedLists.compactMap { cached in
                convertCachedListToView(cached)
            }
            
            // Apply memory limits
            enforceMemoryLimits()
            
            DevLogger.shared.log("BookmarkManager - Loaded page 0 from cache: \(bookmarks.count) bookmarks, total: \(totalBookmarksCount)")
        } catch {
            DevLogger.shared.log("BookmarkManager - Failed to load from cache: \(error)")
        }
    }
    
    // MARK: - Pagination
    
    /// Load next page of bookmarks from cache
    func loadNextPage() async {
        guard !isLoadingPage && hasMorePages else { return }
        
        isLoadingPage = true
        defer { isLoadingPage = false }
        
        do {
            currentPage += 1
            let cachedBookmarks = try await syncEngine.loadCachedBookmarksPage(
                pageIndex: currentPage,
                pageSize: pageSize
            )
            
            // Convert and append to existing bookmarks
            let newBookmarks = cachedBookmarks.compactMap { cached in
                convertCachedToView(cached)
            }
            
            bookmarks.append(contentsOf: newBookmarks)
            
            // Apply memory limits
            enforceMemoryLimits()
            
            // Update pagination state
            hasMorePages = bookmarks.count < totalBookmarksCount
            
            DevLogger.shared.log("BookmarkManager - Loaded page \(currentPage): \(newBookmarks.count) bookmarks, total loaded: \(bookmarks.count)")
        } catch {
            DevLogger.shared.log("BookmarkManager - Failed to load page \(currentPage): \(error)")
            currentPage -= 1 // Revert page increment on error
        }
    }
    
    /// Reset pagination and reload first page
    func resetPagination() async {
        bookmarks = []
        currentPage = 0
        hasMorePages = true
        await loadFromCache()
    }
    
    // MARK: - CRUD Operations
    
    func createBookmark(
        url: String,
        title: String,
        description: String? = nil,
        summary: String? = nil,
        note: String? = nil,
        imageUrl: String? = nil,
        imageBlob: Data? = nil,
        tags: [String]? = nil,
        listUris: [String]? = nil,
        pinned: Bool = false,
        archived: Bool = false,
        reminder: BookmarkReminder? = nil,
        sourceUri: String? = nil
    ) async throws {
        guard let protoClient = client.protoClient else {
            throw BookmarkError.noClient
        }
        
        // Convert local types to AT Protocol types
        let atProtoReminder = reminder.map { ATProtoBookmarkReminder(date: $0.date, note: $0.note) }
        let atProtoImageBlob = imageBlob.flatMap { data in
            // TODO: Convert Data to ComAtprotoLexicon.Repository.BlobContainer
            // This requires uploading the blob first
            return nil as ComAtprotoLexicon.Repository.BlobContainer?
        }
        
        let result = try await protoClient.createBookmark(
            url: url,
            title: title,
            description: description,
            summary: summary,
            note: note,
            imageUrl: imageUrl,
            imageBlob: atProtoImageBlob,
            tags: tags,
            listUris: listUris,
            pinned: pinned,
            archived: archived,
            reminder: atProtoReminder,
            sourceUri: sourceUri,
            encrypted: false
        )
        
        DevLogger.shared.log("BookmarkManager - Created bookmark: \(result.recordURI)")
        
        // Create BookmarkView from the result
        let newBookmarkView = BookmarkView(
            uri: result.recordURI,
            cid: result.recordCID,
            record: BookmarkRecord(
                url: url,
                title: title,
                createdAt: Date(),
                description: description,
                summary: summary,
                note: note,
                imageUrl: imageUrl,
                tags: tags,
                listUris: listUris,
                pinned: pinned,
                archived: archived,
                reminder: atProtoReminder,
                sourceUri: sourceUri,
                encrypted: false,
                updatedAt: Date()
            ),
            author: client.currentDID ?? ""
        )
        
        // Add to local array (at beginning for newest first)
        bookmarks.insert(newBookmarkView, at: 0)
        
        // Save to cache
        await syncEngine.saveCachedBookmark(from: newBookmarkView)
        
        // Update total count
        totalBookmarksCount += 1
        
        // Track access for LRU
        trackAccess(for: result.recordURI)
        
        // Enforce memory limits after adding
        enforceMemoryLimits()
        
        // Enqueue for processing if summary is needed
        if summary == nil {
            await enqueueForProcessing(newBookmarkView)
        }
    }
    
    func deleteBookmark(_ bookmark: BookmarkView) async throws {
        guard let protoClient = client.protoClient else {
            throw BookmarkError.noClient
        }
        
        // Extract repo and rkey from URI
        guard let (repo, rkey) = ATProtoUtils.extractRepoAndRkey(from: bookmark.uri) else {
            throw BookmarkError.invalidURL
        }
        
        try await protoClient.deleteBookmark(repo: repo, rkey: rkey)
        
        DevLogger.shared.log("BookmarkManager - Deleted bookmark: \(bookmark.uri)")
        
        // Remove from local arrays
        bookmarks.removeAll { $0.uri == bookmark.uri }
        
        // Remove from cache
        if let cached = try? cacheContext.fetch(
            FetchDescriptor<CachedBookmark>(
                predicate: #Predicate { $0.uri == bookmark.uri }
            )
        ).first {
            cacheContext.delete(cached)
            try? cacheContext.save()
        }
    }
    
    func toggleBookmark(for url: URL, title: String? = nil, description: String? = nil, imageUrl: String? = nil) async {
        let urlString = url.absoluteString
        
        if let existing = bookmarks.first(where: { $0.record.url == urlString }) {
            // Remove bookmark
            do {
                try await deleteBookmark(existing)
            } catch {
                DevLogger.shared.log("BookmarkManager - Failed to delete bookmark: \(error)")
            }
        } else {
            // Add bookmark
            do {
                try await createBookmark(
                    url: urlString,
                    title: title ?? url.host ?? urlString,
                    description: description,
                    imageUrl: imageUrl
                )
            } catch {
                DevLogger.shared.log("BookmarkManager - Failed to create bookmark: \(error)")
            }
        }
    }
    
    func isBookmarked(_ url: URL) -> Bool {
        bookmarks.contains { $0.record.url == url.absoluteString }
    }
    
    // MARK: - List Management
    
    func createBookmarkList(name: String, description: String? = nil, visibility: BookmarkListVisibility = .private, color: String? = nil, icon: BookmarkListIcon? = nil, pinned: Bool = false, permissions: BookmarkListPermissions? = nil) async throws {
        guard let protoClient = client.protoClient else {
            throw BookmarkError.noClient
        }
        
        let result = try await protoClient.createBookmarkList(
            name: name,
            visibility: visibility,
            description: description,
            color: color,
            icon: icon,
            pinned: pinned,
            permissions: permissions
        )
        
        DevLogger.shared.log("BookmarkManager - Created bookmark list: \(result.recordURI)")
        
        // Refresh to get the new list
        await fetchAndSyncBookmarks()
    }
    
    func updateBookmarkList(listURI: String, updates: BookmarkListUpdateInput) async throws {
        guard let protoClient = client.protoClient else {
            throw BookmarkError.noClient
        }
        
        // Extract repo and rkey from URI
        guard let (repo, rkey) = ATProtoUtils.extractRepoAndRkey(from: listURI) else {
            throw BookmarkError.invalidURL
        }
        
        _ = try await protoClient.updateBookmarkList(
            repo: repo,
            rkey: rkey,
            updates: updates
        )
        
        await fetchAndSyncBookmarks()
    }
    
    func deleteBookmarkList(_ list: BookmarkListView) async throws {
        guard let protoClient = client.protoClient else {
            throw BookmarkError.noClient
        }
        
        // Extract repo and rkey from URI
        guard let (repo, rkey) = ATProtoUtils.extractRepoAndRkey(from: list.uri) else {
            throw BookmarkError.invalidURL
        }
        
        try await protoClient.deleteBookmarkList(repo: repo, rkey: rkey)
        
        DevLogger.shared.log("BookmarkManager - Deleted bookmark list: \(list.record.name)")
        
        // Remove from local arrays
        bookmarkLists.removeAll { $0.uri == list.uri }
        
        // Remove from cache
        if let cached = try? cacheContext.fetch(
            FetchDescriptor<CachedBookmarkList>(
                predicate: #Predicate { $0.uri == list.uri }
            )
        ).first {
            cacheContext.delete(cached)
            try? cacheContext.save()
        }
    }
    
    func updateBookmarkListPinStatus(listURI: String) async -> Bool {
        // Find the current bookmark list
        guard let currentList = bookmarkLists.first(where: { $0.uri == listURI }) else {
            DevLogger.shared.log("BookmarkManager - List not found: \(listURI)")
            return false
        }
        
        // Toggle the pinned status
        let currentPinStatus = currentList.record.pinned ?? false
        let newPinStatus = !currentPinStatus
        
        do {
            let updates = BookmarkListUpdateInput(pinned: newPinStatus)
            try await updateBookmarkList(listURI: listURI, updates: updates)
            
            DevLogger.shared.log("BookmarkManager - Successfully updated pin status for \(listURI) to \(newPinStatus)")
            return true
        } catch {
            DevLogger.shared.log("BookmarkManager - Failed to toggle pin for list: \(error)")
            return false
        }
    }
    
    func addBookmarkToLists(_ bookmark: BookmarkView, listUris: [String]) async throws {
        guard let protoClient = client.protoClient else {
            throw BookmarkError.noClient
        }
        
        // Extract repo and rkey
        guard let (repo, rkey) = ATProtoUtils.extractRepoAndRkey(from: bookmark.uri) else {
            throw BookmarkError.invalidURL
        }
        
        try await protoClient.addBookmarkToLists(
            bookmarkRepo: repo,
            bookmarkRkey: rkey,
            listUris: listUris
        )
        
        await fetchAndSyncBookmarks()
    }
    
    // MARK: - Processing Queue
    
    func enqueueForProcessing(_ bookmark: BookmarkView) async {
        // Find cached bookmark
        if let cached = try? cacheContext.fetch(
            FetchDescriptor<CachedBookmark>(
                predicate: #Predicate { $0.uri == bookmark.uri }
            )
        ).first {
            await processingQueue.enqueueBookmarkForDescription(cached)
        }
    }
    
    // MARK: - User Management
    
    func deleteBookmarksForUser(did: String) async {
        do {
            try await syncEngine.deleteAllBookmarksForUser(did: did)
            
            // Clear from memory if it's the current user
            if let currentDID = client.currentDID, currentDID == did {
                bookmarks = []
                bookmarkLists = []
            }
            
            DevLogger.shared.log("BookmarkManager - Cleared bookmarks for user: \(did)")
        } catch {
            DevLogger.shared.log("BookmarkManager - Failed to clear bookmarks for user: \(error)")
        }
    }
    
    func loadBookmarksForCurrentUser() async {
        DevLogger.shared.log("BookmarkManager - Reloading bookmarks for new user")
        
        // Clear current in-memory data
        bookmarks = []
        bookmarkLists = []
        
        // Reset migration flag for new user
        hasMigrated = false
        
        // Load bookmarks for the new user
        await startMigrationAndSync()
    }
    
    // MARK: - Helper Methods
    
    func cacheBookmark(_ bookmarkView: BookmarkView) async {
        await syncEngine.saveCachedBookmark(from: bookmarkView)
    }
    
    private func convertCachedToView(_ cached: CachedBookmark) -> BookmarkView? {
        BookmarkView(
            uri: cached.uri,
            cid: cached.cid,
            record: BookmarkRecord(
                url: cached.url,
                title: cached.title,
                createdAt: cached.createdAt,
                description: cached.descriptionText,
                summary: cached.summary,
                note: cached.note,
                imageUrl: cached.imageUrl,
                tags: cached.tags,
                listUris: cached.listUris,
                pinned: cached.pinned,
                archived: cached.archived,
                reminder: cached.reminder.map { ATProtoBookmarkReminder(date: $0.date, note: $0.note) },
                sourceUri: cached.sourceUri,
                encrypted: cached.encrypted,
                updatedAt: cached.updatedAt
            ),
            author: "" // Will be filled during sync
        )
    }
    
    private func convertCachedListToView(_ cached: CachedBookmarkList) -> BookmarkListView? {
        guard let visibility = BookmarkListVisibility(rawValue: cached.visibility) else {
            return nil
        }
        
        let icon = cached.icon.flatMap { BookmarkListIcon(rawValue: $0) }
        
        return BookmarkListView(
            uri: cached.uri,
            cid: cached.cid,
            record: BookmarkListRecord(
                name: cached.name,
                visibility: visibility,
                createdAt: cached.createdAt,
                description: cached.descriptionText,
                color: cached.color,
                icon: icon,
                pinned: cached.pinned,
                updatedAt: cached.updatedAt
            )
        )
    }
    
    // MARK: - Memory Management
    
    /// Track bookmark access for LRU
    func trackAccess(for bookmarkURI: String) {
        // Remove from current position if exists
        bookmarkAccessOrder.removeAll { $0 == bookmarkURI }
        // Add to end (most recently used)
        bookmarkAccessOrder.append(bookmarkURI)
    }
    
    /// Enforce memory limits using LRU eviction
    private func enforceMemoryLimits() {
        // Check bookmarks limit
        if bookmarks.count > maxBookmarksInMemory {
            let itemsToRemove = bookmarks.count - maxBookmarksInMemory
            DevLogger.shared.log("BookmarkManager - Memory limit exceeded, removing \(itemsToRemove) least recently used bookmarks")
            
            // Find least recently used bookmarks
            var bookmarksToKeep: [BookmarkView] = []
            var removedCount = 0
            
            // First, keep all accessed bookmarks in LRU order
            for uri in bookmarkAccessOrder.reversed() {
                if let bookmark = bookmarks.first(where: { $0.uri == uri }) {
                    bookmarksToKeep.append(bookmark)
                    if bookmarksToKeep.count >= maxBookmarksInMemory {
                        break
                    }
                }
            }
            
            // Then add unaccessed bookmarks up to limit
            for bookmark in bookmarks {
                if !bookmarksToKeep.contains(where: { $0.uri == bookmark.uri }) {
                    if bookmarksToKeep.count < maxBookmarksInMemory {
                        bookmarksToKeep.append(bookmark)
                    } else {
                        removedCount += 1
                    }
                }
            }
            
            // Update bookmarks array
            bookmarks = bookmarksToKeep
            
            // Clean up access order
            bookmarkAccessOrder = bookmarkAccessOrder.filter { uri in
                bookmarks.contains { $0.uri == uri }
            }
            
            DevLogger.shared.log("BookmarkManager - Removed \(removedCount) bookmarks, kept \(bookmarks.count)")
        }
        
        // Check lists limit
        if bookmarkLists.count > maxListsInMemory {
            let itemsToRemove = bookmarkLists.count - maxListsInMemory
            DevLogger.shared.log("BookmarkManager - Lists memory limit exceeded, removing \(itemsToRemove) oldest lists")
            
            // Keep most recent lists based on creation date
            bookmarkLists = Array(bookmarkLists
                .sorted { $0.record.createdAt > $1.record.createdAt }
                .prefix(maxListsInMemory))
        }
    }
    
    /// Get memory usage info
    func getMemoryInfo() -> (bookmarksLoaded: Int, listsLoaded: Int, totalCapacity: Int) {
        return (
            bookmarksLoaded: bookmarks.count,
            listsLoaded: bookmarkLists.count,
            totalCapacity: maxBookmarksInMemory + maxListsInMemory
        )
    }
}