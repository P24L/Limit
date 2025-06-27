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
    @Environment(BlueskyClient.self) private var client
    
    @State private var posts: [TimelinePostWrapper]? = nil
    @State private var isTopbarHidden = false
    @State private var hideDirectionIsUp = true
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                topbarView(proxy: proxy)
                ScrollView {
                    LazyVStack {
                        if let posts {
                            Color.clear
                                    .frame(height: 60)
                                    .id("top")
                            ForEach(posts, id: \.id) { post in
                                PostItemWrappedView(post: post, isThreadView: true, postViewType: .timeline)
                                    .id(post.id)
                            }
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(.top,0) //isTopbarHidden ? 0 : 44 + safeAreaTopInset)
                    .animation(.smooth, value: isTopbarHidden)
                    .padding(.horizontal, 12)
                    .scrollTargetLayout()
                }
                .onScrollPhaseChange { old, new in
                    isTopbarHidden = (new == .tracking || new == .interacting)
                }
                .task {
                    await client.login()
                    DevLogger.shared.log("ComputedTimelineView.swift - task part 1 - starting getCachedOrRefreshHotPostIDs")
                    let rawPosts = await client.getCachedOrRefreshHotPosts()
                    DevLogger.shared.log("ComputedTimelineView.swift - task part 2 - completed getCachedOrRefreshHotPostIDs")
                    if rawPosts.count > 0 {
                        posts = rawPosts
                    }
                }
            }
            .ignoresSafeArea(.container, edges: .top)
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
                            await loadFreshPosts(proxy: proxy)
                            withAnimation {
                                proxy.scrollTo("top", anchor: .top)
                            }
                        }
                    } label: {
                        if client.isRefreshingHotPosts {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .buttonStyle(.plain)
                                .symbolEffect(.bounce, value: client.isLoading)
                                .foregroundStyle(.mintAccent)
                                .font(.callout)
                        }
                    }
                    .disabled(client.isRefreshingHotPosts)
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

    private func loadFreshPosts(proxy: ScrollViewProxy) async {
        DevLogger.shared.log("ComputedTimelineView.swift - topbar - starting getCachedOrRefreshHotPostIDs")
        
        let rawPosts = await client.getCachedOrRefreshHotPosts()

        if rawPosts.count > 0 {
            posts = rawPosts
            withAnimation {
                proxy.scrollTo("top", anchor: .top)
            }
        }
    }
}
