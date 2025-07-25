//
//  SearchModels.swift
//  Limit
//
//  Created by Claude on 01.07.2025.
//

import Foundation
import ATProtoKit

// MARK: - Search States
enum SearchState {
    case idle        // Neaktivní, zobrazuje trends/topics
    case active      // Aktivní vyhledávání users/posts
}

enum BrowseMode: String, CaseIterable {
    case trends
    case suggestions
    
    var displayName: String {
        switch self {
        case .trends: return "Trends"
        case .suggestions: return "Suggestions"
        }
    }
}

enum SearchMode: String, CaseIterable {
    case users  
    case posts
    
    var displayName: String {
        switch self {
        case .users: return "Users"
        case .posts: return "Posts"
        }
    }
}

enum PickerMode: Hashable {
    case browse(BrowseMode)
    case search(SearchMode)
    
    var displayName: String {
        switch self {
        case .browse(let mode): return mode.displayName
        case .search(let mode): return mode.displayName
        }
    }
}

enum LoadingState {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - Trends Models
struct TrendView {
    let topic: String              // Shorthand název tématu (lowercased)
    let displayName: String        // Zobrazovací název tématu
    let link: String              // URL feedu pro viewTrendingFeed()
    let startedAt: Date           // Kdy trend začal
    let postCount: Int            // Počet postů v trendu
    let status: TrendStatus?      // Status (.hot nebo nil)
    let category: String?         // Kategorie trendu
    let actors: [ActorProfileBasic]  // Související uživatelé
}

enum TrendStatus {
    case hot
}

struct ActorProfileBasic {
    let actorDID: String
    let actorHandle: String
    let displayName: String?
    let avatarImageURL: URL?
}

// MARK: - Topics Models
struct TrendingTopic {
    let topic: String           // Název tématu
    let displayName: String?    // Zobrazovací název (optional)
    let link: String           // Link na feed
    let description: String?    // Popis tématu (optional)
}

struct TrendingTopicsResponse {
    let topics: [TrendingTopic]
    let suggestedTopics: [TrendingTopic]
}