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



struct SettingsView: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var router
    @Environment(TimelineFeed.self) private var feed
    @Environment(\.modelContext) var context
    @Environment(AppState.self) private var appState
    
    @Query(
        sort: \TimelinePost.createdAt,
        order: .reverse
    ) private var posts: [TimelinePost]
    
    @AppStorage("debugMode") private var debugMode: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    var body: some View {
        Form {
            // Profile Section
            Section(header: Text("Profile")) {
                Button(action: {
                    if !currentUser.did.isEmpty {
                        router.navigateTo(.actor(userID: currentUser.did))
                    }
                }) {
                    HStack(spacing: 16) {
                        AvatarView(url: currentUser.avatarURL, size: 48)
                        VStack(alignment: .leading) {
                            if !currentUser.displayName.isEmpty {
                                Text(currentUser.displayName).font(.headline)
                            }
                            Text("@" + currentUser.handle).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                // Restore Logout/Login button
                if client.isAuthenticated {
                    Button("Logout") {
                        Task {
                            // Clear keychain credentials
                            let keychain = KeychainSwift()
                            keychain.delete("cz.P24L.limit.handle")
                            keychain.delete("cz.P24L.limit.appPassword")
                            
                            // Clear SwiftData
                            do {
                                let allPosts = try context.fetch(FetchDescriptor<TimelinePost>())
                                allPosts.forEach { context.delete($0) }
                                let allImages = try context.fetch(FetchDescriptor<PostImage>())
                                allImages.forEach { context.delete($0) }
                                let allLinks = try context.fetch(FetchDescriptor<PostLinkExt>())
                                allLinks.forEach { context.delete($0) }
                                let allVideos = try context.fetch(FetchDescriptor<PostVideo>())
                                allVideos.forEach { context.delete($0) }
                                // let allFavoriteURLs = try context.fetch(FetchDescriptor<FavoriteURL>())
                                // allFavoriteURLs.forEach { context.delete($0) }
                                // let allFavoritePosts = try context.fetch(FetchDescriptor<FavoritePost>())
                                // allFavoritePosts.forEach { context.delete($0) }
                                try context.save()
                            } catch {
                                DevLogger.shared.log("SettingsView.swift - error while clearing SwiftData during logout: \(error)")
                            }
                            
                            // Clear currentUser
                            currentUser.clear()
                            
                            // Clear timeline feed from memory
                            feed.clearStorage()
                            
                            // Logout from client
                            await client.logout()
                            
                            // Switch to unauthenticated state
                            appState.setUnauthenticated()
                        }
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Login") {
                        router.presentedSheet = .login
                    }
                    .foregroundColor(.blue)
                }
            }
            // Options Section
            Section(header: Text("Options")) {
                Toggle("Dark Mode", isOn: $isDarkMode)
                    .onChange(of: isDarkMode) {
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first?
                            .windows
                            .first?
                            .overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                    }
            }
            // Debug Section (only in DEBUG builds)
#if DEBUG
            Section(header: Text("Debug")) {
                Toggle("Debug Mode", isOn: $debugMode)
                if debugMode {
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
                    NavigationLink("View Logs", destination: LogViewer())
                    SwiftDataCountView()
                }
            }
#endif
            // About Section
            Section(header: Text("About")) {
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-") (Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"))")
            }
        }
        .onAppear {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first?
                .overrideUserInterfaceStyle = isDarkMode ? .dark : .light
        }
    }

}

struct SwiftDataCountView: View {
    @Environment(\.modelContext) private var context
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
                
                // Count FavoriteURL
                let favoriteURLs = try context.fetch(FetchDescriptor<FavoriteURL>())
                await MainActor.run {
                    favoriteURLCount = favoriteURLs.count
                }
                
                // Count FavoritePost
                let favoritePosts = try context.fetch(FetchDescriptor<FavoritePost>())
                await MainActor.run {
                    favoritePostCount = favoritePosts.count
                }
                
            } catch {
                DevLogger.shared.log("SettingsView.swift - chyba při počítání SwiftData modelů: \(error)")
            }
        }
    }
}
