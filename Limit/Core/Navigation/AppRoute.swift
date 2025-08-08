//
//  AppRoute.swift
//  Limit
//
//  Created by Zdenek Indra on 05.06.2025.
//


import AppRouter
import Foundation
import SwiftUI
import ATProtoKit

enum AppTab: String, TabType, CaseIterable {
    case timeline, favorites, post, search, settings
    
    var id: String { rawValue}
    
    var icon: String {
        switch self {
        case .timeline:
            return "house"
        case .favorites:
            return "heart.fill"
        case .post:
            return "plus.circle.fill"
        case .search:
            return "magnifyingglass"
        case .settings:
            return "person.crop.circle"
        }
    }
    
    var description: String {
        switch self {
        case .timeline:
            return "Home"
        case .favorites:
            return "You"
        case .post:
            return "Post"
        case .search:
            return "Search"
        case .settings:
            return "Profile"
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
    case listManagement
    case listMembers(list: AppBskyLexicon.Graph.ListViewDefinition)
    case feedManagement
    case feedTimeline(uri: String, displayName: String)
    case bookmarkListManagement
    
    static func from(path: String, fullPath: [String], parameters: [String : String]) -> Destination? {
        return nil // Nepotřebuješ prozatím deep-linking, lze doplnit později.
    }
}


enum Sheet: SheetType {
    case none // nebo můžeš později přidat např. compose post apod.
    case login
    case composePost(quotedPost: TimelinePostWrapper? = nil, replyTo: TimelinePostWrapper? = nil)
    case fullScreenImage(images: [ImageDisplayData], initialIndex: Int, namespace: Namespace.ID)
    case aiExplanation(type: AIExplanationType)
    case aiSummary(bookmark: BookmarkView)
    case repostOptions(post: TimelinePostWrapper)
    
    var id: Int { hashValue }
}

typealias AppRouter = Router<AppTab, Destination, Sheet>
