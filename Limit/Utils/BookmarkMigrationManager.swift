//
//  BookmarkMigrationManager.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import Foundation
import SwiftData
import ATProtoKit

@MainActor
class BookmarkMigrationManager {
    private weak var bookmarkManager: BookmarkManager?
    private let favoritesContext: ModelContext
    private let client: BlueskyClient
    
    init(bookmarkManager: BookmarkManager, favoritesContext: ModelContext, client: BlueskyClient) {
        self.bookmarkManager = bookmarkManager
        self.favoritesContext = favoritesContext
        self.client = client
    }
    
    func performAutomaticMigration() async throws {
        DevLogger.shared.log("BookmarkMigrationManager - Starting automatic migration")
        
        // Check if already migrated
        if UserDefaults.standard.bool(forKey: "BookmarkMigrationCompleted") {
            DevLogger.shared.log("BookmarkMigrationManager - Migration already completed")
            return
        }
        
        // Load all FavoriteURLs
        let favoriteURLs = try await loadAllFavoriteURLs()
        DevLogger.shared.log("BookmarkMigrationManager - Found \(favoriteURLs.count) FavoriteURLs to migrate")
        
        guard !favoriteURLs.isEmpty else {
            UserDefaults.standard.set(true, forKey: "BookmarkMigrationCompleted")
            return
        }
        
        var successCount = 0
        var failureCount = 0
        
        // Migrate each FavoriteURL
        for favoriteURL in favoriteURLs {
            do {
                try await migrateIndividualFavorite(favoriteURL)
                successCount += 1
            } catch {
                failureCount += 1
                DevLogger.shared.log("BookmarkMigrationManager - Failed to migrate: \(favoriteURL.url) - \(error)")
            }
        }
        
        DevLogger.shared.log("BookmarkMigrationManager - Migration completed: \(successCount) success, \(failureCount) failed")
        
        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: "BookmarkMigrationCompleted")
        
        // Clean up old favorites if all successful
        if failureCount == 0 {
            try await cleanupOldFavorites()
        }
    }
    
    private func loadAllFavoriteURLs() async throws -> [FavoriteURL] {
        let descriptor = FetchDescriptor<FavoriteURL>(
            sortBy: [SortDescriptor(\.saveTime, order: .reverse)]
        )
        return try favoritesContext.fetch(descriptor)
    }
    
    private func migrateIndividualFavorite(_ favoriteURL: FavoriteURL) async throws {
        guard let protoClient = client.protoClient else {
            throw BookmarkError.noClient
        }
        
        // Create bookmark in AT Protocol
        let result = try await protoClient.createBookmark(
            url: favoriteURL.url.absoluteString,
            title: favoriteURL.title ?? favoriteURL.url.absoluteString,
            description: nil, // Keep description empty for user-provided content
            summary: favoriteURL.summary, // AI summary goes to summary field
            imageUrl: favoriteURL.thumbnailImageURL?.absoluteString,
            pinned: false,
            archived: false
        )
        
        DevLogger.shared.log("BookmarkMigrationManager - Created bookmark: \(result.recordURI)")
        
        // Create corresponding cached bookmark
        if let bookmarkManager = bookmarkManager {
            let bookmarkView = BookmarkView(
                uri: result.recordURI,
                cid: result.recordCID,
                record: BookmarkRecord(
                    url: favoriteURL.url.absoluteString,
                    title: favoriteURL.title ?? favoriteURL.url.absoluteString,
                    createdAt: favoriteURL.saveTime,
                    description: nil,
                    summary: favoriteURL.summary,
                    imageUrl: favoriteURL.thumbnailImageURL?.absoluteString
                ),
                author: client.currentDID ?? ""
            )
            
            await bookmarkManager.cacheBookmark(bookmarkView)
        }
    }
    
    private func cleanupOldFavorites() async throws {
        DevLogger.shared.log("BookmarkMigrationManager - Cleaning up old FavoriteURLs")
        
        // Delete all FavoriteURLs
        let favoriteURLs = try await loadAllFavoriteURLs()
        for favorite in favoriteURLs {
            favoritesContext.delete(favorite)
        }
        
        // Delete all FavoritePosts (they're migrating to a different system)
        let postDescriptor = FetchDescriptor<FavoritePost>()
        let favoritePosts = try favoritesContext.fetch(postDescriptor)
        for post in favoritePosts {
            favoritesContext.delete(post)
        }
        
        try favoritesContext.save()
        DevLogger.shared.log("BookmarkMigrationManager - Cleanup completed")
    }
}