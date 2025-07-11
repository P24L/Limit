//
//  ComputedTimelineContainer.swift
//  Limit
//
//  Created by Zdenek Indra on 11.07.2025.
//

import ATProtoKit
import Foundation
import SwiftData
import SwiftUI

struct ComputedTimelineContainer: View {
    let posts: [TimelinePostWrapper]
    
    @Environment(BlueskyClient.self) private var client
    @Environment(ComputedTimelineFeed.self) private var computedFeed
    
    @Binding var isTopbarHidden: Bool
    
    @State private var viewState: ViewState = .posts([])
    
    enum ViewState {
        case posts([TimelinePostWrapper])
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    Color.clear
                        .frame(height: 100)
                        .id("top")
                    
                    ForEach(posts, id: \.id) { post in
                        PostItemWrappedView(post: post, isThreadView: true, postViewType: .timeline, showCard: true)
                            .id(post.id)
                    }
                    
                    // Infinity scroll trigger for A-line
                    if computedFeed.isPreparingNextBatch {
                        VStack {
                            ProgressView("Loading more posts...")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Color.clear
                            .frame(height: 20)
                            .onAppear {
                                Task {
                                    await computedFeed.loadMorePosts(client: client)
                                    viewState = .posts(computedFeed.posts)
                                }
                            }
                    }
                }
                .padding(.horizontal, 8)
                .background(.warmBackground)
            }
            .onScrollPhaseChange { old, new in
                if new == .tracking || new == .interacting {
                    isTopbarHidden = true
                } else if new == .idle {
                    isTopbarHidden = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didLoadComputedPosts)) { _ in
                Task {
                    viewState = .posts(computedFeed.posts)
                }
            }
        }
    }
}

extension Notification.Name {
    static let didLoadComputedPosts = Notification.Name("DidLoadComputedPosts")
}