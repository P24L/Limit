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
    @State private var favoritesURLManager: FavoriteURLManager
    @State private var favoritesPostManager: FavoritePostManager
    @State private var feed: TimelineFeed
    @State private var computedFeed = ComputedTimelineFeed()
    @State private var currentUser = CurrentUser()
    @State private var aiService = AIService()
    
    let container: ModelContainer = {
        let config = ModelConfiguration(
            "LimitDB_v40",
            schema: Schema(AppSchema.allModels)
        )
        return try! ModelContainer(
            for: Schema(AppSchema.allModels),
            configurations: config
        )
    }()

    init() {
        _client = State(initialValue: BlueskyClient())
        _favoritesURLManager = State(initialValue: FavoriteURLManager(context: container.mainContext))
        _favoritesPostManager = State(initialValue: FavoritePostManager(context: container.mainContext))
        _feed = State(initialValue: TimelineFeed(context: container.mainContext, client: BlueskyClient()))
        
        // Configure LinkMetadataService
        LinkMetadataService.shared.configure(context: container.mainContext)
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
                        .environment(favoritesURLManager)
                        .environment(favoritesPostManager)
                        .environment(feed)
                        .environment(computedFeed)
                        .environment(currentUser)
                        .environment(appState)
                        .environment(aiService)
                }
            }
            .task {
                await tryAutoLogin()
            }
        }
    }
    
    
    private func tryAutoLogin() async {
        let keychain = KeychainSwift()
        if let handle = keychain.get("cz.P24L.limit.handle"),
           let appPassword = keychain.get("cz.P24L.limit.appPassword") {
            client.handle = handle
            client.appPassword = appPassword
            await client.login()
            if client.isAuthenticated {
                feed.updateClient(client)
                await currentUser.refreshProfile(client: client)
                appState.setAuthenticated()
                
                // Start preparing ComputedTimeline cache with 4s delay to allow main timeline to load first
                Task.detached { [weak computedFeed, weak client] in
                    guard let computedFeed = computedFeed, let client = client else { return }
                    try? await Task.sleep(for: .seconds(4))
                    await computedFeed.prepareSessionCacheInBackground(client: client)
                }
            }
        } else {
            computedFeed.clearSession()
            appState.setUnauthenticated()
        }
    }
    
    private func handleLoginSuccess() async {
        if client.isAuthenticated {
            feed.updateClient(client)
            await currentUser.refreshProfile(client: client)
            appState.setAuthenticated()
            
            // Start preparing ComputedTimeline cache with 4s delay to allow main timeline to load first
            Task.detached { [weak computedFeed, weak client] in
                guard let computedFeed = computedFeed, let client = client else { return }
                try? await Task.sleep(for: .seconds(4))
                await computedFeed.prepareSessionCacheInBackground(client: client)
            }
        } else {
            computedFeed.clearSession()
        }
    }
}
    
