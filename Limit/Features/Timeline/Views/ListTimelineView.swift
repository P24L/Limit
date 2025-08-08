//
//  ListTimelineView.swift
//  Limit
//
//  Created by Zdenek Indra on 24.06.2025.
//

import AppRouter
import ATProtoKit
import Foundation
import SwiftData
import SwiftUI

enum TimelineContentSource: Hashable {
    case list(AppBskyLexicon.Graph.ListViewDefinition)
    case feed(AppBskyLexicon.Feed.GeneratorViewDefinition)
    case feedUri(String, String) // uri, displayName
    case trendingFeed(String, String) // link, displayName
    case trendingPosts //trending posts through search
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .list(let list):
            hasher.combine("list")
            hasher.combine(list.uri)
        case .feed(let feed):
            hasher.combine("feed")
            hasher.combine(feed.feedURI)
        case .feedUri(let uri, let displayName):
            hasher.combine("feedUri")
            hasher.combine(uri)
            hasher.combine(displayName)
        case .trendingFeed(let link, let displayName):
            hasher.combine("trendingFeed")
            hasher.combine(link)
            hasher.combine(displayName)
        case .trendingPosts:
            hasher.combine("trendingPosts")
        }

    }
    
    static func == (lhs: TimelineContentSource, rhs: TimelineContentSource) -> Bool {
        switch (lhs, rhs) {
        case (.list(let lhsList), .list(let rhsList)):
            return lhsList.uri == rhsList.uri
        case (.feed(let lhsFeed), .feed(let rhsFeed)):
            return lhsFeed.feedURI == rhsFeed.feedURI
        case (.feedUri(let lhsUri, let lhsName), .feedUri(let rhsUri, let rhsName)):
            return lhsUri == rhsUri && lhsName == rhsName
        case (.trendingFeed(let lhsLink, let lhsName), .trendingFeed(let rhsLink, let rhsName)):
            return lhsLink == rhsLink && lhsName == rhsName
        case (.trendingPosts, .trendingPosts):
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .list(let list): return list.name
        case .feed(let feed): return feed.displayName
        case .feedUri(_, let displayName): return displayName
        case .trendingFeed(_, let displayName): return displayName
        case .trendingPosts: return "trendingPosts"
        }
    }
    
    var uri: String {
        switch self {
        case .list(let list): return list.uri
        case .feed(let feed): return feed.feedURI
        case .feedUri(let uri, _): return uri
        case .trendingFeed(let link, _): return link // Return link for trending feeds
        case .trendingPosts: return ""
        }
    }
    
    var sourceType: String {
        switch self {
        case .list: return "list"
        case .feed: return "feed"
        case .feedUri: return "feed"
        case .trendingFeed: return "trendingFeed"
        case .trendingPosts: return "trendingPosts"
        }
    }
}

struct ListTimelineView: View {
    let source: TimelineContentSource
    @Environment(BlueskyClient.self) private var client
    
    @Binding var isTopbarHidden: Bool

    @State private var posts: [TimelinePostWrapper] = []
    @State private var isLoading = false
    @State private var error: Error?
    
    // Modern scrollPosition API approach
    @State private var scrolledID: String? = nil
    @State private var shouldMaintainPosition = false
    @State private var isInitialLoad: Bool = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear
                    .frame(height: 120)
                
                if isLoading && posts.isEmpty {
                    // Show loading inside ScrollView to maintain state
                    ProgressView("Loading posts…")
                        .frame(maxWidth: .infinity, minHeight: 400)
                        .padding()
                } else if let error, posts.isEmpty {
                    // Show error inside ScrollView
                    Text("Chyba: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, minHeight: 400)
                        .padding()
                } else {
                    // Show posts
                    ForEach(posts) { post in
                        PostItemWrappedView(post: post, depth: 0, nextPostID: nil, nextPostThreadRootID: nil, showCard: true)
                            .id(post.uri)  // Use URI for stable anchoring
                    }
                }
            }
            .padding(.horizontal, 12)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledID, anchor: .top)
        .onScrollPhaseChange { old, new in
            if new == .tracking || new == .interacting {
                isTopbarHidden = true
            } else if new == .idle {
                isTopbarHidden = false
            }
        }
        .onChange(of: scrolledID) { _, newID in
            // Save position when user scrolls (not during programmatic changes)
            if !shouldMaintainPosition, let newID {
                TimelinePositionManager.shared.saveListPosition(newID, for: source.uri)
            }
        }
        .onChange(of: posts) { oldPosts, newPosts in
            // Handle data changes - maintain scroll position if needed
            if !oldPosts.isEmpty && !newPosts.isEmpty {
                // If we have a current position and it still exists in new posts
                if let currentScrolledID = scrolledID,
                   newPosts.contains(where: { $0.uri == currentScrolledID }) {
                    // Maintain position
                    shouldMaintainPosition = true
                    scrolledID = currentScrolledID
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        shouldMaintainPosition = false
                    }
                }
            }
        }
        .task(id: source.uri) {
            // Clear posts when source changes for clean UX
            posts = []
            isInitialLoad = true
            
            // Load data with prepend logic (handles position restoration internally)
            await loadContent()
        }
    }

    private func loadContent() async {
        guard !isLoading else { return }
        isLoading = true
        defer { 
            isLoading = false
        }
        
        // 1. Fetch all data
        let allWrappers = await fetchAllData()
        
        // 2. Try to find saved position
        let savedID = TimelinePositionManager.shared.getListPosition(for: source.uri)
        
        await MainActor.run {
            if let savedID = savedID,
               let savedIndex = allWrappers.firstIndex(where: { $0.uri == savedID }) {
                // 3A. We have saved position - use prepend strategy
                
                // Show posts from saved position down
                let visiblePosts = Array(allWrappers[savedIndex...])
                self.posts = visiblePosts
                self.scrolledID = savedID
                self.shouldMaintainPosition = true
                
                // After small delay, prepend older posts
                if savedIndex > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        let olderPosts = Array(allWrappers[0..<savedIndex])
                        self.posts.insert(contentsOf: olderPosts, at: 0)
                        // scrollPosition API will maintain position on savedID
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.shouldMaintainPosition = false
                        }
                    }
                } else {
                    // No older posts to prepend
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.shouldMaintainPosition = false
                    }
                }
            } else {
                // 3B. No saved position or post doesn't exist - normal load
                self.posts = allWrappers
                self.scrolledID = nil
                self.shouldMaintainPosition = false
            }
            
            self.isInitialLoad = false
        }
    }
    
    // Helper function to fetch data based on source type
    private func fetchAllData() async -> [TimelinePostWrapper] {
        switch source {
        case .list(let list):
            let output = await client.getListFeed(listURI: list.uri, limit: 50)
            return output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
        case .feed(let feed):
            let output = await client.getCustomFeed(feedURI: feed.feedURI, limit: 50)
            return output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
        case .feedUri(let uri, _):
            let output = await client.getCustomFeed(feedURI: uri, limit: 50)
            return output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
        case .trendingFeed(let link, _):
            let result = await client.viewTrendingFeed(link: link, limit: 50)
            return result?.posts.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
        case .trendingPosts:
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -2, to: Date())
            let output = await client.searchPosts(
                matching: "*",
                sortRanking: .top,
                sinceDate: weekAgo,
                untilDate: Date(),
                limit: 50
            )
            return output?.posts.compactMap { TimelinePostWrapper(from: $0) } ?? []
        }
    }
}