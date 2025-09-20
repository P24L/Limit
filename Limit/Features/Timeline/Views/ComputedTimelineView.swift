//
//  ComputedTimelineView.swift
//  Limit
//
//  Created by Zdenek Indra on 08.06.2025.
//

import SwiftData
import SwiftUI


struct ComputedTimelineView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\EnvironmentValues.modelContext) private var context
    @Environment(MultiAccountClient.self) private var client
    @Environment(ComputedTimelineFeed.self) private var feed
    
    @State private var isTopbarHidden = false
    @State private var hideDirectionIsUp = true
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                topbarView(proxy: proxy)
                
                Group {
                    if feed.isLoading && feed.posts.isEmpty {
                        ProgressView("Loading computed timeline...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = feed.error, feed.posts.isEmpty {
                        ErrorView(title: "Error", 
                                  message: error.localizedDescription,
                                  buttonTitle: "Try again") {
                            Task {
                                await feed.fastRefresh(client: client)
                            }
                        }
                    } else if feed.posts.isEmpty {
                        VStack {
                            Text("No posts available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Try refreshing to load content")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            // Top spacer for topbar
                            Color.clear
                                .frame(height: 60)
                                .id("top")
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())

                            ForEach(feed.posts, id: \.id) { post in
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

                            // Infinity scroll trigger and loading indicator
                            if feed.isPreparingNextBatch {
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
                                // Invisible trigger that loads more when it appears
                                Color.clear
                                    .frame(height: 20)
                                    .onAppear {
                                        Task {
                                            await feed.loadMorePosts(client: client)
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
                        .animation(.smooth, value: isTopbarHidden)
                        .onScrollPhaseChange { old, new in
                            isTopbarHidden = (new == .tracking || new == .interacting)
                        }
                    }
                }
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .task {
            await feed.loadPosts(client: client)
        }
        .refreshable {
            await feed.fastRefresh(client: client)
        }
    }

    private var safeAreaTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.top }
            .first ?? 0
    }

    @ViewBuilder
    private func topbarView(proxy: ScrollViewProxy) -> some View {
        let safeAreaTopInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.top }
            .first ?? 0
        let totalOffset = 44 + safeAreaTopInset
        ZStack {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 24, height: 24)
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await feed.fastRefresh(client: client)
                            withAnimation {
                                proxy.scrollTo("top", anchor: .top)
                            }
                        }
                    } label: {
                        if feed.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .buttonStyle(.plain)
                                .symbolEffect(.bounce, value: feed.isLoading)
                                .foregroundStyle(.mintAccent)
                                .font(.callout)
                        }
                    }
                    .disabled(feed.isLoading)
                }
            }

            // Logo vystředěné
            Image("Logo")
                .resizable()
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal)
        .frame(height: 44)
        .background(Color(.secondarySystemBackground))
        .offset(y: isTopbarHidden ? (hideDirectionIsUp ? -totalOffset : totalOffset) : safeAreaTopInset)
        .animation(.easeInOut(duration: 0.25), value: isTopbarHidden)
        .zIndex(1)
    }

}
