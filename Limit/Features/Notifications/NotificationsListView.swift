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
    @Environment(MultiAccountClient.self) private var client
    @State private var isLoading = false
    @State private var hasLoadedInitial = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Group {
            if let error = errorMessage {
                errorStateView(error: error)
            } else if isLoading && notificationManager.allNotifications.isEmpty {
                // Show skeleton loading for initial load
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { _ in
                            NotificationSkeletonRow()
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color.warmBackground)
            } else if notificationManager.allNotifications.isEmpty && !isLoading {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(notificationManager.allNotifications.enumerated()), id: \.element.id) { index, notification in
                            NotificationRowView(notification: notification)
                                .padding(.horizontal, 10)
                                .onAppear {
                                    // Když se zobrazí jedna z posledních 5 notifikací, načíst další
                                    if index >= notificationManager.allNotifications.count - 5 {
                                        Task {
                                            await notificationManager.loadMoreNotifications()
                                        }
                                    }
                                }
                        }
                        
                        // Loading indicator na konci seznamu
                        if notificationManager.isLoadingMore {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading more notifications...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        
                        // End of list indicator
                        if !notificationManager.hasMoreNotifications && notificationManager.allNotifications.count > 0 {
                            Text("No more notifications")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color.warmBackground)
                .refreshable {
                    await loadNotifications(refresh: true)
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
    
    private func loadNotifications(refresh: Bool = false) async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil // Clear any previous error
        
        await notificationManager.loadNotifications(append: false)
        
        isLoading = false
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
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
    }
    
    @ViewBuilder
    private func errorStateView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            
            Text("Failed to load notifications")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                errorMessage = nil
                Task {
                    await loadNotifications()
                }
            }) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.mintAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.warmBackground)
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
                                    .foregroundStyle(.secondary)
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
                                .foregroundStyle(.secondary)
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
                                    .foregroundStyle(.secondary)
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

// MARK: - Loading Skeleton

struct NotificationSkeletonRow: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar skeleton
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 8) {
                // Name skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 16)
                
                // Action text skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 14)
                
                // Post preview skeleton
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
            }
            
            Spacer()
            
            // Time skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 12)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 10)
        .redacted(reason: isAnimating ? .placeholder : [])
        .shimmering(active: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// Shimmer effect modifier
extension View {
    func shimmering(active: Bool = true) -> some View {
        self
            .overlay(
                Group {
                    if active {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: -200)
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: active
                        )
                        .offset(x: active ? 400 : 0)
                    }
                }
            )
            .mask(self)
    }
}

