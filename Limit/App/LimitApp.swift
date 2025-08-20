//
//  LimitApp.swift
//  Limit
//
//  Created by Zdenek Indra on 16.05.2025.
//

import AppRouter
import KeychainSwift
import Observation
import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import SDWebImage
import ATProtoKit


@Observable
class NavigationState {
    var selectedTab: Int = 0
    var safariURL: URL? = nil
}

enum AppStateValue: Sendable {
    case loading
    case unauthenticated
    case authenticated
}

@Observable
@MainActor
class AppState {
    var value: AppStateValue = .loading
    
    func setAuthenticated() {
        value = .authenticated
    }
    
    func setUnauthenticated() {
        value = .unauthenticated
    }
}

@main
struct LimitApp: App {
    @State private var appState = AppState()
    @State private var router = AppRouter(initialTab: .timeline)
    @State private var client = BlueskyClient()
    @State private var bookmarkManager: BookmarkManager
    @State private var favoritesPostManager: FavoritePostManager
    @State private var feed: TimelineFeed
    @State private var computedFeed = ComputedTimelineFeed()
    @State private var currentUser = CurrentUser()
    @State private var aiService = AIService()
    @State private var notificationManager = NotificationManager.shared
    @State private var pendingDeepLink: URL? = nil
    @State private var analyticsService = AnalyticsService.shared
    
    let container: ModelContainer = {
        let config = ModelConfiguration(
            "LimitDB_v41",
            schema: Schema(AppSchema.allModels)
        )
        return try! ModelContainer(
            for: Schema(AppSchema.allModels),
            configurations: config
        )
    }()
    
    let favoritesContainer: ModelContainer = {
        let config = ModelConfiguration(
            "FavoritesDB_v1",
            schema: Schema(FavoritesSchema.allModels)
        )
        return try! ModelContainer(
            for: Schema(FavoritesSchema.allModels),
            configurations: config
        )
    }()
    
    let bookmarkCacheContainer: ModelContainer = {
        let config = ModelConfiguration(
            "BookmarkCacheDB_v2",
            schema: Schema(BookmarkCacheSchema.allModels)
        )
        return try! ModelContainer(
            for: Schema(BookmarkCacheSchema.allModels),
            configurations: config
        )
    }()

    init() {
        let blueskyClient = BlueskyClient()
        _client = State(initialValue: blueskyClient)
        _bookmarkManager = State(initialValue: BookmarkManager(
            context: bookmarkCacheContainer.mainContext,
            client: blueskyClient,
            favoritesContext: favoritesContainer.mainContext
        ))
        _favoritesPostManager = State(initialValue: FavoritePostManager(context: favoritesContainer.mainContext))
        _feed = State(initialValue: TimelineFeed(context: container.mainContext, client: blueskyClient))
        
        // Configure LinkMetadataService
        LinkMetadataService.shared.configure(context: container.mainContext)
        
        // Configure SDWebImage for memory optimization
        configureSDWebImage()
        
        // Register custom bookmark record types
        Task {
            await ATRecordTypeRegistry.shared.register(types: [
                BookmarkRecord.self,
                BookmarkListRecord.self
            ])
            DevLogger.shared.log("LimitApp.swift - Registered bookmark record types")
        }
    }
    
    private func configureSDWebImage() {
        // Configure memory cache
        let config = SDImageCache.shared.config
        config.maxMemoryCost = 20 * 1024 * 1024 // 100MB memory limit
        config.maxMemoryCount = 500 // Maximum 500 images in memory
        
        // Configure disk cache
        config.maxDiskSize = 40 * 1024 * 1024 // 200MB disk limit
        config.maxDiskAge = 7 * 24 * 60 * 60 // 7 days
        
        // Configure download settings
        let downloadManager = SDWebImageDownloader.shared
        downloadManager.config.maxConcurrentDownloads = 6 // Limit concurrent downloads
        downloadManager.config.downloadTimeout = 15.0 // 15 second timeout
        
        // Enable memory pressure monitoring
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Clear memory cache on memory warning
                SDImageCache.shared.clearMemory()
                DevLogger.shared.log("LimitApp.swift - Memory warning: cleared SDWebImage cache")
            }
        }
    }
    
    var body: some Scene  {
        WindowGroup {
            Group {
                switch appState.value {
                case .loading:
                    LoadingScreenView()
                        .environment(client)
                        .environment(currentUser)
                        .environment(appState)
                        .environment(feed)
                        .environment(computedFeed)
                case .unauthenticated:
                    LoadingScreenView()
                        .environment(client)
                        .environment(currentUser)
                        .environment(appState)
                        .environment(feed)
                        .environment(computedFeed)
                case .authenticated:
                    AppRootView()
                        .environment(client)
                        .environment(router)
                        .modelContainer(container)
                        .environment(bookmarkManager)
                        .environment(favoritesPostManager)
                        .environment(feed)
                        .environment(computedFeed)
                        .environment(currentUser)
                        .environment(appState)
                        .environment(aiService)
                        .environment(notificationManager)
                }
            }
            .task {
                // Initialize analytics with delay for performance
                analyticsService.initializeDelayed()
                
                await tryAutoLogin()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    handleUniversalLink(url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if client.isAuthenticated {
                    notificationManager.startPeriodicRefresh()
                }
                // Log app becoming active (foreground)
                analyticsService.logSessionStart()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                notificationManager.stopPeriodicRefresh()
            }
        }
    }
    
    
    private func tryAutoLogin() async {
        guard let currentAccount = AccountManager.shared.currentAccount,
              let appPassword = AccountManager.shared.getAppPassword(for: currentAccount) else {
            computedFeed.clearSession()
            appState.setUnauthenticated()
            return
        }
        
        client.handle = currentAccount.handle
        client.appPassword = appPassword
        await client.login()
        
        if client.isAuthenticated {
            feed.updateClient(client)
            notificationManager.setClient(client)
            
            // Set authenticated state immediately to show UI
            appState.setAuthenticated()
            
            // Start notification refresh immediately
            notificationManager.startPeriodicRefresh()
            
            // Start all background tasks without waiting
            Task.detached { [weak computedFeed, weak bookmarkManager] in
                // Profile refresh first (needed for UI but don't block on it)
                await currentUser.refreshProfile(client: client)
                
                // Update account profile info after refresh
                await MainActor.run {
                    AccountManager.shared.updateAccountProfile(
                        for: client.currentDID ?? currentAccount.did,
                        displayName: currentUser.displayName,
                        avatarURL: currentUser.avatarURL
                    )
                    
                    // Update DID if it was a legacy account
                    if currentAccount.did.hasPrefix("legacy:"), let realDID = client.currentDID {
                        AccountManager.shared.addAccount(
                            did: realDID,
                            handle: currentAccount.handle,
                            appPassword: appPassword,
                            displayName: currentUser.displayName,
                            avatarURL: currentUser.avatarURL
                        )
                        AccountManager.shared.deleteAccount(currentAccount)
                    }
                }
                
                // Start bookmark sync after a delay
                try? await Task.sleep(for: .seconds(2))
                await bookmarkManager?.startSyncAfterAuth()
                
                // Computed timeline preparation with longer delay
                if let computedFeed = computedFeed {
                    try? await Task.sleep(for: .seconds(2)) // Total 4s delay
                    await computedFeed.prepareSessionCacheInBackground(client: client)
                }
            }
            
            // Process any pending deep link after successful login
            if let pending = pendingDeepLink {
                DevLogger.shared.log("LimitApp - Processing pending deep link after login")
                pendingDeepLink = nil
                // Process on main actor to ensure UI updates
                await MainActor.run {
                    // Check if it's a universal link or custom scheme
                    if pending.host == "viewer.hyperlimit.app" {
                        processUniversalLink(pending)
                    } else {
                        processDeepLink(pending)
                    }
                }
            }
        } else {
            computedFeed.clearSession()
            appState.setUnauthenticated()
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        DevLogger.shared.log("LimitApp - Handling deep link: \(url)")
        
        // Check authentication state
        if !client.isAuthenticated {
            DevLogger.shared.log("LimitApp - User not authenticated, storing deep link for later")
            pendingDeepLink = url
            
            // Trigger login if not already in progress
            if appState.value == .unauthenticated {
                Task {
                    await tryAutoLogin()
                }
            }
            return
        }
        
        // Process the deep link immediately
        processDeepLink(url)
    }
    
    private func handleUniversalLink(_ url: URL) {
        DevLogger.shared.log("LimitApp - Handling universal link: \(url)")
        
        // Check if it's our domain
        guard url.host == "viewer.hyperlimit.app" else {
            DevLogger.shared.log("LimitApp - Not our domain: \(url.host ?? "nil")")
            return
        }
        
        // Check authentication state (same as handleDeepLink)
        if !client.isAuthenticated {
            DevLogger.shared.log("LimitApp - User not authenticated, storing universal link for later")
            pendingDeepLink = url  // Store it as pending
            
            // Trigger login if not already in progress
            if appState.value == .unauthenticated {
                Task {
                    await tryAutoLogin()
                }
            }
            return
        }
        
        // Process the universal link immediately
        processUniversalLink(url)
    }
    
    private func processUniversalLink(_ url: URL) {
        DevLogger.shared.log("LimitApp - Processing universal link: \(url)")
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        // Handle bookmark links: https://viewer.hyperlimit.app/at/{did}/{collection}/{rkey}
        if pathComponents.count >= 4 && pathComponents[0] == "at" {
            let did = pathComponents[1]
            let collection = pathComponents[2]
            let rkey = pathComponents[3]
            
            // Reconstruct AT URI
            let atUri = "at://\(did)/\(collection)/\(rkey)"
            
            DevLogger.shared.log("LimitApp - Parsed universal link: did=\(did), collection=\(collection), rkey=\(rkey)")
            
            // Check if it's user's own bookmark
            let isOwner = AccountManager.shared.currentAccount?.did == did || client.currentDID == did
            
            // Navigate based on ownership
            if isOwner {
                // Switch to bookmarks tab first, then navigate
                router.selectedTab = .bookmarks
                router.navigateTo(.bookmarkDetail(id: rkey), for: .bookmarks)
            } else {
                // For external bookmarks, also switch to bookmarks tab
                router.selectedTab = .bookmarks  
                router.navigateTo(.externalBookmark(uri: atUri, isOwner: false), for: .bookmarks)
            }
            
            DevLogger.shared.log("LimitApp - Navigating to bookmark from universal link: \(atUri), isOwner: \(isOwner)")
        }
    }
    
    private func processDeepLink(_ url: URL) {
        DevLogger.shared.log("LimitApp - Processing deep link: \(url)")
        
        // Handle universal links that were redirected here
        if url.host == "viewer.hyperlimit.app" {
            processUniversalLink(url)
            return
        }
        
        // Parse: limit://bookmark/{did}/{collection}/{rkey}
        if url.scheme == "limit" && url.host == "bookmark" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            
            // Expected format: [did, collection, rkey]
            guard pathComponents.count >= 3 else {
                DevLogger.shared.log("LimitApp - Invalid deep link format: \(url)")
                return
            }
            
            let did = pathComponents[0]
            let collection = pathComponents[1]
            let rkey = pathComponents[2]
            
            // Reconstruct AT URI
            let atUri = "at://\(did)/\(collection)/\(rkey)"
            
            DevLogger.shared.log("LimitApp - Parsed deep link: did=\(did), collection=\(collection), rkey=\(rkey)")
            
            // Check if it's user's own bookmark
            // Use AccountManager since client.currentDID might be nil on cold start
            let isOwner = AccountManager.shared.currentAccount?.did == did || client.currentDID == did
            
            // Navigate based on ownership
            if isOwner {
                // For own bookmarks, use regular detail view
                router.selectedTab = .bookmarks
                router.navigateTo(.bookmarkDetail(id: rkey), for: .bookmarks)
            } else {
                // For external bookmarks, use external view
                router.selectedTab = .bookmarks
                router.navigateTo(.externalBookmark(uri: atUri, isOwner: false), for: .bookmarks)
            }
            
            DevLogger.shared.log("LimitApp - Navigating to bookmark: \(atUri), isOwner: \(isOwner)")
        }
    }
    
    private func handleLoginSuccess() async {
        if client.isAuthenticated {
            feed.updateClient(client)
            notificationManager.setClient(client)
            await currentUser.refreshProfile(client: client)
            appState.setAuthenticated()
            
            // Start notification refresh
            notificationManager.startPeriodicRefresh()
            
            // Start preparing ComputedTimeline cache with 4s delay to allow main timeline to load first
            Task.detached { [weak computedFeed, weak client] in
                guard let computedFeed = computedFeed, let client = client else { return }
                try? await Task.sleep(for: .seconds(4))
                await computedFeed.prepareSessionCacheInBackground(client: client)
            }
        } else {
            computedFeed.clearSession()
            notificationManager.clearNotifications()
        }
    }
}
    
