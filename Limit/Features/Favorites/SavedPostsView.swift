//
//  SavedPostsView.swift
//  Limit
//
//  Created by Assistant on 06.01.2025.
//

import SwiftUI
import SwiftData

struct SavedPostsView: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(FavoritePostManager.self) private var favoritesPost
    @State private var posts: [TimelinePostWrapper]? = nil
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding()
            } else if let posts = posts {
                LazyVStack(spacing: 8) {
                    if posts.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("No saved posts")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Posts you like will appear here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 60)
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(posts, id: \.id) { post in
                            PostItemWrappedView(post: post, isThreadView: true)
                                .id(post.id)
                        }
                    }
                }
                .padding(15)
                .background(.warmBackground)
            }
        }
        .navigationTitle("Saved Posts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSavedPosts()
        }
    }
    
    private func loadSavedPosts() async {
        isLoading = true
        let ids = favoritesPost.favorites.map { $0.postID }
        if ids.count > 0 {
            let rawPosts = await client.fetchPostWrappersByID(for: ids)
            if rawPosts.count > 0 {
                posts = rawPosts.sorted { $0.createdAt > $1.createdAt }
            }
        } else {
            posts = []
        }
        isLoading = false
    }
}