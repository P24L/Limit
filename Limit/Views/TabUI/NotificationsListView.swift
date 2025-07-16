//
//  NotificationsListView.swift
//  Limit
//
//  Created by assistant on 2025-07-15.
//

import SwiftUI
import ATProtoKit

struct NotificationsListView: View {
    @Environment(NotificationManager.self) var notificationManager
    @Environment(BlueskyClient.self) private var client
    @State private var isLoading = false
    @State private var hasLoadedInitial = false
    
    var body: some View {
        Group {
            if notificationManager.allNotifications.isEmpty && !isLoading {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No notifications")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("When someone interacts with your posts, you'll see it here")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.warmBackground)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(notificationManager.allNotifications) { notification in
                            NotificationRowView(notification: notification)
                                .padding(.horizontal, 10)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading notifications...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color.warmBackground)
                .refreshable {
                    await loadNotifications()
                }
            }
        }
        .task {
            if !hasLoadedInitial {
                hasLoadedInitial = true
                await loadNotifications()
            }
        }
    }
    
    private func loadNotifications() async {
        guard !isLoading else { return }
        
        isLoading = true
        await notificationManager.loadNotifications()
        
        // Mark all as read after displaying
        //await notificationManager.markAllAsRead()
        
        isLoading = false
    }
}

struct NotificationRowView: View {
    let notification: NotificationWrapper
    @Environment(AppRouter.self) private var router
    
    var body: some View {
        notificationContent
    }
    
    @ViewBuilder
    private var notificationContent: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarSection
            contentSection
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.isRead ? Color.clear : Color.mintAccent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(url: notification.author.avatarImageURL, size: 48)
                .onTapGesture {
                    router.navigateTo(.actor(userID: notification.author.actorDID))
                }
            
            // Action icon badge
            Circle()
                .fill(Color.warmBackground)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: notification.actionIcon)
                        .font(.caption2)
                        .foregroundColor(iconColor)
                )
                .offset(x: 4, y: 4)
        }
    }
    
    @ViewBuilder
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            detailContent
        }
    }
    
    @ViewBuilder
    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(notification.author.displayName ?? notification.author.actorHandle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .onTapGesture {
                        router.navigateTo(.actor(userID: notification.author.actorDID))
                    }
                
                Spacer()
                
                Text(notification.timeAgoText)
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
            }
            
            Text(notification.displayText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch notification.reason {
                case .like, .repost:
                    // Show the original post that was liked/reposted
                    if let post = notification.linkedPost {
                        VStack(alignment: .leading, spacing: 4) {
                            /*HStack {
                                Text(likeRepostLabel)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                                Spacer()
                            }*/
                            Text(post.text)
                                .font(.caption)
                                .lineLimit(3)
                                .foregroundColor(.primary)
                            
                            if !post.embeds.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo")
                                        .font(.caption2)
                                    Text("\(post.embeds.count) image\(post.embeds.count > 1 ? "s" : "")")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(notificationBackgroundColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            router.navigateTo(.postThreadWrapped(postThread: post))
                        }
                    } else {
                        // Loading state for like/repost
                        Text("Loading post...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                case .reply, .mention, .quote:
                    // Show the reply/mention/quote text directly from PostRecord
                    if let postText = notification.postText {
                        VStack(alignment: .leading, spacing: 4) {
                            /*HStack {
                                Text(replyMentionQuoteLabel)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                                Spacer()
                            }*/
                            Text(postText)
                                .font(.caption)
                                .lineLimit(3)
                                .foregroundColor(.primary)
                        }
                        .padding(8)
                        .background(notificationBackgroundColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            // Navigate to the original post thread (reasonSubjectURI)
                            if let post = notification.linkedPost {
                                router.navigateTo(.postThreadWrapped(postThread: post))
                            }
                        }
                    }
                    
        default:
            EmptyView()
        }
    }
    
    private var likeRepostLabel: String {
        switch notification.reason {
        case .like:
            return "Liked post:"
        case .repost:
            return "Reposted post:"
        default:
            return ""
        }
    }
    
    private var replyMentionQuoteLabel: String {
        switch notification.reason {
        case .reply:
            return "Reply:"
        case .mention:
            return "Mention:"
        case .quote:
            return "Quote:"
        default:
            return ""
        }
    }
    
    private var iconColor: Color {
        switch notification.reason {
        case .like:
            return .red
        case .repost:
            return .green
        case .follow:
            return .blue
        case .reply, .mention:
            return .orange
        case .quote:
            return .purple
        case .verified:
            return .mint
        default:
            return .secondary
        }
    }
    
    private var notificationBackgroundColor: Color {
        switch notification.reason {
        case .like:
            return .red
        case .repost:
            return .green
        case .follow:
            return .blue
        case .reply:
            return .orange
        case .mention:
            return .yellow
        case .quote:
            return .purple
        case .verified:
            return .mint
        default:
            return .gray
        }
    }
}

