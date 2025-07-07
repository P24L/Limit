//
//  FavoritesData.swift
//  Limit
//
//  Created by Zdenek Indra on 04.06.2025.
//

import Foundation
import SwiftData

enum URLSummaryStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
}

enum FavoriteCategory: String, CaseIterable, Identifiable {
    case links = "Links"
    case posts = "Posts"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .links:
            return "link"
        case .posts:
            return "text.bubble"
        }
    }
}

@Model
final class FavoriteURL: Hashable, Equatable {
    @Attribute(.unique) var id: UUID
    var url: URL
    var title: String?
    var saveTime: Date
    var thumbnailImageURL: URL?
    
    // AI Summary fields - made optional for backwards compatibility
    // to avoid SwiftData migration issues with existing FavoriteURL records
    var summary: String?
    var summaryStatus: URLSummaryStatus?
    var summaryError: String?
    var summaryGeneratedAt: Date?
    
    init( url: URL, title: String? = nil, thumbnailImageURL: URL? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.saveTime = .now
        self.thumbnailImageURL = thumbnailImageURL
        self.summary = nil
        self.summaryStatus = .pending
        self.summaryError = nil
        self.summaryGeneratedAt = nil
    }
    
    var hasSummary: Bool {
        return summary != nil && summaryStatus == .completed
    }
    
    var canRetrySummarization: Bool {
        guard summaryStatus == .failed,
              let errorMessage = summaryError else {
            return false
        }
        
        let errorType = URLSummaryErrorType.categorize(from: errorMessage)
        return errorType == .retryable
    }
    
    // Computed property for safe access to summary status with default value
    var safeSummaryStatus: URLSummaryStatus {
        return summaryStatus ?? .pending
    }
}

@Model
final class FavoritePost: Hashable, Equatable {
    @Attribute(.unique) var id: UUID
    var postID: String
    var saveTime: Date
    
    init(postID: String) {
        self.id = UUID()
        self.postID = postID
        self.saveTime = .now
    }
}

@Observable
@MainActor
class FavoriteURLManager {
    private var context: ModelContext

    private(set) var favorites: [FavoriteURL] = []

    init(context: ModelContext) {
        self.context = context
        Task {
            await loadFavorites()
        }
    }

    func isFavorited(_ url: URL) -> Bool {
        favorites.contains { $0.url == url }
    }

    func toggleFavorite(for url: URL, title: String?, thumbnailImageURL: URL? = nil) async {
        if let index = favorites.firstIndex(where: { $0.url == url }) {
            let existing = favorites[index]
            context.delete(existing)
            try? context.save()
            favorites.remove(at: index)
        } else {
            let newFavorite = FavoriteURL(url: url, title: title, thumbnailImageURL: thumbnailImageURL)
            context.insert(newFavorite)
            try? context.save()
            favorites.append(newFavorite)
        }
    }

    func addFavorite(url: URL, title: String?, thumbnailImageURL: URL? = nil) async {
        guard !isFavorited(url) else { return }
        let newFavorite = FavoriteURL(url: url, title: title, thumbnailImageURL: thumbnailImageURL)
        context.insert(newFavorite)
        try? context.save()
        favorites.append(newFavorite)
        
        Task.detached { [self] in
            await self.requestSummary(for: newFavorite)
        }
    }

    func removeFavorite(url: URL) async {
        if let index = favorites.firstIndex(where: { $0.url == url }) {
            let existing = favorites[index]
            context.delete(existing)
            try? context.save()
            favorites.remove(at: index)
        }
    }
    
    func getPendingSummaryCount() -> Int {
        return favorites.filter { $0.summaryStatus == .pending || $0.summaryStatus == .processing }.count
    }
    
    func getFailedSummaryCount() -> Int {
        return favorites.filter { $0.summaryStatus == .failed }.count
    }

    private func loadFavorites() async {
        do {
            let results = try context.fetch(FetchDescriptor<FavoriteURL>(sortBy: [SortDescriptor(\.saveTime, order: .reverse)]))
            favorites = results
        } catch {
            DevLogger.shared.log("FavoritesData.swift - URLManager - failed to load favorites - \(error)")
        }
    }
    
    private func requestSummary(for favoriteURL: FavoriteURL) async {
        await MainActor.run {
            favoriteURL.summaryStatus = .processing
            try? context.save()
        }
        
        do {
            let aiService = AIService()
            let summaryResult = try await aiService.summarizeURL(favoriteURL.url)
            
            await MainActor.run {
                favoriteURL.summary = summaryResult.summary
                favoriteURL.summaryStatus = .completed
                favoriteURL.summaryError = nil
                favoriteURL.summaryGeneratedAt = .now
                
                if let title = summaryResult.title, favoriteURL.title == nil {
                    favoriteURL.title = title
                }
                
                try? context.save()
                DevLogger.shared.log("FavoritesData.swift - URLManager - summary generated for \(favoriteURL.url)")
            }
        } catch {
            let errorType = if let aiError = error as? AIServiceError {
                aiError.isRetryable ? "retryable" : "permanent"
            } else {
                "retryable"
            }
            
            await MainActor.run {
                favoriteURL.summaryStatus = .failed
                favoriteURL.summaryError = error.localizedDescription
                try? context.save()
                DevLogger.shared.log("FavoritesData.swift - URLManager - summary failed for \(favoriteURL.url) - \(errorType) - \(error)")
            }
        }
    }
    
    func retrySummary(for favoriteURL: FavoriteURL) async {
        guard favoriteURL.canRetrySummarization else {
            DevLogger.shared.log("FavoritesData.swift - URLManager - retry skipped for \(favoriteURL.url) - permanent error")
            return
        }
        
        Task.detached { [self] in
            await self.requestSummary(for: favoriteURL)
        }
    }
}

@Observable
@MainActor
class FavoritePostManager {
    private var context: ModelContext
    
    private(set) var favorites: [FavoritePost] = []
    
    init(context: ModelContext) {
        self.context = context
        Task {
            await loadFavorites()
        }
    }
    
    func isFavorited(_ postID: String) -> Bool {
        favorites.contains { $0.postID == postID }
    }
    
    func addFavorite(postID: String) async {
        guard !isFavorited(postID) else { return }
        let fav = FavoritePost(postID: postID)
        context.insert(fav)
        try? context.save()
        favorites.append(fav)
    }
    
    func removeFavorite(postID: String) async {
        let matches = favorites.filter { $0.postID == postID }
        for match in matches {
            context.delete(match)
        }
        try? context.save()
        favorites.removeAll { $0.postID == postID }
    }
    
    func loadFavorites() async {
        do {
            let results = try context.fetch(
                FetchDescriptor<FavoritePost>(sortBy:[SortDescriptor(\FavoritePost.saveTime, order:.reverse)])
            )
            favorites = results
        } catch {
            DevLogger.shared.log("FavoritesData.swift - PostManager - failed to load favorites - \(error)")
        }
    }
}
