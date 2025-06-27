//
//  FavoritesData.swift
//  Limit
//
//  Created by Zdenek Indra on 04.06.2025.
//

import Foundation
import SwiftData

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
    
    init( url: URL, title: String? = nil, thumbnailImageURL: URL? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.saveTime = .now
        self.thumbnailImageURL = thumbnailImageURL
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
    }

    func removeFavorite(url: URL) async {
        if let index = favorites.firstIndex(where: { $0.url == url }) {
            let existing = favorites[index]
            context.delete(existing)
            try? context.save()
            favorites.remove(at: index)
        }
    }

    private func loadFavorites() async {
        do {
            let results = try context.fetch(FetchDescriptor<FavoriteURL>(sortBy: [SortDescriptor(\.saveTime, order: .reverse)]))
            favorites = results
        } catch {
            print("Failed to load favorites:", error)
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
