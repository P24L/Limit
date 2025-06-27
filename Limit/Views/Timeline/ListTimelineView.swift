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
                                    .id(post.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .scrollTargetLayout()
                    }
                }
            }
        }
        .task {
            if posts.isEmpty { await loadListFeed() }
        }
    }

    private func loadListFeed() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let output = try await client.protoClient?.getListFeed(from: list.uri, limit: 50)
            let wrappers = output?.feed.compactMap { TimelinePostWrapper(from: $0.post) } ?? []
            await MainActor.run {
                self.posts = wrappers
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
}