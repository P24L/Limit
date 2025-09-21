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
    @State private var hasLoadedThread = false
    
    // Adjust depth values for better visual display
    private func adjustDepthForDisplay(_ threadPosts: [(post: TimelinePostWrapper, depth: Int)]) -> [(post: TimelinePostWrapper, depth: Int)] {
        guard !threadPosts.isEmpty else { return threadPosts }
        
        // Build parent-child relationships map
        var childrenCount: [String: Int] = [:]
        var parentMap: [String: String] = [:]
        
        // First pass: count children for each post
        for i in 0..<threadPosts.count {
            let current = threadPosts[i]
            
            // Find parent (previous post with depth - 1)
            for j in stride(from: i - 1, through: 0, by: -1) {
                let candidate = threadPosts[j]
                if candidate.depth == current.depth - 1 {
                    parentMap[current.post.uri] = candidate.post.uri
                    childrenCount[candidate.post.uri, default: 0] += 1
                    break
                }
            }
        }
        
        // Second pass: adjust depths
        var adjustedPosts: [(post: TimelinePostWrapper, depth: Int)] = []
        var depthAdjustment: [String: Int] = [:]
        
        for i in 0..<threadPosts.count {
            let current = threadPosts[i]
            let uri = current.post.uri
            
            // Determine if depth should be increased
            var newDepth = current.depth
            
            if let parentURI = parentMap[uri] {
                let parentChildCount = childrenCount[parentURI] ?? 0
                let parentAdjustment = depthAdjustment[parentURI] ?? 0
                
                // Only increase depth if:
                // 1. Parent has multiple children (branching)
                // 2. OR this is a different author than parent (visual separation)
                if parentChildCount > 1 {
                    // Real branching - keep the depth increase
                    newDepth = current.depth + parentAdjustment
                } else {
                    // Linear sequence - use parent's depth
                    let parentIndex = threadPosts.firstIndex(where: { $0.post.uri == parentURI })
                    if let parentIndex = parentIndex {
                        let parentPost = threadPosts[parentIndex]
                        // Check if same author
                        if current.post.authorID == parentPost.post.authorID {
                            // Same author, linear thread - keep same depth
                            newDepth = parentPost.depth + parentAdjustment
                            depthAdjustment[uri] = parentAdjustment - 1
                        } else {
                            // Different author - allow depth increase for visual clarity
                            newDepth = current.depth + parentAdjustment
                        }
                    }
                }
            }
            
            adjustedPosts.append((post: current.post, depth: max(0, newDepth)))
        }
        
        // Normalize depths to remove gaps
        let uniqueDepths = Set(adjustedPosts.map { $0.depth }).sorted()
        var depthMapping: [Int: Int] = [:]
        for (index, depth) in uniqueDepths.enumerated() {
            depthMapping[depth] = index
        }
        
        return adjustedPosts.map { item in
            (post: item.post, depth: depthMapping[item.depth] ?? item.depth)
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(posts, id: \.post.uri) { item in
                    PostItemWrappedView(
                        post: item.post,
                        isThreadView: true,
                        showCard: true,
                        threadDepth: item.depth,
                        useListStyle: true
                    )
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: 6,
                        bottom: 0,
                        trailing: 6
                    ))
                    .listRowBackground(Color.warmBackground)
                    .listRowSeparator(.hidden)
                    .id(item.post.uri)
                }

                Color.clear
                    .frame(height: 300)
                    .listRowInsets(.init())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.warmBackground)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.warmBackground)
            .safeAreaInset(edge: .top) {
                Color.warmBackground
                    .frame(height: 12)
            }
            .task {
                guard !hasLoadedThread else { return }
                hasLoadedThread = true

                // 1. Show the tapped post immediately for instant feedback
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        posts = [(post: postThread, depth: 0)]
                    }
                }
                await scrollToAnchor(proxy: proxy)

                // 2. Load the full thread and preserve the tapped post position
                let threadPosts = await client.fetchThreadWrapped(for: postThread.uri)
                guard !threadPosts.isEmpty else { return }

                let adjusted = adjustDepthForDisplay(threadPosts)

                guard let anchorIndex = adjusted.firstIndex(where: { $0.post.uri == postThread.uri }) else {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            posts = adjusted
                        }
                    }
                    return
                }

                let anchor = adjusted[anchorIndex]
                let prefix = Array(adjusted.prefix(anchorIndex))
                let suffix = Array(adjusted.suffix(from: anchorIndex + 1))

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        posts = [anchor]
                    }
                }
                await scrollToAnchor(proxy: proxy)

                if !prefix.isEmpty {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            posts.insert(contentsOf: prefix, at: 0)
                        }
                    }
                    await scrollToAnchor(proxy: proxy)
                }

                if !suffix.isEmpty {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            posts.append(contentsOf: suffix)
                        }
                    }
                }
            }
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
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

private extension ThreadWrappedView {
    func scrollToAnchor(proxy: ScrollViewProxy) async {
        await MainActor.run {
            withAnimation(nil) {
                proxy.scrollTo(postThread.uri, anchor: .top)
            }
        }
    }
}
