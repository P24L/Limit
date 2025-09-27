//
//  ProfileTabView.swift
//  Limit
//
//  Created by Assistant on 06.01.2025.
//

import SwiftUI
import SwiftData

struct ProfileTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(MultiAccountClient.self) private var client
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(FavoritePostManager.self) private var favoritesPost
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(CurrentUser.self) private var currentUser
    @Environment(TimelineFeed.self) private var feed
    @Environment(ComputedTimelineFeed.self) private var computedFeed
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    
    @State private var showAddAccountSheet = false
    @State private var isSwitchingAccount = false
    @State private var accountToDelete: UserAccount? = nil
    @State private var showDeleteConfirmation = false
    @State private var showLogoutConfirmation = false
    @State private var accountForReauth: UserAccount? = nil
    
    var body: some View {
        Form {
                // Account Section
                Section {
                    // User profile card
                    if client.isAuthenticated {
                        Button {
                            if let did = client.currentDID {
                                router.navigateTo(.actor(userID: did))
                            }
                        } label: {
                            HStack(spacing: 16) {
                                // Avatar
                                AvatarView(url: currentUser.avatarURL, size: 60)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Display name
                                    if !currentUser.displayName.isEmpty {
                                        Text(currentUser.displayName)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text(client.handle)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    // Handle
                                    Text("@\(client.handle)")
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
                    
                    // Notifications
                    Button {
                        router.navigateTo(.notifications)
                    } label: {
                        HStack {
                            Label("Notifications", systemImage: "bell.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            if notificationManager.unreadCount > 0 {
                                Text("\(notificationManager.unreadCount)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                                    .foregroundColor(.white)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Saved Posts
                    Button {
                        router.navigateTo(.savedPosts)
                    } label: {
                        HStack {
                            Label("Saved Posts", systemImage: "heart.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(favoritesPost.favorites.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Lists
                    Button {
                        router.navigateTo(.listManagement)
                    } label: {
                        HStack {
                            Label("Lists", systemImage: "list.bullet")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(currentUser.lists.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Feeds
                    Button {
                        router.navigateTo(.feedManagement)
                    } label: {
                        HStack {
                            Label("Feeds", systemImage: "rectangle.stack")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(currentUser.feeds.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Bookmark Lists
                    Button {
                        router.navigateTo(.bookmarkListManagement)
                    } label: {
                        HStack {
                            Label("Bookmark Lists", systemImage: "bookmark.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(bookmarkManager.bookmarkLists.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Account")
                }
                
                // Accounts Management Section
                Section(header: Text("Accounts")) {
                    ForEach(AccountManager.shared.accounts) { account in
                        AccountRowView(
                            account: account,
                            isCurrent: account.id == AccountManager.shared.currentAccount?.id
                        )
                        .onTapGesture {
                            if account.needsReauth {
                                // Account needs re-authentication, show login sheet with handle
                                accountForReauth = account
                                showAddAccountSheet = true
                            } else if account.id != AccountManager.shared.currentAccount?.id {
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
                        showAddAccountSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Account")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Actions Section
                Section {
                    // Settings
                    Button {
                        router.navigateTo(.settings)
                    } label: {
                        HStack {
                            Label("Settings", systemImage: "gearshape")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        router.navigateTo(.colorTheme)
                    } label: {
                        HStack {
                            Label("Color Theme", systemImage: "paintpalette")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    NavigationLink {
                        FeatureRequestsView()
                    } label: {
                        HStack {
                            Label("Feature Requests", systemImage: "list.bullet.rectangle.portrait")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // Send Feedback
                    Button {
                        router.presentedSheet = .composePost(initialText: "@limitapp.bsky.social ")
                    } label: {
                        HStack {
                            Label("Send Feedback", systemImage: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // Sign Out
                    Button {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Label("Sign Out", systemImage: "arrow.right.square")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
        }
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Refresh user data when view appears
            if client.isAuthenticated {
                await currentUser.refreshLists(client: client)
                await currentUser.refreshProfile(client: client)
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
            LoginView(prefilledHandle: accountForReauth?.handle ?? "") { success in
                if success {
                    showAddAccountSheet = false
                    accountForReauth = nil
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
        isSwitchingAccount = true
        defer { isSwitchingAccount = false }
        
        // Clear current data
        currentUser.clear()
        feed.clearStorage()
        computedFeed.clearSession()
        
        // Update AccountManager first
        AccountManager.shared.switchToAccount(account)
        
        // Switch account using MultiAccountClient
        await client.switchToAccount(account)
        
        // Check if authenticated
        if client.isAuthenticated {
            // Update real DID if needed (for legacy accounts)
            if account.did.hasPrefix("legacy:"), let realDID = client.currentDID {
                if let password = AccountManager.shared.getAppPassword(for: account) {
                    AccountManager.shared.addAccount(
                        did: realDID,
                        handle: account.handle,
                        appPassword: password,
                        displayName: currentUser.displayName,
                        avatarURL: currentUser.avatarURL
                    )
                    AccountManager.shared.deleteAccount(account, bookmarkManager: bookmarkManager)
                }
            }
            
            // Refresh user data and reload timeline
            feed.updateClient(client)
            feed.loadFromStorage(force: true)
            await currentUser.refreshProfile(client: client)
            
            // Update profile info
            AccountManager.shared.updateAccountProfile(
                for: client.currentDID ?? account.did,
                displayName: currentUser.displayName,
                avatarURL: currentUser.avatarURL
            )
            
            // Reload bookmarks for new user
            await bookmarkManager.loadBookmarksForCurrentUser()
            
            // Start preparing ComputedTimeline cache
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
        // Clear all accounts
        let allAccounts = AccountManager.shared.accounts
        for account in allAccounts {
            AccountManager.shared.deleteAccount(account, bookmarkManager: bookmarkManager)
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
            DevLogger.shared.log("ProfileTabView - Error clearing SwiftData: \(error)")
        }
        
        // Clear user data
        currentUser.clear()
        
        // Clear feeds
        feed.clearStorage(forAllAccounts: true)
        computedFeed.clearSession()
        
        // Logout
        await client.logout()
        
        // Switch to unauthenticated state
        appState.setUnauthenticated()
    }
}
