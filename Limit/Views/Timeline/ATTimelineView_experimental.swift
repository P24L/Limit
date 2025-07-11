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

@MainActor
struct ATTimelineView_experimental: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(\.modelContext) var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TimelineFeed.self) private var feed
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var router
    @Environment(ComputedTimelineFeed.self) private var computedFeed

    enum ViewState {
        case loading
        case error(Error)
        case posts([TimelinePostWrapper])
        case content(TimelineContentSource)
    }
    
    enum TopbarTab: Equatable {
        case timeline
        case aline
        case list(Int)
        case feed(Int)
        
        var color: Color {
            switch self {
            case .timeline:
                return .mintAccent
            case .aline:
                return .blue
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
            case .list:
                return "list.bullet"
            case .feed:
                return "square.stack.3d.up"
            }
        }
        
        var title: String {
            switch self {
            case .timeline:
                return "Timeline"
            case .aline:
                return "A-line"
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
                if feed.posts.isEmpty {
                    feed.loadFromStorage()
                }
                await feed.refreshTimeline()
                viewState = .posts(feed.postTimeline)
            case .aline:
                // For A-line, we'll show computed timeline posts
                await computedFeed.loadPosts(client: client)
                viewState = .posts(computedFeed.posts)
            case .list, .feed:
                viewState = getSelectedContent()
            }
        }
        .refreshable {
            switch selectedTab {
            case .timeline:
                let savedTopID = TimelinePositionManager.shared.getTimelinePosition()
                await feed.refreshTimeline()
                viewState = .posts(feed.postTimeline)
                if let id = savedTopID {
                    NotificationCenter.default.post(name: .restoreScrollToID, object: id)
                }
            case .aline:
                // A-line uses its own refresh button
                break
            case .list, .feed:
                viewState = getSelectedContent()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if selectedTab == .timeline && newPhase == .active && Date().timeIntervalSince(lastRefresh) > 60 {
                Task {
                    let savedTopID = TimelinePositionManager.shared.getTimelinePosition()
                    await feed.refreshTimeline()
                    lastRefresh = .now
                    viewState = .posts(feed.postTimeline)
                    if let id = savedTopID {
                        NotificationCenter.default.post(name: .restoreScrollToID, object: id)
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
                case .list, .feed:
                    viewState = getSelectedContent()
                }
            }
        }
    }
    
    // MARK: Helper Functions
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
        HStack(spacing: 8) {
            // Timeline tab
            TabButton(
                tab: .timeline,
                isSelected: selectedTab == .timeline,
                showText: selectedTab == .timeline,
                badge: selectedTab == .timeline && newPostsAboveCount > 0 ? "\(newPostsAboveCount)" : nil,
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
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
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
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in }
        )
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
}

extension Notification.Name {
    static let restoreScrollToID = Notification.Name("RestoreScrollToID")
    static let restoreListScrollToID = Notification.Name("RestoreListScrollToID")
    static let didLoadOlderPosts = Notification.Name("DidLoadOlderPosts")
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


