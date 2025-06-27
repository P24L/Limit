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
    
    let postThread: TimelinePostWrapper
    
    @State private var posts: [TimelinePostWrapper]? = nil
    @State private var beforePosts: [TimelinePostWrapper] = []
    @State private var afterPosts: [TimelinePostWrapper] = []
    
    @State private var scrollToId: TimelinePostWrapper.ID? = nil
    
    var body: some View {
            Group {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(beforePosts, id: \.id) { post in
                                PostItemWrappedView(post: post, isThreadView: true)
                                    .id(post.id)
                            }
                            PostItemWrappedView(post: postThread, isThreadView: true)
                                .id(postThread.id)
                                .defaultScrollAnchor(.topLeading)
                                
                            ForEach(afterPosts, id: \.id) { post in
                                PostItemWrappedView(post: post, isThreadView: true)
                                    .id(post.id)
                            }
                            VStack {}.frame(height: 300)
                        }
                        .padding()
                        .scrollTargetLayout()
                        .onChange(of: scrollToId) { _, newID in
                            if let id = newID {
                                DispatchQueue.main.async {
                                    proxy.scrollTo(id, anchor: .top)
                                }
                            }
                        }
                    }
                    .task {
                        posts = try? await client.fetchThreadWrapped(for: postThread.uri)

                        if let allPosts = posts {
                            let cleanedPosts = allPosts

                            if let centerIndex = cleanedPosts.firstIndex(where: { $0.cid == postThread.cid })  {
                                if centerIndex > 0 {
                                    // Slicing od začátku až po index (nezahrnujeme element na centerIndex)
                                    beforePosts = Array(cleanedPosts[..<centerIndex])
                                    scrollToId = postThread.id
                                }
                                let nextIndex = centerIndex + 1
                                if nextIndex < cleanedPosts.count {
                                    // Slicing od indexu za středovým postem až na konec
                                    afterPosts = Array(cleanedPosts[nextIndex...])
                                }
                            }
                        }
                    }
                }


        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }
}
