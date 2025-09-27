//
//  TimelinePostList.swift
//  Limit
//
//  Created by Zdenek Indra on 24.06.2025.
//

import AppRouter
import ATProtoKit
import Foundation
import SwiftUI

struct ThreadConnectionView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Rectangle()
            .fill(themeManager.colors.accentMuted)
            .frame(width: 2)
            .frame(height: 80) // Spans between cards
    }
}

struct TimelinePostList: View {
    @Bindable var viewModel: HomeTimelineViewModel

    @Environment(MultiAccountClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var appRouter
    @Environment(ThemeManager.self) private var themeManager
    @Environment(UserPreferences.self) private var userPreferences

    @State private var isProgrammaticScroll = false
    @State private var hasUserInteracted = false
    @State private var isLoadingMore: Bool = false
    @State private var hasReachedEnd: Bool = false
    @State private var visiblePostIDs: Set<String> = []

    @Binding var newPostsAboveCount: Int

    private var posts: [TimelinePostWrapper] { viewModel.posts }
    private let positionTrackingEnabled = true

    var body: some View {
        @Bindable var router = appRouter
        let colors = themeManager.colors

        ScrollViewReader { proxy in
            List {
            ForEach(posts) { wrapper in
                if isVisible(wrapper) {
                    postItemForList(for: wrapper)
                        .id(wrapper.uri)
                        .listRowInsets(EdgeInsets(
                            top: 4,
                            leading: 6,
                            bottom: 4,
                            trailing: 6
                        ))
                        .listRowBackground(colors.backgroundListRow)
                        .listRowSeparator(.visible, edges: .bottom)
                        .onAppear {
                            guard positionTrackingEnabled else { return }
                            if viewModel.isRestoringPosition,
                               viewModel.pendingRestoreID == wrapper.uri {
                                DevLogger.shared.log("TimelinePostList - ✅ Restore target appeared: \(wrapper.uri)")
                                viewModel.completePositionRestore(for: wrapper.uri)
                                viewModel.postDidAppear(id: wrapper.uri)
                                Task { @MainActor in
                                    isProgrammaticScroll = false
                                    visiblePostIDs.insert(wrapper.uri)
                                    updateNewPostsIndicator()
                                }
                            } else {
                                viewModel.postDidAppear(id: wrapper.uri)
                                visiblePostIDs.insert(wrapper.uri)
                                updateNewPostsIndicator()
                            }
                        }
                        .onDisappear {
                            guard positionTrackingEnabled else { return }
                            viewModel.postDidDisappear(id: wrapper.uri)
                            visiblePostIDs.remove(wrapper.uri)
                            updateNewPostsIndicator()
                        }
                }
            }

            // Loading indicator when fetching more posts
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.accent))
                        .padding(.vertical, 20)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }

            // trigger načtení dalších postů nebo konec timeline
            if hasReachedEnd {
                // End of timeline indicator
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(colors.accent)
                    Text("You've reached the end")
                        .font(.caption)
                        .foregroundColor(colors.textSecondary)
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            } else {
                LoadMoreTriggerView()
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .id("load-more-trigger")
                    .onAppear {
                        Task {
                            await loadMoreIfNeeded()
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }

            // Extra padding at bottom to ensure trigger is visible
            Color.clear
                .frame(height: 50)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(colors.backgroundCanvas)
            .contentMargins(.top, 12)
            .contentMargins(.bottom, 100)
            .onScrollPhaseChange { _, new in
                if new == .tracking || new == .interacting {
                    if positionTrackingEnabled {
                        hasUserInteracted = true
                        viewModel.userDidInteract()
                    }
                }
            }
            .onChange(of: viewModel.scrollTargetID) { _, newValue in
                guard let target = newValue else { return }
                isProgrammaticScroll = true
                hasUserInteracted = false
                DevLogger.shared.log("TimelinePostList - Restoring scroll position to: \(target)")
                proxy.scrollTo(target, anchor: .top)
                // Clear the trigger so we scroll only once
                viewModel.clearScrollTarget()
            }
            .onChange(of: posts) { oldPosts, newPosts in
                if newPosts.count > oldPosts.count {
                    hasReachedEnd = false
                }

                if viewModel.isRestoringPosition {
                    viewModel.retryRestoreIfNeeded()
                }

                visiblePostIDs = visiblePostIDs.intersection(Set(newPosts.map { $0.uri }))
                updateNewPostsIndicator()
            }
            .onAppear {
                if let target = viewModel.targetForInitialDisplay() {
                    DevLogger.shared.log("TimelinePostList - Attempting initial scroll restore to: \(target)")
                    isProgrammaticScroll = true
                    hasUserInteracted = false
                    proxy.scrollTo(target, anchor: .top)
                }
                viewModel.resetInteractionState(with: viewModel.pendingRestoreID ?? viewModel.currentScrollPosition)
            }
        } // End of ScrollViewReader
        .onAppear {
            hasUserInteracted = false
        }
        .onDisappear {
            let activeTab = router.selectedTab
            if !router[activeTab].isEmpty {
                return
            }
            viewModel.prepareForTemporaryRemoval()
        }
    }
    
    @ViewBuilder
    func postItemForList(for wrapper: TimelinePostWrapper) -> some View {
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
            nextPostThreadRootID: nextWrapper?.rootPost?.uri,
            useListStyle: true  // Use List-based rendering
        )
    }


    // MARK: - Position Tracking
    private func updateNewPostsIndicator() {
        for (index, post) in posts.enumerated() where isVisible(post) {
            if visiblePostIDs.contains(post.uri) {
                newPostsAboveCount = index
                return
            }
        }
        newPostsAboveCount = 0
    }

    // MARK: - Visibility Helpers
    private func isVisible(_ wrapper: TimelinePostWrapper) -> Bool {
        if wrapper.isReplyToOthers,
           userPreferences.isRepliesMuted(forDid: wrapper.authorID) {
            return false
        }

        if userPreferences.showRepliesToOthers { return true }
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
        await viewModel.loadOlderTimeline()
    }
    
    private func loadMoreIfNeeded() async {
        // Don't try to load if we've reached the end or already loading
        guard !hasReachedEnd, !isLoadingMore, !client.isLoading else { return }
        
        // Mark as loading
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        // Store count before loading
        let countBefore = posts.count
        
        // Load older posts
        await viewModel.loadOlderTimeline()

        // Check if we got new posts
        let countAfter = posts.count
        let newPostsAdded = countAfter > countBefore

        // If no new posts were added and feed has no cursor, we've reached the end
        if !newPostsAdded && !viewModel.hasMoreOlderPosts {
            hasReachedEnd = true
        }
    }
}

struct LoadMoreTriggerView: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
    }
}
