//
//  SettingsView.swift
//  Limit
//
//  Created by Zdenek Indra on 27.05.2025.
//


import Foundation
import SwiftUI
import SwiftData
import KeychainSwift
import StoreKit
import SDWebImage



struct SettingsView: View {
    @Environment(MultiAccountClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var router
    @Environment(TimelineFeed.self) private var feed
    @Environment(\.modelContext) var context
    @Environment(AppState.self) private var appState
    @Environment(ComputedTimelineFeed.self) private var computedFeed
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(FavoritePostManager.self) private var favoritesPost
    @Environment(UserPreferences.self) private var preferences
    @Environment(AppTheme.self) private var theme

    @Query(
        sort: \TimelinePost.createdAt,
        order: .reverse
    ) private var posts: [TimelinePost]
    
    @State private var showAddAccountSheet = false
    @State private var isSwitchingAccount = false
    @State private var accountToDelete: UserAccount? = nil
    @State private var showDeleteConfirmation = false
    @State private var showLogoutConfirmation = false
    @State private var showClearTimelineConfirmation = false
    @State private var isClearingTimelinePosts = false
    @State private var isClearingMediaCache = false

    var body: some View {
        Form {
            // Timeline Section
            Section(header: Text("Timeline")) {
                Toggle("Show replies to others", isOn: Binding(
                    get: { preferences.showRepliesToOthers },
                    set: { preferences.showRepliesToOthers = $0 }
                ))
                Toggle("Show direct reply context", isOn: Binding(
                    get: { preferences.showDirectReplyContext },
                    set: { preferences.showDirectReplyContext = $0 }
                ))
                Toggle("Auto-play videos", isOn: Binding(
                    get: { preferences.autoPlayVideos },
                    set: { preferences.autoPlayVideos = $0 }
                ))
                NavigationLink("Muted users") {
                    MutedRepliesSettingsView()
                }
                Button(role: .destructive) {
                    showClearTimelineConfirmation = true
                } label: {
                    if isClearingTimelinePosts {
                        ProgressView()
                    } else {
                        Text("Clear timeline posts")
                    }
                }
                .disabled(isClearingTimelinePosts)
            }
            // Debug Section (only in DEBUG builds)
#if DEBUG
            Section(header: Text("Debug")) {
                Toggle("Debug Mode", isOn: Binding(
                    get: { preferences.debugMode },
                    set: { preferences.debugMode = $0 }
                ))
                if preferences.debugMode {
                    Button("Clear Old Data") {
                        Task {
                            do {
                                let allPosts = try context.fetch(FetchDescriptor<TimelinePost>())
                                let temporaryThreadPosts = allPosts.filter { $0.type == .temporaryThread }
                                temporaryThreadPosts.forEach { context.delete($0) }
                                let postTypePosts = allPosts.filter { $0.type == .post }
                                if postTypePosts.count > 3000 {
                                    let postsToDelete = Array(postTypePosts.dropFirst(2000))
                                    postsToDelete.forEach { context.delete($0) }
                                    DevLogger.shared.log("SettingsView.swift - deleted \(postsToDelete.count) old posts")
                                }
                                let allImages = try context.fetch(FetchDescriptor<PostImage>())
                                let orphanedImages = allImages.filter { $0.timelinePost == nil }
                                orphanedImages.forEach { context.delete($0) }
                                let allLinks = try context.fetch(FetchDescriptor<PostLinkExt>())
                                let orphanedLinks = allLinks.filter { $0.timelinePost == nil }
                                orphanedLinks.forEach { context.delete($0) }
                                let allVideos = try context.fetch(FetchDescriptor<PostVideo>())
                                let orphanedVideos = allVideos.filter { $0.timelinePost == nil }
                                orphanedVideos.forEach { context.delete($0) }
                                try context.save()
                                DevLogger.shared.log("SettingsView.swift - deleted \(temporaryThreadPosts.count) temporary thread posts")
                                DevLogger.shared.log("SettingsView.swift - deleted \(orphanedImages.count) orphaned images")
                                DevLogger.shared.log("SettingsView.swift - deleted \(orphanedLinks.count) orphaned links")
                                DevLogger.shared.log("SettingsView.swift - deleted \(orphanedVideos.count) orphaned videos")
                            } catch {
                                DevLogger.shared.log("SettingsView.swift - error while deleting old posts: \(error)")
                            }
                        }
                    }
                    Button("Clear All Data") {
                        Task {
                            do {
                                let allPosts = try context.fetch(FetchDescriptor<TimelinePost>())
                                allPosts.forEach { context.delete($0) }
                                let allImages = try context.fetch(FetchDescriptor<PostImage>())
                                allImages.forEach { context.delete($0) }
                                let allLinks = try context.fetch(FetchDescriptor<PostLinkExt>())
                                allLinks.forEach { context.delete($0) }
                                let allVideos = try context.fetch(FetchDescriptor<PostVideo>())
                                allVideos.forEach { context.delete($0) }
                                try context.save()
                            } catch {
                                DevLogger.shared.log("SettingsView.swift - error while deleting all SwiftData objects: \(error)")
                            }
                        }
                    }
                    
                    // Test OAuth re-authentication
                    Button("Simulate Expired OAuth Token") {
                        if let currentAccount = AccountManager.shared.currentAccount {
                            AccountManager.shared.markAccountNeedsReauth(currentAccount)
                            DevLogger.shared.log("SettingsView - Simulated expired OAuth for: \(currentAccount.handle)")
                        }
                    }
                    .foregroundColor(.orange)
                    NavigationLink("View Logs", destination: LogViewer())
                    SwiftDataCountView()
                }
            }
#endif
            // Links Section
            Section(header: Text("Links")) {
                Button {
                    if #available(iOS 18.0, *) {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            AppStore.requestReview(in: windowScene)
                        }
                    } else {
                        // Fallback for iOS 17 and earlier
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: windowScene)
                        }
                    }
                } label: {
                    HStack {
                        Label("Rate Limit", systemImage: "star.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Button {
                    if let url = URL(string: "https://p24l.github.io/Limit/PRIVACY_POLICY.html") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label("Privacy Policy", systemImage: "lock.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Button {
                    if let url = URL(string: "https://github.com/P24L/Limit") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label("Source (GitHub)", systemImage: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            // Developer Profiles Section
            Section(header: Text("Developer Profiles")) {
                // Limit App Profile
                Button {
                    router.navigateTo(.actor(userID: "limitapp.bsky.social"))
                } label: {
                    HStack(spacing: 16) {
                        // Avatar
                        AvatarView(url: URL(string: "https://cdn.bsky.app/img/avatar_thumbnail/plain/did:plc:bhjhmdlfpjyc3xk7ha3tptdi/bafkreie2v33n3mb2fc6o4yjahgo5bjuw7wc2nauq35qje2pmhns373buoi@jpeg"), size: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            // Display name
                            Text("Limit App")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            // Handle
                            Text("@limitapp.bsky.social")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                // P24L Profile
                Button {
                    router.navigateTo(.actor(userID: "p24l.bsky.social"))
                } label: {
                    HStack(spacing: 16) {
                        // Avatar
                        AvatarView(url: URL(string: "https://cdn.bsky.app/img/avatar_thumbnail/plain/did:plc:5j2yklrr4pozy7yhrdq5xfn7/bafkreidko5gl66gmrj5jerwre5yvvjx45se5tq5htd2fmcgjrebgo6k22q@jpeg"), size: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            // Display name
                            Text("P24L")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            // Handle
                            Text("@p24l.bsky.social")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            // About Section
            Section(header: Text("More")) {
                Toggle("In-app browser", isOn: Binding(
                    get: { preferences.openLinksInApp },
                    set: { preferences.openLinksInApp = $0 }
                ))
                Button {
                    clearMediaCache()
                } label: {
                    if isClearingMediaCache {
                        HStack {
                            ProgressView()
                            Text("Clearing media cache...")
                        }
                    } else {
                        Text("Clear Media Cache")
                    }
                }
                .disabled(isClearingMediaCache)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-") (Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"))")
            }
        }
        .alert("Clear timeline posts?", isPresented: $showClearTimelineConfirmation) {
            Button("Clear", role: .destructive) {
                clearTimelinePosts()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes all cached timeline posts, media, link metadata, and actor data stored locally.")
        }
    }
}

extension SettingsView {
    @MainActor
    private func clearTimelinePosts() {
        guard !isClearingTimelinePosts else { return }

        isClearingTimelinePosts = true
        defer { isClearingTimelinePosts = false }

        do {
            feed.clearStorage()

            let postImages = try context.fetch(FetchDescriptor<PostImage>())
            postImages.forEach { context.delete($0) }

            let postLinks = try context.fetch(FetchDescriptor<PostLinkExt>())
            postLinks.forEach { context.delete($0) }

            let postVideos = try context.fetch(FetchDescriptor<PostVideo>())
            postVideos.forEach { context.delete($0) }

            let postFacets = try context.fetch(FetchDescriptor<PostFacet>())
            postFacets.forEach { context.delete($0) }

            try context.save()

            if let accountDID = client.currentDID {
                TimelinePositionManager.shared.clearPositionsForAccount(accountDID)
            }

            feed.loadFromStorage(force: true)

            DevLogger.shared.log("SettingsView.swift - Cleared timeline posts and related SwiftData objects")
        } catch {
            DevLogger.shared.log("SettingsView.swift - Failed to clear timeline posts: \(error)")
        }
    }

    private func clearMediaCache() {
        guard !isClearingMediaCache else { return }

        isClearingMediaCache = true
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk {
            Task { @MainActor in
                isClearingMediaCache = false
                DevLogger.shared.log("SettingsView.swift - Cleared SDWebImage cache")
            }
        }
    }
}

struct SwiftDataCountView: View {
    @Environment(\.modelContext) private var context
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(FavoritePostManager.self) private var favoritesPost
    @State private var timelinePostCount: Int = 0
    @State private var postImageCount: Int = 0
    @State private var favoriteURLCount: Int = 0
    @State private var favoritePostCount: Int = 0
    
    // TimelinePost type breakdown
    @State private var postTypeCount: Int = 0
    @State private var quotedTypeCount: Int = 0
    @State private var parentTypeCount: Int = 0
    @State private var rootTypeCount: Int = 0
    @State private var temporaryThreadTypeCount: Int = 0
    
    // PostFacet (Links) breakdown
    @State private var linkFacetsTotal: Int = 0
    @State private var linkFacetsInPosts: Int = 0
    @State private var linkFacetsMetadataCache: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TimelinePost: \(timelinePostCount)")
                .fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 2) {
                Text("  - Post: \(postTypeCount)")
                Text("  - Quoted: \(quotedTypeCount)")
                Text("  - Parent: \(parentTypeCount)")
                Text("  - Root: \(rootTypeCount)")
                Text("  - TemporaryThread: \(temporaryThreadTypeCount)")
            }
            .padding(.leading, 8)
            Text("PostImage: \(postImageCount)")
            Text("PostFacet (Links): \(linkFacetsTotal)")
                .fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 2) {
                Text("  - In Posts: \(linkFacetsInPosts)")
                Text("  - Metadata Cache: \(linkFacetsMetadataCache)")
            }
            .padding(.leading, 8)
            Text("FavoriteURL: \(favoriteURLCount)")
            Text("FavoritePost: \(favoritePostCount)")
        }
        .onAppear {
            updateCounts()
        }
    }
    
    private func updateCounts() {
        Task {
            do {
                // Count TimelinePost and breakdown by type
                let timelinePosts = try context.fetch(FetchDescriptor<TimelinePost>())
                await MainActor.run {
                    timelinePostCount = timelinePosts.count
                    postTypeCount = timelinePosts.filter { $0.type == .post }.count
                    quotedTypeCount = timelinePosts.filter { $0.type == .quoted }.count
                    parentTypeCount = timelinePosts.filter { $0.type == .parent }.count
                    rootTypeCount = timelinePosts.filter { $0.type == .root }.count
                    temporaryThreadTypeCount = timelinePosts.filter { $0.type == .temporaryThread }.count
                }
                
                // Count PostImage
                let postImages = try context.fetch(FetchDescriptor<PostImage>())
                await MainActor.run {
                    postImageCount = postImages.count
                }
                
                // Count Bookmarks from manager
                await MainActor.run {
                    favoriteURLCount = bookmarkManager.bookmarks.count
                }
                
                // Count FavoritePost from manager
                await MainActor.run {
                    favoritePostCount = favoritesPost.favorites.count
                }
                
                // Count PostFacet (Links)
                let allFacets = try context.fetch(FetchDescriptor<PostFacet>())
                let allLinkFacets = allFacets.filter { $0.facetType == .link }
                
                let facetsInPosts = allLinkFacets.filter { $0.timelinePost != nil }
                let facetsMetadataCache = allLinkFacets.filter { $0.timelinePost == nil }
                
                await MainActor.run {
                    linkFacetsTotal = allLinkFacets.count
                    linkFacetsInPosts = facetsInPosts.count
                    linkFacetsMetadataCache = facetsMetadataCache.count
                }
                
            } catch {
                DevLogger.shared.log("SettingsView.swift - chyba při počítání SwiftData modelů: \(error)")
            }
        }
    }
}
