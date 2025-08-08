//
//  TimelinePostList.swift
//  Limit
//
//  Created by Zdenek Indra on 24.06.2025.
//

import AppRouter
import ATProtoKit
import Foundation
import SwiftData
import SwiftUI

struct ThreadConnectionView: View {
    var body: some View {
        Rectangle()
            .fill(.mintInactive)
            .frame(width: 2)
            .frame(height: 80) // Spans between cards
    }
}

struct TimelinePostList: View {
    let posts: [TimelinePostWrapper]

    @Environment(\.modelContext) private var context
    @Environment(BlueskyClient.self) private var client
    @Environment(TimelineFeed.self) private var feed
    
    // Hybrid approach: scrollPosition API + TimelinePositionManager
    @State private var scrolledID: String? = nil
    @State private var shouldMaintainPosition = false
    @State private var isScrolling: Bool = false
    @State private var isInitialLoad: Bool = true

    @Binding var newPostsAboveCount: Int
    @Binding var hideDirectionIsUp: Bool
    @Binding var isTopbarHidden: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear
                    .frame(height: 100) // Výška topbaru + safe area margin
                ForEach(posts) { wrapper in
                    postView(for: wrapper)
                }
                if client.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 20)
                        Spacer()
                    }
                }
                
                // trigger načtení dalších postů
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task {
                            await feed.loadOlderTimeline()
                            NotificationCenter.default.post(name: .didLoadOlderPosts, object: nil)
                        }
                    }
            }
            .padding(.horizontal, 6)
            .background(.warmBackground)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledID, anchor: .top)
        .onScrollPhaseChange { old, new in
            isScrolling = new != .idle
            if new == .tracking || new == .interacting {
                isTopbarHidden = true
            } else if new == .idle {
                isTopbarHidden = false
            }
        }
        .onChange(of: scrolledID) { _, newID in
            // Save position when user scrolls (not during programmatic changes)
            if !shouldMaintainPosition, let newID {
                TimelinePositionManager.shared.saveTimelinePosition(newID)
                
                // Update new posts count
                if let index = posts.firstIndex(where: { $0.uri == newID }) {
                    newPostsAboveCount = index
                } else {
                    newPostsAboveCount = 0
                }
            }
        }
        .onChange(of: posts) { oldPosts, newPosts in
            // Handle prepend operation - maintain scroll position
            if !oldPosts.isEmpty && !newPosts.isEmpty {
                // Check if this is a prepend (new posts at beginning)
                let oldFirstID = oldPosts.first?.uri
                let newFirstID = newPosts.first?.uri
                
                if oldFirstID != newFirstID {
                    // This is likely a prepend operation
                    if let currentScrolledID = scrolledID,
                       newPosts.contains(where: { $0.uri == currentScrolledID }) {
                        // The previously visible post still exists, maintain position
                        shouldMaintainPosition = true
                        scrolledID = currentScrolledID
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            shouldMaintainPosition = false
                        }
                    }
                }
            }
        }
        .task {
            // Restore saved position on initial load
            if isInitialLoad {
                if let savedID = TimelinePositionManager.shared.getTimelinePosition(),
                   posts.contains(where: { $0.uri == savedID }) {
                    shouldMaintainPosition = true
                    scrolledID = savedID
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shouldMaintainPosition = false
                        isInitialLoad = false
                    }
                } else {
                    isInitialLoad = false
                }
            }
        }
        .onAppear {
            DevLogger.shared.log("TimeLinePostList.swift - Main timeline loaded with scrollPosition API")
        }
    }
    
    @ViewBuilder
    func postView(for wrapper: TimelinePostWrapper) -> some View {
        let currentIndex = posts.firstIndex { $0.id == wrapper.id }
        let nextWrapper = currentIndex.flatMap { index in
            index + 1 < posts.count ? posts[index + 1] : nil
        }

        PostItemWrappedView(
            post: wrapper,
            depth: 0,
            nextPostID: nextWrapper?.uri,
            nextPostThreadRootID: nextWrapper?.rootPost?.uri,
        )
        .id(wrapper.uri)
        .padding(.vertical, 4)
    }
    
    func loadOlderPostsIfNeeded() async {
        guard !client.isLoading else { return }

        await feed.loadOlderTimeline()
        NotificationCenter.default.post(name: .didLoadOlderPosts, object: nil)

    }
}