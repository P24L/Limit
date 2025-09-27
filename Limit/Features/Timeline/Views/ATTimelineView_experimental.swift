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
    @Environment(ThemeManager.self) private var themeManager

    enum ViewState {
        case loading
        case error(Error)
        case home
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
    @State private var lastTimelineRefresh: Date = Date().addingTimeInterval(-300) // Start with 5 minutes ago to ensure initial refresh
    @State private var isListsExpanded = false
    @State private var isFeedsExpanded = false
    @State private var newPostsAboveCount: Int = 0
    
    // Auto-refresh interval (4 minutes)
    private let autoRefreshInterval: TimeInterval = 240
    
    @State private var selectedTab: TopbarTab = .timeline
    @State private var isRefreshingAline = false
    @State private var isRefreshingTimeline = false
    @State private var showBookmarkConfirmation = false
    @State private var lastBookmarkId: String?
    @GestureState private var isVerticalTopBarDrag = false
    @State private var shouldRunDeferredTimelineRefresh = false
    @State private var homeTimelineViewModel: HomeTimelineViewModel?
    @StateObject private var listTimelineCache = ListTimelineViewModelCache()

    // Swipe gesture state (UI preview removed; no offset tracking needed)
    private var timelineIsLoading: Bool {
        guard selectedTab == .timeline else { return false }
        let isInitialLoadComplete = homeTimelineViewModel?.isInitialLoadComplete ?? false
        return isRefreshingTimeline || !isInitialLoadComplete
    }

    private var timelineBadgeText: String? {
        guard selectedTab == .timeline,
              !timelineIsLoading,
              newPostsAboveCount > 0 else {
            return nil
        }
        return "\(newPostsAboveCount.abbreviatedRounded)"
    }
    
    var body: some View {
        timelineContent
            .background(themeManager.colors.backgroundCanvas)
            .safeAreaBar(edge: .top) {
                topBar
            }
            .task {
                if homeTimelineViewModel == nil {
                    homeTimelineViewModel = HomeTimelineViewModel(feed: feed)
                }
                switch selectedTab {
                case .timeline:
                    homeTimelineViewModel?.loadFromStorage()
                    viewState = .home
                    
                    // Refresh only if needed (more than autoRefreshInterval since last refresh)
                    let timeSinceRefresh = Date().timeIntervalSince(lastTimelineRefresh)
                    DevLogger.shared.log("ATTimelineView - Time since last refresh: \(timeSinceRefresh)s")
                    
                    if timeSinceRefresh > autoRefreshInterval && !isRefreshingTimeline {
                        if homeTimelineViewModel?.isRestoringPosition == true {
                            DevLogger.shared.log("ATTimelineView - Deferring refresh until position restore completes")
                            shouldRunDeferredTimelineRefresh = true
                        } else {
                            Task {
                                await performTimelineRefresh(reason: "initial load")
                            }
                        }
                    } else {
                        DevLogger.shared.log("ATTimelineView - Skipping refresh (only \(timeSinceRefresh)s since last)")
                    }
                case .aline:
                    // For A-line, we'll show computed timeline posts
                    await computedFeed.loadPosts(client: client)
                    viewState = .posts(computedFeed.posts)
                case .list, .feed, .trendingPosts:
                    // These always load fresh data via ListTimelineView
                    viewState = getSelectedContent()
                }
            }
        .refreshable {
            switch selectedTab {
            case .timeline:
                guard homeTimelineViewModel?.isRestoringPosition != true else {
                    DevLogger.shared.log("ATTimelineView - Pull-to-refresh ignored, position restore in progress")
                    return
                }
                await performTimelineRefresh(reason: "pull-to-refresh")
            case .aline:
                // A-line uses its own refresh button
                break
            case .list, .feed, .trendingPosts:
                viewState = getSelectedContent()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Flush pending position changes when going to background
            if newPhase == .background {
                TimelinePositionManager.shared.flushPendingChanges()
                DevLogger.shared.log("ATTimelineView - Flushed position changes on background")
            }
            
            if selectedTab == .timeline && newPhase == .active {
                let timeSinceRefresh = Date().timeIntervalSince(lastTimelineRefresh)
                DevLogger.shared.log("ATTimelineView - Scene became active, time since last refresh: \(timeSinceRefresh)s")
                if timeSinceRefresh > autoRefreshInterval && !isRefreshingTimeline {
                    if homeTimelineViewModel?.isRestoringPosition == true {
                        DevLogger.shared.log("ATTimelineView - Deferring auto-refresh until restoration completes")
                        shouldRunDeferredTimelineRefresh = true
                    } else {
                        DevLogger.shared.log("ATTimelineView - Triggering auto-refresh on scene activation (>\(autoRefreshInterval)s)")
                        Task {
                            await performTimelineRefresh(reason: "scene activation")
                        }
                    }
                } else if isRefreshingTimeline {
                    DevLogger.shared.log("ATTimelineView - Skipping auto-refresh, already refreshing")
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
                    viewState = .home
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
            switch newValue {
            case .list:
                isListsExpanded = true
                isFeedsExpanded = false
            case .feed:
                isFeedsExpanded = true
                isListsExpanded = false
            default:
                isListsExpanded = false
                isFeedsExpanded = false
            }
            if newValue != .timeline {
                shouldRunDeferredTimelineRefresh = false
                homeTimelineViewModel?.prepareForTemporaryRemoval()
            }
        }
        .onChange(of: homeTimelineViewModel?.isRestoringPosition ?? false) { _, isRestoring in
            guard selectedTab == .timeline else { return }
            if !isRestoring,
               shouldRunDeferredTimelineRefresh,
               !isRefreshingTimeline {
                shouldRunDeferredTimelineRefresh = false
                Task {
                    await performTimelineRefresh(reason: "post-restore")
                }
            }
        }
        .onChange(of: currentUser.lists.count) { _, newValue in
            if newValue == 0 {
                isListsExpanded = false
            }
        }
        .onChange(of: currentUser.feeds.count) { _, newValue in
            if newValue == 0 {
                isFeedsExpanded = false
            }
        }
        .onChange(of: currentUser.did) { _, _ in
            listTimelineCache.removeAll()
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

    private func listTimelineViewModel(for source: TimelineContentSource) -> ListTimelineViewModel {
        switch source {
        case .list(let list):
            return currentUser.listViewModel(for: list, client: client)
        default:
            let accountDID = currentUser.did.isEmpty ? nil : currentUser.did
            return listTimelineCache.viewModel(for: source, client: client, accountDID: accountDID)
        }
    }

    @MainActor
    private func performTimelineRefresh(reason: String) async {
        guard !isRefreshingTimeline else {
            DevLogger.shared.log("ATTimelineView - Skipping \(reason) refresh, already in progress")
            return
        }

        DevLogger.shared.log("ATTimelineView - Starting \(reason) refresh")
        shouldRunDeferredTimelineRefresh = false
        isRefreshingTimeline = true
        if selectedTab == .timeline {
            let anchorID = homeTimelineViewModel?.currentAnchorPostID()
            await homeTimelineViewModel?.refreshTimeline()
            homeTimelineViewModel?.restoreToPostIfPossible(anchorID)
        } else {
            await feed.refreshTimeline()
        }
        lastTimelineRefresh = .now
        viewState = selectedTab == .timeline ? .home : .posts(feed.postTimeline)
        isRefreshingTimeline = false
        DevLogger.shared.log("ATTimelineView - Finished \(reason) refresh")
    }

    @ViewBuilder
    private var topBar: some View {
        VStack(spacing: 0) {
            mainTopBar

            if isListsExpanded, !currentUser.lists.isEmpty {
                Divider()
                    .overlay(themeManager.colors.border.opacity(0.2))
                listsSecondaryBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if isFeedsExpanded, !currentUser.feeds.isEmpty {
                Divider()
                    .overlay(themeManager.colors.border.opacity(0.2))
                    .transition(.opacity)
                feedsSecondaryBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            Rectangle()
                .fill(themeManager.colors.chromeBackground)
                .shadow(color: themeManager.colors.border.opacity(0.2), radius: 12, y: 6)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isListsExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFeedsExpanded)
    }

    private var mainTopBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                composeChip
                timelineChip
                alineChip
                trendingChip

                if !currentUser.lists.isEmpty {
                    listsToggleChip
                }

                if !currentUser.feeds.isEmpty {
                    feedsToggleChip
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
        .scrollDisabled(isVerticalTopBarDrag)
        .allowsHitTesting(!isVerticalTopBarDrag)
        .simultaneousGesture(
            DragGesture(minimumDistance: 2)
                .updating($isVerticalTopBarDrag) { value, state, _ in
                    let verticalMagnitude = abs(value.translation.height)
                    let horizontalMagnitude = abs(value.translation.width)
                    state = verticalMagnitude > horizontalMagnitude
                }
        )
    }

    private var composeChip: some View {
        Button {
            router.presentedSheet = .composePost()
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(themeManager.colors.accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.colors.accent.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private var timelineChip: some View {
        let isSelected = selectedTab == .timeline

        return chip(
            icon: TopbarTab.timeline.icon,
            title: TopbarTab.timeline.title,
            tint: themeManager.colors.accent,
            isSelected: isSelected,
            showTitleWhenUnselected: false,
            badge: timelineBadgeText,
            neutralColor: themeManager.colors.chromeForeground.opacity(0.75),
            trailing: {
                if timelineIsLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: isSelected ? Color.white : themeManager.colors.accent)
                        )
                        .scaleEffect(0.7)
                }
            }
        ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = .timeline
            }
        }
    }

    private var alineChip: some View {
        let isSelected = selectedTab == .aline
        return chip(
            icon: TopbarTab.aline.icon,
            title: "A-line",
            tint: TopbarTab.aline.color,
            isSelected: selectedTab == .aline,
            showTitleWhenUnselected: false,
            neutralColor: themeManager.colors.chromeForeground.opacity(0.75),
            trailing: {
                if isSelected {
                    if isRefreshingAline {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(Color.white)
                    }
                }
            }
        ) {
            if isSelected {
                guard !isRefreshingAline else { return }
                Task {
                    isRefreshingAline = true
                    await computedFeed.fastRefresh(client: client)
                    isRefreshingAline = false
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .aline
                }
            }
        }
    }

    private var trendingChip: some View {
        chip(
            icon: TopbarTab.trendingPosts.icon,
            title: TopbarTab.trendingPosts.title,
            tint: TopbarTab.trendingPosts.color,
            isSelected: selectedTab == .trendingPosts,
            showTitleWhenUnselected: false,
            neutralColor: themeManager.colors.chromeForeground.opacity(0.75)
        ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = .trendingPosts
            }
        }
    }

    private var listsToggleChip: some View {
        let isSelected: Bool
        if case .list = selectedTab {
            isSelected = true
        } else {
            isSelected = isListsExpanded
        }

        return chip(
            icon: TopbarTab.list(0).icon,
            title: nil,
            tint: TopbarTab.list(0).color,
            isSelected: isSelected,
            showTitleWhenUnselected: false,
            neutralColor: themeManager.colors.chromeForeground.opacity(0.75)
        ) {
            guard !currentUser.lists.isEmpty else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isListsExpanded {
                    isListsExpanded = false
                    if case .list = selectedTab {
                        selectedTab = .timeline
                    }
                } else {
                    isListsExpanded = true
                    isFeedsExpanded = false
                    if case .list = selectedTab {
                        // keep current selection
                    } else {
                        selectedTab = .list(0)
                    }
                }
            }
        }
    }

    private var feedsToggleChip: some View {
        let isSelected: Bool
        if case .feed = selectedTab {
            isSelected = true
        } else {
            isSelected = isFeedsExpanded
        }

        return chip(
            icon: TopbarTab.feed(0).icon,
            title: nil,
            tint: TopbarTab.feed(0).color,
            isSelected: isSelected,
            showTitleWhenUnselected: false,
            neutralColor: themeManager.colors.chromeForeground.opacity(0.75)
        ) {
            guard !currentUser.feeds.isEmpty else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isFeedsExpanded {
                    isFeedsExpanded = false
                    if case .feed = selectedTab {
                        selectedTab = .timeline
                    }
                } else {
                    isFeedsExpanded = true
                    isListsExpanded = false
                    if case .feed = selectedTab {
                        // keep current selection
                    } else {
                        selectedTab = .feed(0)
                    }
                }
            }
        }
    }

    private var listsSecondaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(currentUser.lists.enumerated()), id: \.offset) { index, list in
                    let tint = TopbarTab.list(index).color
                    secondaryChip(
                        title: truncatedTitle(list.name),
                        tint: tint,
                        isSelected: selectedTab == .list(index)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .list(index)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
    }

    private var feedsSecondaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(currentUser.feeds.enumerated()), id: \.offset) { index, feed in
                    let tint = TopbarTab.feed(index).color
                    secondaryChip(
                        title: truncatedTitle(feed.displayName),
                        tint: tint,
                        isSelected: selectedTab == .feed(index)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .feed(index)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
    }

    private func secondaryChip(title: String, tint: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? tint : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? tint.opacity(0.15) : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? tint : Color.gray.opacity(0.2), lineWidth: 1.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func chip(
        icon: String,
        title: String?,
        tint: Color,
        isSelected: Bool,
        showTitleWhenUnselected: Bool,
        badge: String? = nil,
        unselectedUsesTint: Bool = false,
        neutralColor: Color = .secondary,
        @ViewBuilder trailing: () -> some View = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 16 : 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : (unselectedUsesTint ? tint : neutralColor))
                    .symbolEffect(.bounce, value: isSelected)

                if let title, !title.isEmpty, showTitleWhenUnselected || isSelected {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : (unselectedUsesTint ? tint : neutralColor))
                        .lineLimit(1)
                }

                if let badge, isSelected {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                }

                trailing()
            }
            .padding(.horizontal, (showTitleWhenUnselected || isSelected) ? 16 : 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? tint : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : tint.opacity(unselectedUsesTint ? 0.4 : 0),
                        lineWidth: unselectedUsesTint && !isSelected ? 1.5 : 0
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func truncatedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 20 {
            return trimmed
        }
        let prefix = trimmed.prefix(20)
        return String(prefix)
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
                        guard selectedTab == .timeline else { return }
                        await performTimelineRefresh(reason: "error retry")
                    }
                }
            case .home:
                if let viewModel = homeTimelineViewModel {
                    if viewModel.isInitialLoadComplete {
                        TimelinePostList(
                            viewModel: viewModel,
                            newPostsAboveCount: $newPostsAboveCount
                        )
                    } else {
                        ProgressPostsRedacted()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ProgressPostsRedacted()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .posts(let wrappers):
                if selectedTab == .aline {
                    // A-line computed timeline
                    ComputedTimelineContainer(
                        posts: wrappers
                    )
                    .onReceive(NotificationCenter.default.publisher(for: .didLoadComputedPosts)) { _ in
                        Task {
                            viewState = .posts(computedFeed.posts)
                        }
                    }
                } else {
                    EmptyView()
                }
            case .content(let source):
                let viewModel = listTimelineViewModel(for: source)
                ListTimelineView(viewModel: viewModel)
            }
        }
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
