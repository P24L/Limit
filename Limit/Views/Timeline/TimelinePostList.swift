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

struct TimelinePostList: View {
    let posts: [TimelinePostWrapper]

    @Environment(\.modelContext) private var context
    @Environment(BlueskyClient.self) private var client
    @Environment(TimelineFeed.self) private var feed
    
    @State private var topVisibleID: String? = nil
    @State private var isRestoringScrollPosition: Bool = true
    @State private var isScrolling: Bool = false

    @Binding var newPostsAboveCount: Int
    @Binding var hideDirectionIsUp: Bool
    @Binding var isTopbarHidden: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack {
                    Color.clear
                        .frame(height: 60) // Výška podle výšky topbaru
                    ForEach(posts) { wrapper in
                        postView(for: wrapper)
                    }
                    if client.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 16)
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
                .padding(.horizontal, 12)
                .scrollTargetLayout()
            }
            .onScrollPhaseChange { old, new in
                isScrolling = new != .idle
                if new == .tracking || new == .interacting {
                    // Hide or show topbar based on scroll direction preference and scroll phase
                    isTopbarHidden = true
                } else if new == .idle {
                    isTopbarHidden = false
                }
            }
            .onScrollTargetVisibilityChange(idType: String.self) { visibleIDs in
                guard !isRestoringScrollPosition else { return }
                if let firstID = visibleIDs.first {
                    topVisibleID = firstID
                    TimelinePositionManager.shared.saveTimelinePosition(firstID)
                    DevLogger.shared.log("ATTimelineView_experimental.swift - onScrollTargetVisibilityChange - saving position \(firstID)")
                    if let index = posts.firstIndex(where: { $0.uri == firstID }) {
                        newPostsAboveCount = index
                    } else {
                        newPostsAboveCount = 0
                    }
                }
            }
            .task {
                if isRestoringScrollPosition {
                    if let savedID = TimelinePositionManager.shared.getTimelinePosition() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation {
                                proxy.scrollTo(savedID, anchor: .top)
                                isRestoringScrollPosition = false
                            }
                        }
                    } else {
                        isRestoringScrollPosition = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .restoreScrollToID)) { notification in
                if let id = notification.object as? String {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }
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
            nextPostThreadRootID: nextWrapper?.rootPost?.uri
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