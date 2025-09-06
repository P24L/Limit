//
//  ATTimelineView_experimental.swift
//  Limit
//
//  Created by Zdenek Indra on 01.06.2025.
//


import ATProtoKit
import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor
struct ATTimelineView_experimental: View {
    @Environment(MultiAccountClient.self) private var client
    @Environment(\.modelContext) var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TimelineFeed.self) private var feed
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var router
    @Environment(ComputedTimelineFeed.self) private var computedFeed
    @Environment(BookmarkManager.self) private var bookmarkManager

    enum ViewState {
        case loading
        case error(Error)
        case posts([TimelinePostWrapper])
        case content(TimelineContentSource)
    }
    
    enum TopbarTab: Equatable {
        case timeline
        case aline
        case trendingPosts
        case list(Int)
        case feed(Int)
        
        var color: Color {
            switch self {
            case .timeline:
                return .mintAccent
            case .aline:
                return .blue
            case .trendingPosts:
                return Color(red: 0.557, green: 0.267, blue: 0.678) // #8E44AD royalPurple
            case .list:
                return .yellow
            case .feed:
                return .yellow
            }
        }
        
        var icon: String {
            switch self {
            case .timeline:
                return "house.fill"
            case .aline:
                return "sparkles"
            case .trendingPosts:
                return "arrowshape.up.fill"
            case .list:
                return "list.bullet"
            case .feed:
                return "square.stack.3d.up"
            }
        }
        
        var title: String {
            switch self {
            case .timeline:
                return "Home"
            case .aline:
                return "A-line"
            case .trendingPosts:
                return "Trending"
            case .list:
                return "Lists"
            case .feed:
                return "Feeds"
            }
        }
    }

    @State private var viewState: ViewState = .loading
    @State private var lastRefresh: Date = Date().addingTimeInterval(-60)
    @State private var hideDirectionIsUp: Bool = true
    @State private var isTopbarHidden = false
    @State private var isExpandedTopbar = false
    @State private var newPostsAboveCount: Int = 0
    
    @State private var selectedTab: TopbarTab = .timeline
    @State private var isRefreshingAline = false
    @State private var isRefreshingTimeline = false
    @State private var showBookmarkConfirmation = false
    @State private var lastBookmarkId: String?
    
    // Swipe gesture state (UI preview removed; no offset tracking needed)
    
    private var shouldShowSecondaryBar: Bool {
        switch selectedTab {
        case .list, .feed:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Timeline content fills entire screen
            timelineContent
                .ignoresSafeArea(.container, edges: .top)
            
            // Floating topbar container
            topbarContainer
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldShowSecondaryBar)
        .task {
            switch selectedTab {
            case .timeline:
                // Show cached posts immediately
                if feed.posts.isEmpty {
                    feed.loadFromStorage()
                }
                viewState = .posts(feed.postTimeline)
                
                // Refresh timeline in background
                Task {
                    DevLogger.shared.log("ATTimelineView - Initial refresh starting")
                    isRefreshingTimeline = true
                    await feed.refreshTimeline()
                    DevLogger.shared.log("ATTimelineView - Initial refresh completed, updating viewState")
                    await MainActor.run {
                        viewState = .posts(feed.postTimeline)
                        // ScrollPosition API will handle position restoration automatically
                        isRefreshingTimeline = false
                    }
                }
            case .aline:
                // For A-line, we'll show computed timeline posts
                await computedFeed.loadPosts(client: client)
                viewState = .posts(computedFeed.posts)
            case .list, .feed, .trendingPosts:
                viewState = getSelectedContent()
            }
        }
        .refreshable {
            switch selectedTab {
            case .timeline:
                isRefreshingTimeline = true
                await feed.refreshTimeline()
                viewState = .posts(feed.postTimeline)
                isRefreshingTimeline = false
                // ScrollPosition API will handle position restoration automatically
            case .aline:
                // A-line uses its own refresh button
                break
            case .list, .feed, .trendingPosts:
                viewState = getSelectedContent()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if selectedTab == .timeline && newPhase == .active {
                let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
                DevLogger.shared.log("ATTimelineView - Scene became active, time since last refresh: \(timeSinceRefresh)s")
                if timeSinceRefresh > 60 {
                    DevLogger.shared.log("ATTimelineView - Triggering auto-refresh on scene activation")
                    Task {
                        isRefreshingTimeline = true
                        await feed.refreshTimeline()
                        DevLogger.shared.log("ATTimelineView - Auto-refresh completed")
                        lastRefresh = .now
                        viewState = .posts(feed.postTimeline)
                        // ScrollPosition API will handle position restoration automatically
                        isRefreshingTimeline = false
                    }
                }
            } else if selectedTab == .aline && newPhase == .active {
                // Don't auto-refresh A-line on scene activation
            } else if selectedTab != .timeline && selectedTab != .aline && newPhase == .active {
                viewState = getSelectedContent()
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            Task {
                switch newValue {
                case .timeline:
                    viewState = .posts(feed.postTimeline)
                case .aline:
                    // For A-line, we'll show computed timeline posts
                    if computedFeed.posts.isEmpty {
                        await computedFeed.loadPosts(client: client)
                    }
                    viewState = .posts(computedFeed.posts)
                case .list, .feed, .trendingPosts:
                    viewState = getSelectedContent()
                }
            }
        }
        .saveConfirmationOverlay(show: $showBookmarkConfirmation, bookmarkId: lastBookmarkId)
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkSaved)) { notification in
            if let bookmarkId = notification.object as? String {
                lastBookmarkId = bookmarkId
            }
            showBookmarkConfirmation = true
        }
    }
    
    // MARK: Helper Functions
    
    // Computed property for available tabs
    private var availableTabs: [TopbarTab] {
        var tabs: [TopbarTab] = [.timeline, .aline, .trendingPosts]
        if !currentUser.lists.isEmpty {
            tabs.append(.list(0))
        }
        if !currentUser.feeds.isEmpty {
            tabs.append(.feed(0))
        }
        return tabs
    }
    
    // Helper function to get current tab index
    private func currentTabIndex() -> Int? {
        availableTabs.firstIndex { tab in
            switch (tab, selectedTab) {
            case (.timeline, .timeline), (.aline, .aline), (.trendingPosts, .trendingPosts):
                return true
            case (.list, .list), (.feed, .feed):
                return true
            default:
                return false
            }
        }
    }
    
    // Get next tab
    private func nextTab() -> TopbarTab? {
        guard let currentIndex = currentTabIndex() else { return nil }
        let nextIndex = currentIndex + 1
        if nextIndex < availableTabs.count {
            return availableTabs[nextIndex]
        }
        return nil
    }
    
    // Get previous tab
    private func previousTab() -> TopbarTab? {
        guard let currentIndex = currentTabIndex() else { return nil }
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            return availableTabs[previousIndex]
        }
        return nil
    }
    
    private func getSelectedContent() -> ViewState {
        switch selectedTab {
        case .list(let index):
            guard let list = currentUser.lists[safe: index] else {
                return .loading
            }
            return .content(.list(list))
        case .feed(let index):
            guard let feed = currentUser.feeds[safe: index] else {
                return .loading
            }
            return .content(.feed(feed))
        case .trendingPosts:
            return .content(.trendingPosts)
        default:
            return .loading
        }
    }

    @ViewBuilder
    private var topbarContainer: some View {
        let safeAreaTopInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.top }
            .first ?? 0
        let topbarHeight: CGFloat = 60
        let secondaryBarHeight: CGFloat = shouldShowSecondaryBar ? 44 : 0

        VStack(spacing: 0) {
            // Safe area spacer
            Color.clear
                .frame(height: (safeAreaTopInset - 10) > 0 ? safeAreaTopInset - 10 : safeAreaTopInset)
                .frame(maxWidth: .infinity)
            
            // Main topbar
            topbarView
            
            // Secondary bar (conditionally shown)
            if shouldShowSecondaryBar {
                secondaryBarView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .background(.warmBackground)
        .ignoresSafeArea(.container, edges: .top)
        .offset(y: isTopbarHidden ? -(safeAreaTopInset+topbarHeight + secondaryBarHeight+50) : 0)
        .animation(.easeInOut(duration: 0.5), value: isTopbarHidden)
        .zIndex(10)
    }
    
    // MARK: Topbar View
    @ViewBuilder
    private var topbarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Compose button
                Button {
                    router.presentedSheet = .composePost()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundColor(.mintAccent)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.mintAccent.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)
                
                // Timeline tab
                TabButton(
                    tab: .timeline,
                    isSelected: selectedTab == .timeline,
                    showText: selectedTab == .timeline,
                    badge: (selectedTab == .timeline && !isRefreshingTimeline && newPostsAboveCount > 0) ? "\(newPostsAboveCount.abbreviatedRounded)" : nil,
                    showRefresh: isRefreshingTimeline,
                    isRefreshing: isRefreshingTimeline,
                    refreshAction: isRefreshingTimeline ? { } : nil,
                    action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = .timeline } }
                )
                
                // A-line tab
                TabButton(
                    tab: .aline,
                    isSelected: selectedTab == .aline,
                    showText: selectedTab == .aline,
                    showRefresh: selectedTab == .aline,
                    isRefreshing: isRefreshingAline,
                    refreshAction: {
                        Task {
                            isRefreshingAline = true
                            await computedFeed.fastRefresh(client: client)
                            isRefreshingAline = false
                        }
                    },
                    action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = .aline } }
                )

                // Trending tab
                TabButton(
                    tab: .trendingPosts,
                    isSelected: selectedTab == .trendingPosts,
                    showText: selectedTab == .trendingPosts,
                    showRefresh: selectedTab == .trendingPosts,
                    action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = .trendingPosts } }
                )
                
                // Lists tab (if available)
                if !currentUser.lists.isEmpty {
                    TabButton(
                        tab: .list(0),
                        isSelected: isListOrFeedSelected(.list),
                        showText: isListOrFeedSelected(.list),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if case .list = selectedTab {
                                    // Already in lists
                                } else {
                                    selectedTab = .list(0)
                                }
                            }
                        }
                    )
                }
                
                // Feeds tab (if available)
                if !currentUser.feeds.isEmpty {
                    TabButton(
                        tab: .feed(0),
                        isSelected: isListOrFeedSelected(.feed),
                        showText: isListOrFeedSelected(.feed),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if case .feed = selectedTab {
                                    // Already in feeds
                                } else {
                                    selectedTab = .feed(0)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
        .background(
            Rectangle()
                .fill(.warmBackground)
        )
        .shadow(
            color: .subtleGray.opacity(0.3),
            radius: 1,
            x: 0,
            y: 1
        )

    }
    
    // MARK: Tab Button Component
    @ViewBuilder
    private func TabButton(
        tab: TopbarTab,
        isSelected: Bool,
        showText: Bool,
        badge: String? = nil,
        showRefresh: Bool = false,
        isRefreshing: Bool = false,
        refreshAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? 16 : 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .symbolEffect(.bounce, value: isSelected)
                
                if showText {
                    Text(tab.title)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(tab.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.white)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    if showRefresh, let refreshAction = refreshAction {
                        Button(action: refreshAction) {
                            if isRefreshing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                        }
                        .disabled(isRefreshing)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, showText ? 16 : 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? tab.color : Color.clear)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            )
        }
        .buttonStyle(.plain)
    }
    
    // Helper function to check if list or feed is selected
    private func isListOrFeedSelected(_ type: ListOrFeedType) -> Bool {
        switch (type, selectedTab) {
        case (.list, .list):
            return true
        case (.feed, .feed):
            return true
        default:
            return false
        }
    }
    
    private enum ListOrFeedType {
        case list
        case feed
    }
    
    // MARK: Secondary Bar View
    @ViewBuilder
    private var secondaryBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                switch selectedTab {
                case .list:
                    ForEach(Array(currentUser.lists.enumerated()), id: \.offset) { index, list in
                        SecondaryBarItem(
                            title: list.name,
                            isSelected: selectedTab == .list(index),
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = .list(index)
                                }
                            }
                        )
                    }
                case .feed:
                    ForEach(Array(currentUser.feeds.enumerated()), id: \.offset) { index, feed in
                        SecondaryBarItem(
                            title: feed.displayName,
                            isSelected: selectedTab == .feed(index),
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = .feed(index)
                                }
                            }
                        )
                    }
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
        .frame(height: 44)
        .clipped()
        .background(
            Rectangle()
                .fill(.subtleGray)
                .shadow(
                    color: .subtleGray.opacity(0.8),
                    radius: 1,
                    x: 0,
                    y: 1
                )
        )
        // With iOS 18 gestureMask on parent, no workaround gesture needed here
    }
    
    // MARK: Secondary Bar Item Component
    @ViewBuilder
    private func SecondaryBarItem(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? selectedTab.color : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? selectedTab.color.opacity(0.15) : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? selectedTab.color : Color.clear, lineWidth: 1.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var timelineContent: some View {
        Group {
            switch viewState {
            case .loading:
                ProgressPostsRedacted()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let error):
                ErrorView(title: "Chyba",
                          message: error.localizedDescription,
                          buttonTitle: "Zkusit znovu") {
                    Task {
                        await feed.refreshTimeline()
                    }
                }
            case .posts(let wrappers):
                if selectedTab == .aline {
                    // A-line computed timeline
                    ComputedTimelineContainer(
                        posts: wrappers,
                        isTopbarHidden: $isTopbarHidden
                    )
                    .onReceive(NotificationCenter.default.publisher(for: .didLoadComputedPosts)) { _ in
                        Task {
                            viewState = .posts(computedFeed.posts)
                        }
                    }
                } else {
                    // Regular timeline
                    TimelinePostList(
                        posts: wrappers,
                        newPostsAboveCount: $newPostsAboveCount,
                        hideDirectionIsUp: $hideDirectionIsUp,
                        isTopbarHidden: $isTopbarHidden
                    )
                    .onReceive(NotificationCenter.default.publisher(for: .didLoadOlderPosts)) { _ in
                        Task {
                            viewState = .posts(feed.postTimeline)
                        }
                    }
                }
            case .content(let source):
                ListTimelineView(source: source, isTopbarHidden: $isTopbarHidden)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { _ in }
                .onEnded { value in
                    let t = value.translation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        // Commit only for clear horizontal swipe beyond threshold
                        if abs(t.width) > abs(t.height) && abs(t.width) > 100 {
                            if t.width > 0 {
                                // Swipe right -> previous tab
                                if let prevTab = previousTab() {
                                    selectedTab = prevTab
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } else {
                                // Swipe left -> next tab
                                if let nextTab = nextTab() {
                                    selectedTab = nextTab
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                    }
                }
        )
        //.gestureMask(.subviews)
    }
}

extension Notification.Name {
    static let restoreListScrollToID = Notification.Name("RestoreListScrollToID")
    static let didLoadOlderPosts = Notification.Name("DidLoadOlderPosts")
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
