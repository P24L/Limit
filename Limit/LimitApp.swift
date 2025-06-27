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


@Observable
class NavigationState {
    var selectedTab: Int = 0
    var safariURL: URL? = nil
}

enum AppState: Sendable {
    case unauthenticated
    case authenticated
}

@main
struct LimitApp: App {
    @State private var appState: AppState = .unauthenticated
    @State private var router = AppRouter(initialTab: .timeline)
    @State private var client = BlueskyClient()
    @State private var favoritesURLManager: FavoriteURLManager
    @State private var favoritesPostManager: FavoritePostManager
    @State private var feed: TimelineFeed!
    @State private var currentUser = CurrentUser()
    
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
    }
    
    var body: some Scene  {
        WindowGroup {
            Group {
                switch appState {
                case .unauthenticated:
                    LoadingScreenView()
                case .authenticated:
                    AppRootView()
                        .environment(client)
                        .environment(router)
                        .modelContainer(container)
                        .environment(favoritesURLManager)
                        .environment(favoritesPostManager)
                        .environment(feed)
                        .environment(currentUser)
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
                feed = TimelineFeed(context: container.mainContext, client: client)
                await currentUser.refreshProfile(client: client)
                appState = .authenticated
            }
        } else {
            feed = TimelineFeed(context: container.mainContext, client: client)
            appState = .authenticated
        }
    }
}
    
