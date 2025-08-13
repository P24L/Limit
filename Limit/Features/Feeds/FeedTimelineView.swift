//
//  FeedTimelineView.swift
//  Limit
//
//  Created by Claude Code on 15.07.2025.
//

import SwiftUI
import ATProtoKit
import SwiftData

struct FeedTimelineView: View {
    let feedURI: String
    let feedDisplayName: String
    
    @Environment(BlueskyClient.self) private var client
    
    @State private var posts: [TimelinePostWrapper] = []
    @State private var isLoading = false
    @State private var cursor: String? = nil
    @State private var hasMoreContent = true
    
    var body: some View {
        ZStack {
            if posts.isEmpty && isLoading {
                ProgressView("Loading feed...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if posts.isEmpty && !isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "text.append")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No posts in this feed")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(posts, id: \.id) { postWrapper in
                            PostItemWrappedView(post: postWrapper, isThreadView: false, postViewType: .timeline, showCard: true)
                                .id(postWrapper.id)
                        }
                        
                        // Load more indicator
                        if hasMoreContent && !posts.isEmpty {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Pull to load more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .onAppear {
                                Task {
                                    await loadMorePosts()
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    await loadFeed(refresh: true)
                }
            }
        }
        .navigationTitle(feedDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFeed()
        }
    }
    
    private func loadFeed(refresh: Bool = false) async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        if refresh {
            cursor = nil
            hasMoreContent = true
        }
        
        do {
            guard let protoClient = client.protoClient else {
                DevLogger.shared.log("FeedTimelineView - No proto client available")
                return
            }
            
            let output = try await protoClient.getFeed(
                by: feedURI,
                limit: 25,
                cursor: refresh ? nil : cursor
            )
            
            let newPosts = output.feed.compactMap { feedViewPost in
                TimelinePostWrapper(from: feedViewPost)
            }
            
            if refresh {
                posts = newPosts
            } else {
                posts.append(contentsOf: newPosts)
            }
            
            cursor = output.cursor
            hasMoreContent = output.cursor != nil && !newPosts.isEmpty
            
            DevLogger.shared.log("FeedTimelineView - Loaded \(newPosts.count) posts from feed: \(feedDisplayName)")
        } catch {
            DevLogger.shared.log("FeedTimelineView - Failed to load feed: \(error)")
        }
    }
    
    private func loadMorePosts() async {
        guard hasMoreContent && cursor != nil && !isLoading else { return }
        await loadFeed(refresh: false)
    }
}