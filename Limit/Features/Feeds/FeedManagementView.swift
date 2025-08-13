//
//  FeedManagementView.swift
//  Limit
//
//  Created by Claude Code on 15.07.2025.
//

import SwiftUI
import ATProtoKit

struct FeedManagementView: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var router
    
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if currentUser.feeds.isEmpty && !isLoading {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "text.append")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Feeds Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Subscribe to feeds to see custom content in your timeline")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Browse user profiles to discover and subscribe to feeds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Feeds content
                List {
                    ForEach(currentUser.feeds, id: \.feedURI) { feed in
                        FeedManagementItemView(
                            feed: feed,
                            isPinned: currentUser.feedPreferences[feed.feedURI]?.isPinned ?? false,
                            onPinToggle: {
                                Task {
                                    await togglePin(for: feed)
                                }
                            }
                        )
                    }
                    .onMove { source, destination in
                        // Handle reordering
                        Task {
                            await moveItems(from: source, to: destination)
                        }
                    }
                }
                .refreshable {
                    await refreshFeeds()
                }
            }
        }
        .navigationTitle("Feeds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
        }
        .task {
            await refreshFeeds()
        }
    }
    
    private func refreshFeeds() async {
        isLoading = true
        defer { isLoading = false }
        
        await currentUser.refreshFeeds(client: client)
        DevLogger.shared.log("FeedManagementView.swift - Refreshed feeds, count: \(currentUser.feeds.count)")
    }
    
    private func togglePin(for feed: AppBskyLexicon.Feed.GeneratorViewDefinition) async {
        isLoading = true
        defer { isLoading = false }
        
        let success = await currentUser.toggleFeedPin(feedURI: feed.feedURI, client: client)
        if !success {
            DevLogger.shared.log("FeedManagementView.swift - Failed to toggle pin for feed: \(feed.displayName)")
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) async {
        // Move items in the local array
        var feeds = currentUser.feeds
        feeds.move(fromOffsets: source, toOffset: destination)
        
        // Update the currentUser feeds immediately for responsive UI
        await MainActor.run {
            currentUser.feeds = feeds
        }
        
        // Update the server with new order
        isLoading = true
        defer { isLoading = false }
        
        let success = await currentUser.updateFeedOrder(client: client)
        if !success {
            DevLogger.shared.log("FeedManagementView.swift - Failed to update feed order on server")
            // Revert on failure
            await refreshFeeds()
        }
    }
}

struct FeedManagementItemView: View {
    let feed: AppBskyLexicon.Feed.GeneratorViewDefinition
    let isPinned: Bool
    let onPinToggle: () -> Void
    @Environment(AppRouter.self) private var router
    
    var body: some View {
        HStack(spacing: 12) {
            // Feed avatar or placeholder
            Group {
                if let avatarURL = feed.avatarImageURL {
                    AvatarView(url: avatarURL, size: 44)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "text.append")
                                .foregroundColor(.purple)
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(feed.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                if let description = feed.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("by \(feed.creator.displayName ?? feed.creator.actorHandle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let likeCount = feed.likeCount {
                        Text("\(likeCount) likes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Pin toggle button
            PinButton(isPinned: isPinned, action: onPinToggle)
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to feed timeline
            router.navigateTo(.feedTimeline(uri: feed.feedURI, displayName: feed.displayName))
        }
    }
}