//
//  HomeTimelineViewModel.swift
//  Limit
//
//  Created by Zdenek Indra on 11.07.2025.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeTimelineViewModel {
    @ObservationIgnored
    private let feed: TimelineFeed

    private(set) var posts: [TimelinePostWrapper] = []
    private(set) var isRestoringPosition: Bool = false
    private(set) var pendingRestoreID: String?
    private(set) var scrollTargetID: String?
    private(set) var currentScrollPosition: String?
    private(set) var hasMoreOlderPosts: Bool = false
    private(set) var isInitialLoadComplete: Bool = false
    private(set) var isLoading: Bool = false

    @ObservationIgnored
    private var needsScrollToCurrentOnReappear = false
    @ObservationIgnored
    private var visibleTracker = VisiblePostTracker()
    @ObservationIgnored
    private var hasUserInteracted = false
    @ObservationIgnored
    private var postIndexMap: [String: Int] = [:]
    @ObservationIgnored
    private var isPerformingRefresh = false

    init(feed: TimelineFeed) {
        self.feed = feed
        observeFeed()
    }

    // MARK: - Observation
    private func observeFeed() {
        withObservationTracking { [weak self] in
            guard let self else { return }
            syncFromFeed()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeFeed()
            }
        }
    }

    private func syncFromFeed() {
        posts = feed.postTimeline
        rebuildPostIndexMap()
        isRestoringPosition = feed.isRestoringPosition
        pendingRestoreID = feed.pendingRestoreID
        scrollTargetID = feed.scrollToId
        currentScrollPosition = feed.currentScrollPosition
        hasMoreOlderPosts = feed.hasMorePostsAvailable
        if !posts.isEmpty {
            isInitialLoadComplete = true
            isLoading = false
        }
    }

    // MARK: - Loading & Refresh
    func loadFromStorage(force: Bool = false) {
        isLoading = true
        feed.loadFromStorage(force: force)
        syncFromFeed()
        if !isInitialLoadComplete {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000)
                syncFromFeed()
            }
        }
    }

    func refreshTimeline() async {
        isLoading = true
        await feed.refreshTimeline()
        syncFromFeed()
        isLoading = false
    }

    func loadOlderTimeline() async {
        await feed.loadOlderTimeline()
        NotificationCenter.default.post(name: .didLoadOlderPosts, object: nil)
        syncFromFeed()
        isLoading = false
    }

    // MARK: - Scroll coordination
    func prepareForTemporaryRemoval() {
        needsScrollToCurrentOnReappear = true
    }

    func targetForInitialDisplay() -> String? {
        if let explicitTarget = scrollTargetID {
            feed.scrollToId = nil
            syncFromFeed()
            needsScrollToCurrentOnReappear = false
            return explicitTarget
        }

        if isRestoringPosition, let pendingRestoreID {
            needsScrollToCurrentOnReappear = false
            return pendingRestoreID
        }

        if needsScrollToCurrentOnReappear, let currentScrollPosition {
            needsScrollToCurrentOnReappear = false
            return currentScrollPosition
        }

        return nil
    }

    func clearScrollTarget() {
        feed.scrollToId = nil
        syncFromFeed()
        needsScrollToCurrentOnReappear = false
    }

    func queueSave(for postID: String) {
        feed.currentScrollPosition = postID
        TimelinePositionManager.shared.scheduleDebouncedTimelineSave(postID, accountDID: feed.accountDID)
        syncFromFeed()
    }

    func retryRestoreIfNeeded() {
        feed.retryRestoreIfNeeded()
    }

    func completePositionRestore(for id: String) {
        feed.completePositionRestore(for: id)
        syncFromFeed()
    }

    func postDidAppear(id: String) {
        visibleTracker.add(id)
        saveTopIfNeeded()
    }

    func postDidDisappear(id: String) {
        visibleTracker.remove(id)
        saveTopIfNeeded()
    }

    func userDidInteract() {
        hasUserInteracted = true
    }

    func resetInteractionState(with initialID: String?) {
        hasUserInteracted = false
        visibleTracker.reset(with: initialID)
    }

    func currentAnchorPostID() -> String? {
        if isPerformingRefresh, let currentScrollPosition {
            return currentScrollPosition
        }

        if let topVisible = visibleTracker.topVisibleID(using: postIndexMap) {
            return topVisible
        }

        if let currentScrollPosition {
            return currentScrollPosition
        }

        return posts.first?.uri
    }

    func restoreToPostIfPossible(_ id: String?) {
        guard let id,
              posts.contains(where: { $0.uri == id }) else { return }

        feed.currentScrollPosition = id
        TimelinePositionManager.shared.scheduleDebouncedTimelineSave(id, accountDID: feed.accountDID)
        feed.reapplyCurrentScrollPosition()
        syncFromFeed()
        visibleTracker.reset(with: id)
        hasUserInteracted = false
    }

    func beginRefresh() {
        isPerformingRefresh = true
    }

    func endRefresh() {
        isPerformingRefresh = false
    }

    private func saveTopIfNeeded() {
        guard hasUserInteracted,
              !isPerformingRefresh,
              let topID = visibleTracker.topVisibleID(using: postIndexMap),
              topID != currentScrollPosition else { return }

        feed.currentScrollPosition = topID
        TimelinePositionManager.shared.scheduleDebouncedTimelineSave(topID, accountDID: feed.accountDID)
        syncFromFeed()
    }

    private func rebuildPostIndexMap() {
        postIndexMap = [:]
        postIndexMap.reserveCapacity(posts.count)
        for (index, post) in posts.enumerated() {
            postIndexMap[post.uri] = index
        }
    }
}
