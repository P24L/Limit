//
//  ListTimelineView.swift
//  Limit
//
//  Created by Zdenek Indra on 24.06.2025.
//

import ATProtoKit
import SwiftUI

struct ListTimelineView: View {
    @Bindable var viewModel: ListTimelineViewModel

    @Environment(\.scenePhase) private var scenePhase

    @State private var isProgrammaticScroll = false
    @State private var hasUserInteracted = false

    var body: some View {
        ScrollViewReader { proxy in
        List {
            if viewModel.isLoading && !viewModel.isInitialLoadComplete {
                ProgressPostsRedacted()
                    .frame(maxWidth: .infinity, minHeight: 400)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            } else if let error = viewModel.error, viewModel.posts.isEmpty {
                Text("Chyba: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, minHeight: 400)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            } else {
                ForEach(viewModel.posts) { post in
                    PostItemWrappedView(
                        post: post,
                        useListStyle: true
                    )
                    .id(post.uri)
                    .listRowInsets(EdgeInsets(
                        top: 4,
                        leading: 12,
                        bottom: 4,
                        trailing: 12
                    ))
                    .listRowBackground(Color.warmBackground)
                    .listRowSeparator(.visible, edges: .bottom)
                    .onAppear {
                        if viewModel.isRestoringPosition,
                           viewModel.pendingRestoreID == post.uri {
                            DevLogger.shared.log("ListTimelineView - ✅ Restore target appeared: \(post.uri)")
                            viewModel.completePositionRestore(for: post.uri)
                            isProgrammaticScroll = false
                        } else {
                            viewModel.postDidAppear(id: post.uri)
                        }
                    }
                    .onDisappear {
                        viewModel.postDidDisappear(id: post.uri)
                    }
                }

                if viewModel.posts.isEmpty {
                    Text("No posts available")
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.warmBackground)
        .contentMargins(.top, 12)
        .onScrollPhaseChange { _, phase in
            switch phase {
            case .tracking, .interacting:
                hasUserInteracted = true
                viewModel.userDidInteract()
            case .idle:
                break
            case nil:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: viewModel.scrollTargetID) { _, newValue in
            guard let target = newValue else { return }
            DevLogger.shared.log("ListTimelineView - Restoring scroll position to: \(target)")
            isProgrammaticScroll = true
            proxy.scrollTo(target, anchor: .top)
            viewModel.clearScrollTarget()
        }
        .onChange(of: viewModel.posts) { _, newPosts in
            DevLogger.shared.log("ListTimelineView - posts updated, count=\(newPosts.count) for \(viewModel.sourceIdentifier)")
            viewModel.retryRestoreIfNeeded()
        }
        .task(id: viewModel.sourceIdentifier) {
            await viewModel.loadInitial()
        }
        .refreshable {
            viewModel.beginRefresh()
            await viewModel.refresh()
            viewModel.endRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                TimelinePositionManager.shared.flushPendingChanges()
                DevLogger.shared.log("ListTimelineView - Flushed position changes on background")
            }
        }
        .onAppear {
            if let target = viewModel.targetForInitialDisplay() {
                DevLogger.shared.log("ListTimelineView - Attempting initial scroll restore to: \(target)")
                isProgrammaticScroll = true
                proxy.scrollTo(target, anchor: .top)
            }
            hasUserInteracted = false
            viewModel.resetInteractionState(with: viewModel.currentScrollPosition)
        }
        .onDisappear {
            viewModel.prepareForTemporaryRemoval()
            hasUserInteracted = false
        }
        }
    }
}
