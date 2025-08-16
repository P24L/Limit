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
    @Environment(BlueskyClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    let postThread: TimelinePostWrapper
    
    // Simplified state - just one array for all posts
    @State private var posts: [TimelinePostWrapper] = []
    @State private var scrolledID: String? = nil
    
    var body: some View {
        Group {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(posts, id: \.id) { post in
                        PostItemWrappedView(post: post, isThreadView: true, showCard: true)
                            .id(post.uri)  // Use URI instead of ID for stable anchoring
                    }
                }
                .padding(.horizontal, 6)
                .background(.warmBackground)
                .scrollTargetLayout()
            }
            .contentMargins(.bottom, 500)
            .scrollPosition(id: $scrolledID, anchor: .top)
            .task {
                // 1. Show the main post immediately
                posts = [postThread]
                scrolledID = postThread.uri  // Use URI for stable reference
                
                // 2. Fetch and replace with full thread
                let threadPosts = await client.fetchThreadWrapped(for: postThread.uri)
                if !threadPosts.isEmpty {
                    posts = threadPosts
                    // scrollPosition API will maintain position on postThread.uri automatically!
                }
            }
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    router.presentedSheet = .aiExplanation(type: .thread(Array(posts.prefix(10))))
                } label: {
                    Image(systemName: "sparkles")
                }
            }
        }
    }
}
