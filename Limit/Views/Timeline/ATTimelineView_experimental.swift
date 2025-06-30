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

    enum ViewState {
        case loading
        case error(Error)
        case posts([TimelinePostWrapper])
        case content(TimelineContentSource)
    }

    @State private var viewState: ViewState = .loading
    @State private var lastRefresh: Date = Date().addingTimeInterval(-60)
    @State private var hideDirectionIsUp: Bool = true
    @State private var isTopbarHidden = false
    @State private var isExpandedTopbar = false
    @State private var newPostsAboveCount: Int = 0
    
    @State private var selectedIndex: Int = 0 // 0 = Timeline, 1... = listy

    var body: some View {
        VStack(spacing: 0) {           
            topbarView
            timelineContent
        }
        .ignoresSafeArea(.container, edges: .top)
        .task {
            if selectedIndex == 0 {
                if feed.posts.isEmpty {
                    feed.loadFromStorage()
                }
                await feed.refreshTimeline()
                viewState = .posts(feed.postTimeline)
            } else {
                viewState = getSelectedContent()
            }
        }
        .refreshable {
            if selectedIndex == 0 {
                let savedTopID = TimelinePositionManager.shared.getTimelinePosition()
                await feed.refreshTimeline()
                viewState = .posts(feed.postTimeline)
                if let id = savedTopID {
                    NotificationCenter.default.post(name: .restoreScrollToID, object: id)
                }
            } else {
                viewState = getSelectedContent()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if selectedIndex == 0 && newPhase == .active && Date().timeIntervalSince(lastRefresh) > 60 {
                Task {
                    let savedTopID = TimelinePositionManager.shared.getTimelinePosition()
                    await feed.refreshTimeline()
                    lastRefresh = .now
                    viewState = .posts(feed.postTimeline)
                    if let id = savedTopID {
                        NotificationCenter.default.post(name: .restoreScrollToID, object: id)
                    }
                }
            } else if selectedIndex > 0 && newPhase == .active {
                viewState = getSelectedContent()
            }
        }
        .onChange(of: selectedIndex) { _, newValue in
            if newValue == 0 {
                viewState = .posts(feed.postTimeline)
            } else {
                viewState = getSelectedContent()
            }
        }
    }
    
    // MARK: Helper Functions
    private func getSelectedContent() -> ViewState {
        guard selectedIndex > 0 else { return .loading }
        
        if selectedIndex <= currentUser.lists.count {
            // Lists (index 1...lists.count)
            guard let list = currentUser.lists[safe: selectedIndex - 1] else {
                return .loading
            }
            return .content(.list(list))
        } else {
            // Feeds (index lists.count+1...lists.count+feeds.count)
            let feedIndex = selectedIndex - currentUser.lists.count - 1
            guard let feed = currentUser.feeds[safe: feedIndex] else {
                return .loading
            }
            return .content(.feed(feed))
        }
    }
    
    // MARK: Topbar View
    @ViewBuilder
    private var topbarView: some View {
        let safeAreaTopInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.top }
            .first ?? 0
        let totalOffset = 44 + safeAreaTopInset

        ZStack {
            HStack {
                AvatarView(url: currentUser.avatarURL, size: 32)
                    .onTapGesture {
                        if !currentUser.did.isEmpty {
                            router.navigateTo(.actor(userID: currentUser.did))
                        }
                    }
                Spacer()
                HStack(spacing: 8) {
                    if newPostsAboveCount > 0 {
                        Text("\(newPostsAboveCount)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(.mintAccent)
                            )
                            .transition(.scale)
                    }

                    Button {
                        Task {
                            if selectedIndex == 0 {
                                let savedTopID = TimelinePositionManager.shared.getTimelinePosition()
                                await feed.refreshTimeline()
                                viewState = .posts(feed.postTimeline)
                                if let id = savedTopID {
                                    NotificationCenter.default.post(name: .restoreScrollToID, object: id)
                                }
                            } else {
                                viewState = getSelectedContent()
                            }
                        }
                    } label: {
                        if client.isLoading {
                            ProgressView()
                                .progressViewStyle(
                                    CircularProgressViewStyle()
                                )
                                .foregroundStyle(.mintAccent)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .buttonStyle(.plain)
                                .symbolEffect(.bounce, value: client.isLoading)
                                .foregroundStyle(.mintAccent)
                                .font(.callout)
                        }
                    }
                    .disabled(client.isLoading)
                }
            }

            // Dropdown Picker na střed
            Picker("", selection: $selectedIndex) {
                Text("Timeline").tag(0)
                // Lists
                ForEach(Array(currentUser.lists.enumerated()), id: \.offset) { idx, list in
                    Text(list.name).tag(idx + 1)
                }
                
                // Feeds
                ForEach(Array(currentUser.feeds.enumerated()), id: \.offset) { idx, feed in
                    Text(feed.displayName).tag(currentUser.lists.count + idx + 1)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)
        }
        .padding(.horizontal)
        .frame(height: 44)
        .background(Color(.secondarySystemBackground))
        .offset(y: isTopbarHidden ? (hideDirectionIsUp ? -totalOffset : totalOffset) : safeAreaTopInset)
        .animation(.easeInOut(duration: 0.25), value: isTopbarHidden)
        .zIndex(1)
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
            .task {
                client.prepareHotPostCacheInBackground()
            }
        case .content(let source):
            ListTimelineView(source: source)
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


