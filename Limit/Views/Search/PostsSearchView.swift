//
//  PostsSearchView.swift
//  Limit
//
//  Created by Claude on 01.07.2025.
//

import SwiftUI
import ATProtoKit

struct PostsSearchView: View {
    @Environment(BlueskyClient.self) private var client
    
    let query: String
    
    @State private var posts: [TimelinePostWrapper] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var error: Error?
    @State private var cursor: String?
    @State private var hitsTotal: Int?
    
    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                ProgressView("Searching posts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, posts.isEmpty {
                VStack {
                    Text("Error searching posts")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await searchPosts()
                        }
                    }
                    .padding(.top)
                }
                .padding()
            } else if posts.isEmpty && !query.isEmpty {
                VStack {
                    Text("No posts found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try different search terms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if let hitsTotal {
                            HStack {
                                Text("Found \(hitsTotal) posts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        
                        ForEach(posts) { post in
                            PostItemWrappedView(post: post, depth: 0, nextPostID: nil, nextPostThreadRootID: nil, showCard: true)
                        }
                        
                        if cursor != nil {
                            Button("Load more") {
                                Task {
                                    await loadMorePosts()
                                }
                            }
                            .disabled(isLoadingMore)
                            .padding()
                            
                            if isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .background(.warmBackground)
                }
                .refreshable {
                    await searchPosts()
                }
            }
        }
        .task(id: query) {
            guard !query.isEmpty else { return }
            await searchPosts()
        }
    }
    
    private func searchPosts() async {
        guard !isLoading else { return }
        guard client.isAuthenticated, let protoClient = client.protoClient else { return }
        guard !query.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let result = await client.performAuthenticatedRequest {
            try await protoClient.searchPosts(
                matching: query,
                limit: 25
            )
        }
        
        await MainActor.run {
            if let response = result {
                self.posts = response.posts.compactMap { TimelinePostWrapper(from: $0) }
                self.cursor = response.cursor
                self.hitsTotal = response.hitsTotal
                self.error = nil
            } else {
                self.error = NSError(domain: "PostsSearchView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to search posts"])
                self.posts = []
                self.cursor = nil
                self.hitsTotal = nil
            }
        }
    }
    
    private func loadMorePosts() async {
        guard !isLoadingMore else { return }
        guard client.isAuthenticated, let protoClient = client.protoClient else { return }
        guard let cursor = cursor else { return }
        guard !query.isEmpty else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        let result = await client.performAuthenticatedRequest {
            try await protoClient.searchPosts(
                matching: query,
                limit: 25,
                cursor: cursor
            )
        }
        
        await MainActor.run {
            if let response = result {
                let newPosts = response.posts.compactMap { TimelinePostWrapper(from: $0) }
                // Filter out duplicates by URI
                let existingURIs = Set(self.posts.map { $0.uri })
                let uniqueNewPosts = newPosts.filter { !existingURIs.contains($0.uri) }
                
                self.posts.append(contentsOf: uniqueNewPosts)
                self.cursor = response.cursor
                // Don't update hitsTotal on pagination
            } else {
                // On pagination error, just log but don't clear existing results
                DevLogger.shared.log("PostsSearchView - loadMorePosts error: Failed to load more posts")
            }
        }
    }
}

#Preview {
    PostsSearchView(query: "test")
        .environment(BlueskyClient())
}