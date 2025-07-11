//
//  AppRoute.swift
//  Limit
//
//  Created by Zdenek Indra on 05.06.2025.
//


import AppRouter
import Foundation
import SwiftUI

enum AppTab: String, TabType, CaseIterable {
    case timeline, favorites, search, safari, settings
    
    var id: String { rawValue}
    
    var icon: String {
        switch self {
        case .timeline:
            return "clock"
        case .safari:
            return "safari.fill"
        case .search:
            return "magnifyingglass"
        case .favorites:
            return "star"
        case .settings:
            return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .timeline:
            return "Timeline"
        case .safari:
            return "Safari"
        case .search:
            return "Search"
        case .favorites:
            return "Favorites"
        case .settings:
            return "Settings"
        }
    }
}

enum Destination: DestinationType {
    case timeline
    case computedTimeline
    case search
    case searchPosts(query: String)
    case postThreadWrapped(postThread: TimelinePostWrapper)
    case safari(url: URL?)
    case favorites
    case settings
    case actor(userID: String)
    case listTimeline(source: TimelineContentSource)
    
    static func from(path: String, fullPath: [String], parameters: [String : String]) -> Destination? {
        return nil // Nepotřebuješ prozatím deep-linking, lze doplnit později.
    }
}


enum Sheet: SheetType {
    case none // nebo můžeš později přidat např. compose post apod.
    case login
    case fullScreenImage(images: [ImageDisplayData], initialIndex: Int, namespace: Namespace.ID)
    case aiExplanation(postWrapper: TimelinePostWrapper)
    case aiSummary(favoriteURL: FavoriteURL)
    
    var id: Int { hashValue }
}

typealias AppRouter = Router<AppTab, Destination, Sheet>
