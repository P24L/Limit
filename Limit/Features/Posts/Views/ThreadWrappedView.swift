//
//  ThreadWrappedView.swift
//  Limit
//
//  Created by Zdenek Indra on 14.06.2025.
//

import SwiftData
import SwiftUI

struct ThreadWrappedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(MultiAccountClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    let postThread: TimelinePostWrapper
    
    // Simplified state - array of posts with their depth in thread
    @State private var posts: [(post: TimelinePostWrapper, depth: Int)] = []
    @State private var scrolledID: String? = nil
    @State private var hasLoadedThread = false
    
    var body: some View {
        Group {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(posts, id: \.post.id) { item in
                        PostItemWrappedView(
                            post: item.post, 
                            isThreadView: true, 
                            showCard: true,
                            threadDepth: item.depth
                        )
                        .id(item.post.uri)  // Use URI instead of ID for stable anchoring
                    }
                }
                .padding(.horizontal, 6)
                .background(.warmBackground)
                .scrollTargetLayout()
            }
            .contentMargins(.bottom, 500)
            .scrollPosition(id: $scrolledID, anchor: .center)
            .task {
                // Only load thread if not already loaded
                if !hasLoadedThread {
                    hasLoadedThread = true
                    
                    // 1. Show the main post immediately (without depth info initially)
                    posts = [(post: postThread, depth: 0)]
                    scrolledID = postThread.uri
                    
                    // 2. Fetch full thread with depth information
                    let threadPosts = await client.fetchThreadWrapped(for: postThread.uri)
                    if !threadPosts.isEmpty {
                        // Replace with the full thread (now with correct depth values)
                        posts = threadPosts
                        
                        // Keep scroll position on the original post
                        // The post will now have its correct depth assigned
                        scrolledID = postThread.uri
                    }
                }
            }
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Extract just the posts for AI explanation
                    let postsForAI = Array(posts.prefix(10).map { $0.post })
                    router.presentedSheet = .aiExplanation(type: .thread(postsForAI))
                } label: {
                    Image(systemName: "sparkles")
                }
            }
        }
    }
}
