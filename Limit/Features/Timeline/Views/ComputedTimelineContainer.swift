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
    
    @Environment(MultiAccountClient.self) private var client
    @Environment(ComputedTimelineFeed.self) private var computedFeed
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(posts, id: \.id) { post in
                    PostItemWrappedView(
                        post: post,
                        isThreadView: true,
                        postViewType: .timeline,
                        useListStyle: true  // Use List style
                    )
                    .id(post.id)
                    .listRowInsets(EdgeInsets(
                        top: 4,
                        leading: 8,
                        bottom: 4,
                        trailing: 8
                    ))
                    .listRowBackground(Color.warmBackground)
                    .listRowSeparator(.visible, edges: .bottom)
                }

                // Infinity scroll trigger for A-line
                if computedFeed.isPreparingNextBatch {
                    VStack {
                        ProgressView("Loading more posts...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                } else {
                    Color.clear
                        .frame(height: 20)
                        .onAppear {
                            Task {
                                await computedFeed.loadMorePosts(client: client)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.warmBackground)
            .contentMargins(.top, 12)
        }
    }
}

extension Notification.Name {
    static let didLoadComputedPosts = Notification.Name("DidLoadComputedPosts")
}
