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
    @Environment(ComputedTimelineFeed.self) private var computedFeed
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(FavoritePostManager.self) private var favoritesPost
    
    @Query(
        sort: \TimelinePost.createdAt,
        order: .reverse
    ) private var posts: [TimelinePost]
    
    @AppStorage("debugMode") private var debugMode: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @State private var showAddAccountSheet = false
    @State private var isSwitchingAccount = false
    @State private var accountToDelete: UserAccount? = nil
    @State private var showDeleteConfirmation = false
    @State private var showLogoutConfirmation = false
    
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
                
                // Lists section
                if client.isAuthenticated {
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Lists")
                        Spacer()
                        Text("\(currentUser.lists.count)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        router.navigateTo(.listManagement)
                    }
                    
                    // Feeds section
                    HStack {
                        Image(systemName: "text.append")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("Feeds")
                        Spacer()
                        Text("\(currentUser.feeds.count)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        router.navigateTo(.feedManagement)
                    }
                    
                    // Bookmark Lists section
                    HStack {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("Bookmark Lists")
                        Spacer()
                        Text("\(bookmarkManager.bookmarkLists.count)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        router.navigateTo(.bookmarkListManagement)
                    }
                }
            }
            
            // Accounts Section
            Section(header: Text("Accounts")) {
                ForEach(AccountManager.shared.accounts) { account in
                    AccountRowView(
                        account: account,
                        isCurrent: account.id == AccountManager.shared.currentAccount?.id
                    )
                    .onTapGesture {
                        if account.id != AccountManager.shared.currentAccount?.id {
                            Task {
                                await switchToAccount(account)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if AccountManager.shared.accounts.count > 1 && account.id != AccountManager.shared.currentAccount?.id {
                            Button(role: .destructive) {
                                deleteAccount(account)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                
                // Add Account button
                Button(action: {
                    Task {
                        // Logout current session before adding new account
                        await client.logout()
                        showAddAccountSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add Account")
                            .foregroundColor(.blue)
                    }
                }
                
                // Sign Out of All Accounts button
                if client.isAuthenticated {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Sign Out of All Accounts")
                                .foregroundColor(.red)
                        }
                    }
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
        .task {
            // Refresh lists when view appears
            if client.isAuthenticated {
                await currentUser.refreshLists(client: client)
            }
        }
        .disabled(isSwitchingAccount)
        .overlay {
            if isSwitchingAccount {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView("Switching account...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showAddAccountSheet) {
            LoginView { success in
                if success {
                    DevLogger.shared.log("SettingsView - Add account successful")
                    
                    // The account was already added and made current in LoginTabView
                    // We just need to close the sheet and update the feed
                    showAddAccountSheet = false
                    
                    // Update feed with new client
                    feed.updateClient(client)
                }
            }
            .environment(client)
            .environment(currentUser)
            .environment(appState)
            .environment(feed)
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let account = accountToDelete {
                    AccountManager.shared.deleteAccount(account, bookmarkManager: bookmarkManager)
                }
            }
        } message: {
            Text("Are you sure you want to delete the account @\(accountToDelete?.handle ?? "")?")
        }
        .alert("Sign Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await signOutAllAccounts()
                }
            }
        } message: {
            Text("This will sign you out of all accounts")
        }
    }
    
    // MARK: - Helper Methods
    
    private func switchToAccount(_ account: UserAccount) async {
        guard let password = AccountManager.shared.getAppPassword(for: account) else {
            DevLogger.shared.log("SettingsView - No password found for account")
            return
        }
        
        isSwitchingAccount = true
        defer { isSwitchingAccount = false }
        
        // Clear current data
        currentUser.clear()
        feed.clearStorage()  // This clears only current account's posts
        computedFeed.clearSession()  // Clear computed timeline cache
        
        // Switch account
        let success = await client.switchAccount(to: account, password: password)
        
        if success {
            // Update AccountManager
            AccountManager.shared.switchToAccount(account)
            
            // Update real DID if needed
            if account.did.hasPrefix("legacy:"), let realDID = client.currentDID {
                AccountManager.shared.addAccount(
                    did: realDID,
                    handle: account.handle,
                    appPassword: password,
                    displayName: currentUser.displayName,
                    avatarURL: currentUser.avatarURL
                )
                AccountManager.shared.deleteAccount(account)
            }
            
            // Refresh user data and reload timeline for new account
            feed.updateClient(client)
            feed.loadFromStorage()  // Load posts for the new account
            await currentUser.refreshProfile(client: client)
            
            // Update profile info in AccountManager
            AccountManager.shared.updateAccountProfile(
                for: client.currentDID ?? account.did,
                displayName: currentUser.displayName,
                avatarURL: currentUser.avatarURL
            )
            
            // Reload bookmarks for new user
            await bookmarkManager.loadBookmarksForCurrentUser()
            
            // Start preparing ComputedTimeline cache for new account
            Task.detached { [weak computedFeed, weak client] in
                guard let computedFeed = computedFeed, let client = client else { return }
                try? await Task.sleep(for: .seconds(4))
                await computedFeed.prepareSessionCacheInBackground(client: client)
            }
        }
    }
    
    private func deleteAccount(_ account: UserAccount) {
        accountToDelete = account
        showDeleteConfirmation = true
    }
    
    private func signOutAllAccounts() async {
        // Clear all accounts and their passwords
        let allAccounts = AccountManager.shared.accounts
        for account in allAccounts {
            AccountManager.shared.deleteAccount(account)
        }
        
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
            try context.save()
        } catch {
            DevLogger.shared.log("SettingsView.swift - error while clearing SwiftData during logout: \(error)")
        }
        
        // Clear currentUser
        currentUser.clear()
        
        // Clear timeline feed from memory
        feed.clearStorage(forAllAccounts: true)
        computedFeed.clearSession()
        
        // Logout from client
        await client.logout()
        
        // Switch to unauthenticated state
        appState.setUnauthenticated()
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
