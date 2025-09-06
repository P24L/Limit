//
//  MoreOptionsSheet.swift
//  Limit
//
//  Created by Assistant on 19.07.2025.
//

import SwiftUI
import AppRouter
import UIKit

struct MoreOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(MultiAccountClient.self) private var client
    @Environment(FavoritePostManager.self) private var favorites
    
    let post: TimelinePostWrapper
    
    @State private var showCopiedToast = false
    @State private var shareURL: URL? = nil
    @State private var isSharing = false
    @State private var isBookmarkWorking = false
    @State private var isRepostWorking = false
    @State private var isDeleting = false
    
    private var isOwnPost: Bool {
        post.authorHandle == client.handle || post.authorID == client.currentDID
    }
    
    private var canCopyText: Bool { !post.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    private var bskyPermalink: URL? {
        guard let components = ATProtoUtils.parseURI(post.uri) else { return nil }
        // Bluesky public link: https://bsky.app/profile/{handleOrDID}/post/{rkey}
        let profile = post.authorHandle.isEmpty ? components.repo : post.authorHandle
        return URL(string: "https://bsky.app/profile/\(profile)/post/\(components.rkey)")
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 12) {
                    // Core actions
                    if canCopyText {
                        actionRow(icon: "doc.on.doc", tint: .mintAccent, title: "Copy Text") {
                            copyToPasteboard(post.text)
                            dismiss()
                        }
                    }
                    actionRow(icon: "link", tint: .mintAccent, title: "Copy Link") {
                        if let url = bskyPermalink {
                            copyToPasteboard(url.absoluteString)
                            dismiss()
                        }
                    }
                    actionRow(icon: "square.and.arrow.up", tint: .mintAccent, title: "Share…") {
                        if let url = bskyPermalink { shareURL = url }
                    }
                    actionRow(icon: "bubble.right", tint: .mintAccent, title: "View Thread") {
                        dismiss()
                        router.navigateTo(.postThreadWrapped(postThread: post))
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // Engagement
                    actionRow(
                        icon: "bookmark",
                        tint: favorites.isFavorited(post.uri) ? .mintAccent : .postAction,
                        title: favorites.isFavorited(post.uri) ? "Remove Bookmark" : "Add Bookmark",
                        showProgress: isBookmarkWorking
                    ) {
                        Task { @MainActor in
                            isBookmarkWorking = true
                            if favorites.isFavorited(post.uri) {
                                await favorites.removeFavorite(postID: post.uri)
                            } else {
                                await favorites.addFavorite(postID: post.uri)
                            }
                            isBookmarkWorking = false
                            dismiss()
                        }
                    }
                    
                    if post.isReposted || isRepostedByMe {
                        actionRow(icon: "arrow.2.squarepath", tint: .orange, title: "Undo Repost", showProgress: isRepostWorking) {
                            Task { @MainActor in
                                isRepostWorking = true
                                await post.toggleRepost(using: client)
                                isRepostWorking = false
                                dismiss()
                            }
                        }
                    } else {
                        actionRow(icon: "arrow.2.squarepath", tint: .mintAccent, title: "Repost", showProgress: isRepostWorking) {
                            Task { @MainActor in
                                isRepostWorking = true
                                await post.toggleRepost(using: client)
                                isRepostWorking = false
                                dismiss()
                            }
                        }
                    }
                    
                    actionRow(icon: "quote.bubble", tint: .mintAccent, title: "Quote Post") {
                        dismiss()
                        router.presentedSheet = .composePost(quotedPost: post)
                    }
                    
                    // Owner actions
                    if isOwnPost {
                        Divider().padding(.vertical, 4)
                        actionRow(icon: "trash", tint: .red, title: "Delete Post", showProgress: isDeleting) {
                            Task { @MainActor in
                                isDeleting = true
                                let success = await client.deletePost(uri: post.uri)
                                isDeleting = false
                                if success { dismiss() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: .constant(shareURL != nil)) {
            if let url = shareURL {
                ActivityView(activityItems: [url])
                    .onDisappear { shareURL = nil }
            }
        }
    }
    
    private var isRepostedByMe: Bool {
        post.repostedByHandle == client.handle || post.repostedByID == client.currentDID
    }
    
    @ViewBuilder
    private func actionRow(icon: String, tint: Color, title: String, showProgress: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tint)
                    .frame(width: 40)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                if showProgress { ProgressView().scaleEffect(0.8) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var copiedToast: some View {
        Text("Copied")
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
    }
    
    private func copyToPasteboard(_ string: String) {
        UIPasteboard.general.string = string
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showCopiedToast = false }
        }
    }
}

// Simple wrapper for UIActivityViewController
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
