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
    @Environment(MultiAccountClient.self) private var client
    @Environment(TimelineFeed.self) private var feed
    @Environment(CurrentUser.self) private var currentUser
    @AppStorage("showRepliesToOthers") private var showRepliesToOthers: Bool = true
    
    // Hybrid approach: scrollPosition API + TimelinePositionManager
    @State private var scrolledID: String? = nil
    @State private var isRestoringPosition = false
    @State private var isScrolling: Bool = false

    @Binding var newPostsAboveCount: Int
    @Binding var hideDirectionIsUp: Bool
    @Binding var isTopbarHidden: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
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
        .contentMargins(.top, 100)
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
            // Always update new posts count when position changes
            if let newID {
                let visible = posts.filter { isVisible($0) }
                if let index = visible.firstIndex(where: { $0.uri == newID }) {
                    newPostsAboveCount = index
                } else {
                    newPostsAboveCount = 0
                }
                
                // Save position only on genuine user scrolls (not programmatic changes)
                if isScrolling && !isRestoringPosition {
                    DevLogger.shared.log("TimelinePostList - SAVING position: \(newID), isScrolling: \(isScrolling)")
                    TimelinePositionManager.shared.saveTimelinePosition(newID)
                } else {
                    DevLogger.shared.log("TimelinePostList - NOT SAVING position: \(newID), isScrolling: \(isScrolling), isRestoringPosition: \(isRestoringPosition)")
                }
            }
        }
        .onChange(of: posts) { oldPosts, newPosts in
            // Always try to restore position for current user
            // (TimelinePositionManager automatically uses the correct key for current user)
            let visibleNew = newPosts.filter { wrapper in
                if showRepliesToOthers { return true }
                if let root = wrapper.rootPost { return root.authorID == wrapper.authorID }
                return true
            }
            
            // Always update new posts count first (even when scrolling)
            if let currentID = scrolledID,
               let index = visibleNew.firstIndex(where: { $0.uri == currentID }) {
                newPostsAboveCount = index
            } else {
                newPostsAboveCount = 0
            }
            
            // Skip ONLY position restore if user is actively scrolling
            if isScrolling {
                DevLogger.shared.log("TimelinePostList - Skipping position restore, user is scrolling")
                return  // Exit here - after updating count but before restore
            }
            
            // Position restore logic (only when not scrolling)
            if !isRestoringPosition,
               !visibleNew.isEmpty,
               let savedPosition = TimelinePositionManager.shared.getTimelinePosition(),
               visibleNew.contains(where: { $0.uri == savedPosition }) {
                
                DevLogger.shared.log("TimelinePostList - onChange(posts) - Attempting restore, saved: \(savedPosition), found: true")
                isRestoringPosition = true
                scrolledID = savedPosition
                DevLogger.shared.log("TimelinePostList - RESTORED position to: \(savedPosition)")
                
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    isRestoringPosition = false
                }
            } else if !visibleNew.isEmpty && scrolledID == nil {
                // If no saved position or post doesn't exist, go to the beginning
                DevLogger.shared.log("TimelinePostList - Setting to FIRST post: \(visibleNew.first?.uri ?? "nil"), scrolledID was: \(scrolledID ?? "nil")")
                scrolledID = visibleNew.first?.uri
            }
        }
        .task {
            // Restore saved position on initial load
            let initialVisible = posts.filter { isVisible($0) }
            restoreScrollPosition(posts: initialVisible)
        }
        .onAppear {
            DevLogger.shared.log("TimeLinePostList.swift - Main timeline loaded with scrollPosition API")
        }
    }
    
    @ViewBuilder
    func postView(for wrapper: TimelinePostWrapper) -> some View {
        if !isVisible(wrapper) {
            Color.clear
                .frame(height: 0)
                .id(wrapper.uri)
                .padding(.vertical, 0)
        } else {
            let currentIndex = posts.firstIndex { $0.id == wrapper.id }
            let previousWrapper = currentIndex.flatMap { index in
                return previousVisible(before: index)
            }
            let nextWrapper = currentIndex.flatMap { index in
                return nextVisible(after: index)
            }

            PostItemWrappedView(
                post: wrapper,
                depth: 0,
                previousPostID: previousWrapper?.uri,
                previousPostThreadRootID: previousWrapper?.rootPost?.uri ?? previousWrapper?.uri,
                nextPostID: nextWrapper?.uri,
                nextPostThreadRootID: nextWrapper?.rootPost?.uri
            )
            .id(wrapper.uri)
            .padding(.vertical, 4)
        }
    }
    
    private func restoreScrollPosition(posts: [TimelinePostWrapper]) {
        // Only try to restore if there are posts to scroll to
        guard !posts.isEmpty else { return }

        if let savedID = TimelinePositionManager.shared.getTimelinePosition(),
           posts.contains(where: { $0.uri == savedID }) {
            DevLogger.shared.log("TimelinePostList - restoreScrollPosition: saved: \(savedID), found in posts: true")
            isRestoringPosition = true
            scrolledID = savedID
            
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                isRestoringPosition = false
            }
        }
    }
    
    // MARK: - Visibility Helpers
    private func isVisible(_ wrapper: TimelinePostWrapper) -> Bool {
        if showRepliesToOthers { return true }
        // Non-reply posts are always visible
        guard let root = wrapper.rootPost else { return true }
        // Show only replies where author == root author (self-thread)
        return root.authorID == wrapper.authorID
    }

    private func nextVisible(after index: Int) -> TimelinePostWrapper? {
        guard index < posts.count else { return nil }
        var i = index + 1
        while i < posts.count {
            let candidate = posts[i]
            if isVisible(candidate) { return candidate }
            i += 1
        }
        return nil
    }
    
    private func previousVisible(before index: Int) -> TimelinePostWrapper? {
        guard index > 0 else { return nil }
        var i = index - 1
        while i >= 0 {
            let candidate = posts[i]
            if isVisible(candidate) { return candidate }
            i -= 1
        }
        return nil
    }

    func loadOlderPostsIfNeeded() async {
        guard !client.isLoading else { return }

        await feed.loadOlderTimeline()
        NotificationCenter.default.post(name: .didLoadOlderPosts, object: nil)

    }
}
