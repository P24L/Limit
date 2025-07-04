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
        }
    }
    
    var uri: String {
        switch self {
        case .list(let list): return list.uri
        case .feed(let feed): return feed.feedURI
        case .feedUri(let uri, _): return uri
        case .trendingFeed(let link, _): return link // Return link for trending feeds
        }
    }
    
    var sourceType: String {
        switch self {
        case .list: return "list"
        case .feed: return "feed"
        case .feedUri: return "feed"
        case .trendingFeed: return "trendingFeed"
        }
    }
}

struct ListTimelineView: View {
    let source: TimelineContentSource
    @Environment(BlueskyClient.self) private var client
    // Pro budoucí rozšíření lze přidat bindingy jako u TimelinePostList
    // @Binding var newPostsAboveCount: Int
    // @Binding var hideDirectionIsUp: Bool
    // @Binding var isTopbarHidden: Bool

    @State private var posts: [TimelinePostWrapper] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var topVisibleID: String? = nil
    @State private var isRestoringScrollPosition: Bool = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading posts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                Text("Chyba: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack {
                            Color.clear
                                .frame(height: 60)
                            ForEach(posts) { post in
                                PostItemWrappedView(post: post, depth: 0, nextPostID: nil, nextPostThreadRootID: nil)
                                    .id(post.uri)
                            }
                        }
                        .padding(.horizontal, 12)
                        .scrollTargetLayout()
                    }
                    .onScrollTargetVisibilityChange(idType: String.self) { visibleIDs in
                        guard !isRestoringScrollPosition else { return }
                        if let firstID = visibleIDs.first {
                            topVisibleID = firstID
                            TimelinePositionManager.shared.saveListPosition(firstID, for: source.uri)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .restoreListScrollToID)) { notification in
                        if let postID = notification.object as? String {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(postID, anchor: .top)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                isRestoringScrollPosition = false
                            }
                        }
                    }
                }
            }
        }
        .task(id: source.uri) {
            await loadContent() 
            // Fallback timeout - pokud se za 2 sekundy nepodaří obnovit pozici, povol ukládání
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if isRestoringScrollPosition {
                    isRestoringScrollPosition = false
                }
            }
        }
    }

    private func loadContent() async {
        guard !isLoading else { return }
        isLoading = true
        defer { 
            isLoading = false
        }
        do {
            let wrappers: [TimelinePostWrapper]
            
            switch source {
            case .list(let list):
                let output = try await client.protoClient?.getListFeed(from: list.uri, limit: 50)
                wrappers = output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            case .feed(let feed):
                let output = try await client.protoClient?.getFeed(by: feed.feedURI, limit: 50)
                wrappers = output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            case .feedUri(let uri, _):
                let output = try await client.protoClient?.getFeed(by: uri, limit: 50)
                wrappers = output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            case .trendingFeed(let link, _):
                let result = try await client.bskyClient?.viewTrendingFeed(link, limit: 50)
                wrappers = result?.posts.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            }
            
            await MainActor.run {
                self.posts = wrappers
                // Po načtení postů obnov pozici pokud existuje
                if let savedID = TimelinePositionManager.shared.getListPosition(for: source.uri) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .restoreListScrollToID, object: savedID)
                    }
                } else {
                    isRestoringScrollPosition = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
}