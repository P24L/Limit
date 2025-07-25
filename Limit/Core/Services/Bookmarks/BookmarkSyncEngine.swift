//
//  BookmarkSyncEngine.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import Foundation
import SwiftData
import ATProtoKit

@MainActor
class BookmarkSyncEngine {
    private let context: ModelContext
    private let client: BlueskyClient
    
    init(context: ModelContext, client: BlueskyClient) {
        self.context = context
        self.client = client
    }
    
    // MARK: - Main Sync Operations
    
    func performFullSync() async throws -> ([BookmarkView], [BookmarkListView]) {
        guard client.protoClient != nil else {
            throw BookmarkError.noClient
        }
        
        DevLogger.shared.log("BookmarkSyncEngine - Starting bookmark sync")
        
        // Use TaskGroup to sync lists and bookmarks in parallel
        async let listsTask = fetchBookmarkLists()
        async let bookmarksTask = fetchAllBookmarks()
        
        do {
            let (lists, bookmarks) = try await (listsTask, bookmarksTask)
            DevLogger.shared.log("BookmarkSyncEngine - Sync completed: \(bookmarks.count) bookmarks, \(lists.count) lists")
            return (bookmarks, lists)
        } catch {
            DevLogger.shared.log("BookmarkSyncEngine - Sync failed: \(error)")
            throw error
        }
    }
    
    private func fetchBookmarkLists() async throws -> [BookmarkListView] {
        guard let protoClient = client.protoClient,
              let session = try await protoClient.getUserSession() else {
            throw BookmarkError.noSession
        }
        
        var allLists: [BookmarkListView] = []
        var cursor: String? = nil
        
        repeat {
            let output = try await protoClient.getBookmarkLists(
                actorDID: session.sessionDID,
                limit: 50,
                cursor: cursor
            )
            
            allLists.append(contentsOf: output.lists)
            cursor = output.cursor
            
        } while cursor != nil
        
        // Bulk save all lists to cache
        try await bulkSaveBookmarkListsToCache(allLists)
        
        return allLists
    }
    
    private func fetchAllBookmarks() async throws -> [BookmarkView] {
        guard let protoClient = client.protoClient,
              let session = try await protoClient.getUserSession() else {
            throw BookmarkError.noSession
        }
        
        var allBookmarks: [BookmarkView] = []
        
        // First page to get initial cursor and estimate total pages
        let firstResponse = try await fetchBookmarksPage(
            protoClient: protoClient,
            session: session,
            cursor: nil
        )
        
        // Process first page
        for record in firstResponse.records {
            if let value = record.value,
               let bookmarkRecord = value.getRecord(ofType: BookmarkRecord.self) {
                let bookmarkView = BookmarkView(
                    uri: record.uri,
                    cid: record.cid,
                    record: bookmarkRecord,
                    author: session.sessionDID
                )
                allBookmarks.append(bookmarkView)
            }
        }
        
        // If there's more data, fetch remaining pages
        if let firstCursor = firstResponse.cursor {
            var cursor: String? = firstCursor
            
            // Sequential fetching for now (AT Protocol doesn't support parallel cursor-based pagination)
            while cursor != nil {
                let response = try await fetchBookmarksPage(
                    protoClient: protoClient,
                    session: session,
                    cursor: cursor
                )
                
                for record in response.records {
                    if let value = record.value,
                       let bookmarkRecord = value.getRecord(ofType: BookmarkRecord.self) {
                        let bookmarkView = BookmarkView(
                            uri: record.uri,
                            cid: record.cid,
                            record: bookmarkRecord,
                            author: session.sessionDID
                        )
                        allBookmarks.append(bookmarkView)
                    }
                }
                
                cursor = response.cursor
            }
        }
        
        // Bulk save all bookmarks to cache
        try await bulkSaveBookmarksToCache(allBookmarks)
        
        return allBookmarks
    }
    
    private func fetchBookmarksPage(
        protoClient: ATProtoKit,
        session: UserSession,
        cursor: String?
    ) async throws -> ComAtprotoLexicon.Repository.ListRecordsOutput {
        guard let keychain = protoClient.sessionConfiguration?.keychainProtocol else {
            throw BookmarkError.noKeychain
        }
        
        let accessToken = try await keychain.retrieveAccessToken()
        let sessionPDSURL = session.pdsURL ?? protoClient.pdsURL
        
        guard let requestURL = URL(string: "\(sessionPDSURL)/xrpc/com.atproto.repo.listRecords") else {
            throw BookmarkError.invalidURL
        }
        
        var queryItems = [(String, String)]()
        queryItems.append(("repo", session.sessionDID))
        queryItems.append(("collection", "app.hyper-limit.bookmark"))
        queryItems.append(("limit", "50"))
        
        if let cursor {
            queryItems.append(("cursor", cursor))
        }
        
        let queryURL = try protoClient.apiClientService.setQueryItems(
            for: requestURL,
            with: queryItems
        )
        
        let request = protoClient.apiClientService.createRequest(
            forRequest: queryURL,
            andMethod: .get,
            acceptValue: "application/json",
            contentTypeValue: nil,
            authorizationValue: "Bearer \(accessToken)"
        )
        
        return try await protoClient.apiClientService.sendRequest(
            request,
            decodeTo: ComAtprotoLexicon.Repository.ListRecordsOutput.self
        )
    }
    
    // MARK: - Cache Operations
    
    private func bulkSaveBookmarksToCache(_ bookmarks: [BookmarkView]) async throws {
        // Get current user DID
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            DevLogger.shared.log("BookmarkSyncEngine - No session, cannot save bookmarks to cache")
            return
        }
        
        let currentDID = session.sessionDID
        
        // First, get all existing bookmarks for current user
        let descriptor = FetchDescriptor<CachedBookmark>(
            predicate: #Predicate { $0.ownerDID == currentDID }
        )
        let existingBookmarks = (try? context.fetch(descriptor)) ?? []
        
        // Create a dictionary for quick lookup
        var existingByURI: [String: CachedBookmark] = [:]
        for bookmark in existingBookmarks {
            existingByURI[bookmark.uri] = bookmark
        }
        
        // Process bookmarks in batches for better performance
        let batchSize = 100
        for batchStart in stride(from: 0, to: bookmarks.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, bookmarks.count)
            let batch = Array(bookmarks[batchStart..<batchEnd])
            
            // Process batch
            for bookmarkView in batch {
                if let existing = existingByURI[bookmarkView.uri] {
                    // Update existing
                    updateCachedBookmark(existing, from: bookmarkView)
                } else {
                    // Create new
                    let cached = CachedBookmark(
                        uri: bookmarkView.uri,
                        ownerDID: currentDID,
                        cid: bookmarkView.cid,
                        url: bookmarkView.record.url,
                        title: bookmarkView.record.title,
                        createdAt: bookmarkView.record.createdAt
                    )
                    updateCachedBookmark(cached, from: bookmarkView)
                    context.insert(cached)
                }
            }
            
            // Save batch
            do {
                try context.save()
                DevLogger.shared.log("BookmarkSyncEngine - Saved batch of \(batch.count) bookmarks")
            } catch {
                DevLogger.shared.log("BookmarkSyncEngine - Failed to save batch: \(error)")
                // Continue with next batch even if one fails
            }
        }
        
        DevLogger.shared.log("BookmarkSyncEngine - Bulk saved \(bookmarks.count) bookmarks to cache for user \(currentDID)")
    }
    
    private func bulkSaveBookmarkListsToCache(_ lists: [BookmarkListView]) async throws {
        // Get current user DID
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            DevLogger.shared.log("BookmarkSyncEngine - No session, cannot save lists to cache")
            return
        }
        
        let currentDID = session.sessionDID
        
        // Get all existing lists for current user
        let descriptor = FetchDescriptor<CachedBookmarkList>(
            predicate: #Predicate { $0.ownerDID == currentDID }
        )
        let existingLists = (try? context.fetch(descriptor)) ?? []
        
        // Create a dictionary for quick lookup
        var existingByURI: [String: CachedBookmarkList] = [:]
        for list in existingLists {
            existingByURI[list.uri] = list
        }
        
        // Update or insert lists
        for listView in lists {
            if let existing = existingByURI[listView.uri] {
                // Update existing
                existing.cid = listView.cid
                existing.name = listView.record.name
                existing.visibility = listView.record.visibility.rawValue
                existing.descriptionText = listView.record.description
                existing.color = listView.record.color
                existing.icon = listView.record.icon != nil ? String(describing: listView.record.icon!) : nil
                existing.pinned = listView.record.pinned ?? false
                existing.createdAt = listView.record.createdAt
            } else {
                // Create new
                let cached = CachedBookmarkList(
                    uri: listView.uri,
                    ownerDID: currentDID,
                    cid: listView.cid,
                    name: listView.record.name,
                    visibility: listView.record.visibility.rawValue,
                    createdAt: listView.record.createdAt
                )
                cached.descriptionText = listView.record.description
                cached.color = listView.record.color
                cached.icon = listView.record.icon != nil ? String(describing: listView.record.icon!) : nil
                cached.pinned = listView.record.pinned ?? false
                context.insert(cached)
            }
        }
        
        // Save all changes at once
        do {
            try context.save()
            DevLogger.shared.log("BookmarkSyncEngine - Bulk saved \(lists.count) bookmark lists to cache for user \(currentDID)")
        } catch {
            DevLogger.shared.log("BookmarkSyncEngine - Failed to save bookmark lists to cache: \(error)")
            throw ATProtoError.serverError("Failed to save bookmark lists to cache")
        }
    }
    
    func saveCachedBookmark(from bookmarkView: BookmarkView) async {
        // Get current user DID
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            DevLogger.shared.log("BookmarkSyncEngine - No session, cannot save bookmark to cache")
            return
        }
        
        let currentDID = session.sessionDID
        
        let fetchDescriptor = FetchDescriptor<CachedBookmark>(
            predicate: #Predicate { $0.uri == bookmarkView.uri && $0.ownerDID == currentDID }
        )
        
        if let existing = try? context.fetch(fetchDescriptor).first {
            // Update existing
            updateCachedBookmark(existing, from: bookmarkView)
        } else {
            // Create new
            let cached = CachedBookmark(
                uri: bookmarkView.uri,
                ownerDID: currentDID,
                cid: bookmarkView.cid,
                url: bookmarkView.record.url,
                title: bookmarkView.record.title,
                createdAt: bookmarkView.record.createdAt
            )
            updateCachedBookmark(cached, from: bookmarkView)
            context.insert(cached)
        }
        
        do {
            try context.save()
        } catch {
            DevLogger.shared.log("BookmarkSyncEngine - Failed to save bookmark: \(error)")
        }
    }
    
    private func updateCachedBookmark(_ cached: CachedBookmark, from view: BookmarkView) {
        cached.cid = view.cid
        cached.url = view.record.url
        cached.title = view.record.title
        cached.descriptionText = view.record.description
        cached.summary = view.record.summary
        cached.note = view.record.note
        cached.imageUrl = view.record.imageUrl
        
        // Convert imageBlob if present
        if view.record.imageBlob != nil {
            // ATProtoKit blob to Data conversion
            // This depends on how ATProtoKit exposes blob data
            // For now, we'll leave it as nil and handle in future
            cached.imageBlob = nil
        }
        
        cached.tags = view.record.tags
        cached.listUris = view.record.listUris
        cached.pinned = view.record.pinned ?? false
        cached.archived = view.record.archived ?? false
        
        if let reminder = view.record.reminder {
            cached.reminder = BookmarkReminder(
                date: reminder.date,
                note: reminder.note
            )
        }
        
        cached.sourceUri = view.record.sourceUri
        cached.encrypted = view.record.encrypted ?? false
        cached.updatedAt = view.record.updatedAt
        cached.syncStatus = .synced
        cached.lastSynced = Date()
    }
    
    private func saveCachedList(from listView: BookmarkListView) async {
        // Get current user DID
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            DevLogger.shared.log("BookmarkSyncEngine - No session, cannot save list to cache")
            return
        }
        
        let currentDID = session.sessionDID
        
        let fetchDescriptor = FetchDescriptor<CachedBookmarkList>(
            predicate: #Predicate { $0.uri == listView.uri && $0.ownerDID == currentDID }
        )
        
        if let existing = try? context.fetch(fetchDescriptor).first {
            // Update existing
            updateCachedList(existing, from: listView)
        } else {
            // Create new
            let cached = CachedBookmarkList(
                uri: listView.uri,
                ownerDID: currentDID,
                cid: listView.cid,
                name: listView.record.name,
                visibility: listView.record.visibility.rawValue,
                createdAt: listView.record.createdAt
            )
            updateCachedList(cached, from: listView)
            context.insert(cached)
        }
        
        do {
            try context.save()
        } catch {
            DevLogger.shared.log("BookmarkSyncEngine - Failed to save list: \(error)")
        }
    }
    
    private func updateCachedList(_ cached: CachedBookmarkList, from view: BookmarkListView) {
        cached.cid = view.cid
        cached.name = view.record.name
        cached.visibility = view.record.visibility.rawValue
        cached.descriptionText = view.record.description
        cached.color = view.record.color
        cached.icon = view.record.icon?.rawValue
        cached.pinned = view.record.pinned ?? false
        cached.updatedAt = view.record.updatedAt
        cached.syncStatus = .synced
        cached.lastSynced = Date()
    }
    
    // MARK: - Load from Cache
    
    func loadCachedBookmarks() async throws -> [CachedBookmark] {
        // Get current user DID
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            DevLogger.shared.log("BookmarkSyncEngine - No session, cannot load bookmarks from cache")
            return []
        }
        
        let currentDID = session.sessionDID
        
        let descriptor = FetchDescriptor<CachedBookmark>(
            predicate: #Predicate { $0.ownerDID == currentDID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Load a page of cached bookmarks
    /// - Parameters:
    ///   - pageIndex: Zero-based page index
    ///   - pageSize: Number of items per page
    /// - Returns: Array of cached bookmarks for the requested page
    func loadCachedBookmarksPage(pageIndex: Int, pageSize: Int = 50) async throws -> [CachedBookmark] {
        // Get current user DID
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            DevLogger.shared.log("BookmarkSyncEngine - No session, cannot load bookmarks page from cache")
            return []
        }
        
        let currentDID = session.sessionDID
        let offset = pageIndex * pageSize
        
        var descriptor = FetchDescriptor<CachedBookmark>(
            predicate: #Predicate { $0.ownerDID == currentDID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = offset
        
        let bookmarks = try context.fetch(descriptor)
        DevLogger.shared.log("BookmarkSyncEngine - Loaded page \(pageIndex) with \(bookmarks.count) bookmarks")
        
        return bookmarks
    }
    
    /// Get total count of cached bookmarks for current user
    func getCachedBookmarksCount() async throws -> Int {
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            return 0
        }
        
        let currentDID = session.sessionDID
        
        let descriptor = FetchDescriptor<CachedBookmark>(
            predicate: #Predicate { $0.ownerDID == currentDID }
        )
        
        return try context.fetchCount(descriptor)
    }
    
    func loadCachedLists() async throws -> [CachedBookmarkList] {
        // Get current user DID
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            DevLogger.shared.log("BookmarkSyncEngine - No session, cannot load lists from cache")
            return []
        }
        
        let currentDID = session.sessionDID
        
        let descriptor = FetchDescriptor<CachedBookmarkList>(
            predicate: #Predicate { $0.ownerDID == currentDID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Load a page of cached bookmark lists
    func loadCachedListsPage(pageIndex: Int, pageSize: Int = 50) async throws -> [CachedBookmarkList] {
        guard let protoClient = client.protoClient,
              let session = try? await protoClient.getUserSession() else {
            DevLogger.shared.log("BookmarkSyncEngine - No session, cannot load lists page from cache")
            return []
        }
        
        let currentDID = session.sessionDID
        let offset = pageIndex * pageSize
        
        var descriptor = FetchDescriptor<CachedBookmarkList>(
            predicate: #Predicate { $0.ownerDID == currentDID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = offset
        
        return try context.fetch(descriptor)
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflicts(_ conflicts: [SyncConflict]) async {
        // TODO: Implement conflict resolution strategy
        // For now, server wins
    }
    
    // MARK: - Push Local Changes
    
    func pushLocalChanges() async throws {
        // SwiftData doesn't support enum comparisons in predicates
        // Fetch all and filter manually
        let allBookmarks = try context.fetch(FetchDescriptor<CachedBookmark>())
        let pendingBookmarks = allBookmarks.filter { $0.syncStatus == .pending }
        
        for bookmark in pendingBookmarks {
            // TODO: Push to AT Protocol
            bookmark.syncStatus = .syncing
        }
        
        try? context.save()
    }
    
    // MARK: - User Management
    
    func deleteAllBookmarksForUser(did: String) async throws {
        DevLogger.shared.log("BookmarkSyncEngine - Clearing bookmarks for user: \(did)")
        
        // Delete all bookmarks for the user
        let bookmarkDescriptor = FetchDescriptor<CachedBookmark>(
            predicate: #Predicate { $0.ownerDID == did }
        )
        let bookmarks = try context.fetch(bookmarkDescriptor)
        for bookmark in bookmarks {
            context.delete(bookmark)
        }
        
        // Delete all bookmark lists for the user
        let listDescriptor = FetchDescriptor<CachedBookmarkList>(
            predicate: #Predicate { $0.ownerDID == did }
        )
        let lists = try context.fetch(listDescriptor)
        for list in lists {
            context.delete(list)
        }
        
        try context.save()
        
        DevLogger.shared.log("BookmarkSyncEngine - Cleared \(bookmarks.count) bookmarks and \(lists.count) lists for user: \(did)")
    }
}

// MARK: - Supporting Types

enum BookmarkError: Error {
    case noClient
    case noSession
    case noKeychain
    case invalidURL
    case syncFailed(String)
}

struct SyncConflict {
    let localRecord: CachedBookmark
    let remoteRecord: BookmarkView
    let conflictType: ConflictType
    
    enum ConflictType {
        case bothModified
        case deletedRemotely
        case deletedLocally
    }
}