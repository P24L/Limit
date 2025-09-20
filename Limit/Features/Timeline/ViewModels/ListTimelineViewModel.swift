//
//  ListTimelineViewModel.swift
//  Limit
//
//  Created by Zdenek Indra on 11.07.2025.
//

import Foundation
import Observation
import ATProtoKit
import SwiftUI

@MainActor
@Observable
final class ListTimelineViewModel {
    private var client: MultiAccountClient
    private(set) var source: TimelineContentSource
    private let accountDID: String?

    private(set) var posts: [TimelinePostWrapper] = []
    private(set) var isLoading: Bool = false
    private(set) var isInitialLoadComplete: Bool = false
    private(set) var error: Error?

    private(set) var isRestoringPosition: Bool = false
    private(set) var pendingRestoreID: String?
    private(set) var scrollTargetID: String?
    private(set) var currentScrollPosition: String?

    private var needsScrollToCurrentOnReappear = false
    private var visibleTracker = VisiblePostTracker()
    private var hasUserInteracted = false

    init(source: TimelineContentSource, client: MultiAccountClient, accountDID: String?) {
        self.source = source
        self.client = client
        self.accountDID = accountDID
        DevLogger.shared.log("ListTimelineViewModel - init for \(sourceIdentifier)")
    }

    var sourceIdentifier: String {
        source.identifier
    }

    func updateClient(_ newClient: MultiAccountClient) {
        client = newClient
    }

    func updateSource(_ newSource: TimelineContentSource) {
        source = newSource
    }

    func loadInitial(force: Bool = false) async {
        if isLoading && !force { return }
        if isInitialLoadComplete, !force, !posts.isEmpty { return }
        isLoading = true
        error = nil
        needsScrollToCurrentOnReappear = false
        hasUserInteracted = false
        DevLogger.shared.log("ListTimelineViewModel - loadInitial start, force=\(force), source=\(sourceIdentifier)")
        let data = await fetchAllData()
        DevLogger.shared.log("ListTimelineViewModel - loadInitial fetched \(data.count) posts for \(sourceIdentifier)")
        posts = data
        isInitialLoadComplete = true
        pendingRestoreID = nil
        isRestoringPosition = false
        determineInitialScrollTarget(with: data)
        isLoading = false
        DevLogger.shared.log("ListTimelineViewModel - loadInitial completed, posts=\(posts.count), scrollTarget=\(scrollTargetID ?? "nil")")
    }

    func refresh() async {
        DevLogger.shared.log("ListTimelineViewModel - refresh called for \(sourceIdentifier)")
        await loadInitial(force: true)
    }

    func prepareForTemporaryRemoval() {
        needsScrollToCurrentOnReappear = true
        DevLogger.shared.log("ListTimelineViewModel - prepareForTemporaryRemoval for \(sourceIdentifier)")
    }

    func targetForInitialDisplay() -> String? {
        if let target = scrollTargetID {
            scrollTargetID = nil
            needsScrollToCurrentOnReappear = false
            return target
        }

        if isRestoringPosition, let pendingRestoreID {
            return pendingRestoreID
        }

        if needsScrollToCurrentOnReappear, let currentScrollPosition {
            needsScrollToCurrentOnReappear = false
            return currentScrollPosition
        }

        return nil
    }

    func clearScrollTarget() {
        scrollTargetID = nil
        needsScrollToCurrentOnReappear = false
        DevLogger.shared.log("ListTimelineViewModel - clearScrollTarget for \(sourceIdentifier)")
    }

    func queueSave(for postID: String) {
        currentScrollPosition = postID
        if case .list = source {
            TimelinePositionManager.shared.saveListPosition(postID, for: source.uri, accountDID: accountDID)
        } else {
            TimelinePositionManager.shared.scheduleDebouncedTimelineSave(postID, accountDID: accountDID)
        }
        DevLogger.shared.log("ListTimelineViewModel - queueSave \(postID) for \(sourceIdentifier)")
    }

    func retryRestoreIfNeeded() {
        guard isRestoringPosition, let pendingRestoreID else { return }
        if posts.contains(where: { $0.uri == pendingRestoreID }) {
            scrollTargetID = pendingRestoreID
        }
    }

    func completePositionRestore(for id: String) {
        guard pendingRestoreID == id else { return }
        isRestoringPosition = false
        pendingRestoreID = nil
        currentScrollPosition = id
        needsScrollToCurrentOnReappear = false
        DevLogger.shared.log("ListTimelineViewModel - completePositionRestore for \(id) in \(sourceIdentifier)")
    }

    private func determineInitialScrollTarget(with data: [TimelinePostWrapper]) {
        let candidate: String?

        if case .list = source,
           let savedID = TimelinePositionManager.shared.getListPosition(for: source.uri, accountDID: accountDID),
           data.contains(where: { $0.uri == savedID }) {
            pendingRestoreID = savedID
            isRestoringPosition = true
            currentScrollPosition = savedID
            candidate = savedID
            DevLogger.shared.log("ListTimelineViewModel - restoring saved ID \(savedID) for \(sourceIdentifier)")
        } else if let currentScrollPosition,
                  data.contains(where: { $0.uri == currentScrollPosition }) {
            candidate = currentScrollPosition
        } else {
            candidate = data.first?.uri
        }

        if let candidate {
            scrollTargetID = candidate
            currentScrollPosition = candidate
            DevLogger.shared.log("ListTimelineViewModel - initial scroll target set to \(candidate) for \(sourceIdentifier)")
        } else {
            scrollTargetID = nil
            DevLogger.shared.log("ListTimelineViewModel - no scroll target available for \(sourceIdentifier)")
        }
        visibleTracker.reset(with: scrollTargetID)
    }

    private func fetchAllData() async -> [TimelinePostWrapper] {
        DevLogger.shared.log("ListTimelineViewModel - fetching data for \(sourceIdentifier)")
        switch source {
        case .list(let list):
            let output = await client.getListFeed(listURI: list.uri, limit: 50)
            let values = output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            DevLogger.shared.log("ListTimelineViewModel - fetched list feed count=\(values.count) for \(sourceIdentifier)")
            return values
        case .feed(let feed):
            let output = await client.getCustomFeed(feedURI: feed.feedURI, limit: 50)
            let values = output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            DevLogger.shared.log("ListTimelineViewModel - fetched custom feed count=\(values.count) for \(sourceIdentifier)")
            return values
        case .feedUri(let uri, _):
            let output = await client.getCustomFeed(feedURI: uri, limit: 50)
            let values = output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            DevLogger.shared.log("ListTimelineViewModel - fetched feedUri count=\(values.count) for \(sourceIdentifier)")
            return values
        case .trendingFeed(let link, _):
            let result = await client.viewTrendingFeed(link: link, limit: 50)
            let values = result?.posts.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            DevLogger.shared.log("ListTimelineViewModel - fetched trending feed count=\(values.count) for \(sourceIdentifier)")
            return values
        case .trendingPosts:
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -2, to: Date())
            let output = await client.searchPosts(
                matching: "*",
                sortRanking: .top,
                sinceDate: weekAgo,
                untilDate: Date(),
                limit: 50
            )
            let values = output?.posts.compactMap { TimelinePostWrapper(from: $0) } ?? []
            DevLogger.shared.log("ListTimelineViewModel - fetched trending posts count=\(values.count) for \(sourceIdentifier)")
            return values
        }
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

    private func saveTopIfNeeded() {
        guard hasUserInteracted,
              let topID = visibleTracker.topVisibleID,
              topID != currentScrollPosition else { return }

        currentScrollPosition = topID
        switch source {
        case .list(let list):
            TimelinePositionManager.shared.saveListPosition(topID, for: list.uri, accountDID: accountDID)
        default:
            TimelinePositionManager.shared.scheduleDebouncedTimelineSave(topID, accountDID: accountDID)
        }
    }
}
