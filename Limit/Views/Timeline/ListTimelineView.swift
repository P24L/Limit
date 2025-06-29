//
//  ListTimelineView.swift
//  Limit
//
//  Created by Zdenek Indra on 24.06.2025.
//

import AppRouter
import ATProtoKit
import Foundation
import SwiftData
import SwiftUI

struct ListTimelineView: View {
    let list: AppBskyLexicon.Graph.ListViewDefinition
    @Environment(BlueskyClient.self) private var client
    // Pro budoucí rozšíření lze přidat bindingy jako u TimelinePostList
    // @Binding var newPostsAboveCount: Int
    // @Binding var hideDirectionIsUp: Bool
    // @Binding var isTopbarHidden: Bool

    @State private var posts: [TimelinePostWrapper] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var topVisibleID: String? = nil
    @State private var isRestoringScrollPosition: Bool = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Načítám příspěvky…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                Text("Chyba: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack {
                            Color.clear
                                .frame(height: 60)
                                .id("top")
                            ForEach(posts) { post in
                                PostItemWrappedView(post: post, depth: 0, nextPostID: nil, nextPostThreadRootID: nil)
                                    .id(post.uri)
                            }
                        }
                        .padding(.horizontal, 12)
                        .scrollTargetLayout()
                    }
                    .onScrollTargetVisibilityChange(idType: String.self) { visibleIDs in
                        guard !isRestoringScrollPosition else { return }
                        if let firstID = visibleIDs.first {
                            topVisibleID = firstID
                            TimelinePositionManager.shared.saveListPosition(firstID, for: list.uri)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .restoreListScrollToID)) { notification in
                        if let postID = notification.object as? String {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(postID, anchor: .top)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                isRestoringScrollPosition = false
                            }
                        }
                    }
                }
            }
        }
        .task {
            if posts.isEmpty { 
                await loadListFeed() 
                // Fallback timeout - pokud se za 2 sekundy nepodaří obnovit pozici, povol ukládání
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if isRestoringScrollPosition {
                        isRestoringScrollPosition = false
                    }
                }
            }
        }
    }

    private func loadListFeed() async {
        guard !isLoading else { return }
        isLoading = true
        defer { 
            isLoading = false
        }
        do {
            let output = try await client.protoClient?.getListFeed(from: list.uri, limit: 50)
            let wrappers = output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            await MainActor.run {
                self.posts = wrappers
                // Po načtení postů obnov pozici pokud existuje
                if let savedID = TimelinePositionManager.shared.getListPosition(for: list.uri) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .restoreListScrollToID, object: savedID)
                    }
                } else {
                    isRestoringScrollPosition = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
}