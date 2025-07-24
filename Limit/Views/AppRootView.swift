//
//  AppRootView.swift
//  Limit
//
//  Created by Zdenek Indra on 06.06.2025.
//

import AppRouter
import SwiftUI

struct AppRootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(BlueskyClient.self) private var client
    @Environment(NotificationManager.self) private var notificationManager
    
    @State private var isTopbarHidden = false
    
    var body: some View {
        @Bindable var router = router
        
        TabView(selection: $router.selectedTab) {
          ForEach(AppTab.allCases) { tab in
              GeometryReader { _ in
                NavigationStack(path: $router[tab]) {
                  view(for: tab)
                    .navigationDestination(for: Destination.self) { destination in
                      destinationView(for: destination)
                    }
                }
              }
                  .ignoresSafeArea()
            .tabItem {
                Label(tab.description, systemImage: tab.icon)
            }
            .badge(tab == .favorites && notificationManager.unreadCount > 0 ? notificationManager.unreadCount : 0)
            .tag(tab)
          }
        }
        //.tint(.mintAccent)
        .background(.warmBackground)
        .onAppear {
            configureTabBarAppearance()
        }
        .task {
            if !client.isAuthenticated {
                router.presentedSheet = .login
            }
        }
        .sheet(item: $router.presentedSheet) { sheet in
          sheetView(for: sheet)
        }
        .onChange(of: router.presentedSheet) { oldValue, newValue in
            // When compose sheet is dismissed and we're on post tab, go to home
            if case .composePost = oldValue, newValue == nil, router.selectedTab == .post {
                router.selectedTab = .timeline
            }
        }
      }
    
    private func configureTabBarAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        // Background
        tabBarAppearance.backgroundColor = UIColor(.cardBackground)
        
        // Normal state
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(.postAction)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(.postAction)
        ]

        // Selected state
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(.mintAccent)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(.mintAccent)
        ]
        
        // Add subtle shadow
        tabBarAppearance.shadowColor = UIColor(.subtleGray)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    @ViewBuilder
    private func view(for tab: AppTab) -> some View {
        switch tab {
        case .timeline:
            ATTimelineView_experimental()
        case .favorites:
            FavoritesViews()
        case .post:
            // Empty view - we'll show compose sheet instead
            Color.clear
                .onAppear {
                    router.presentedSheet = .composePost()
                }
        case .search:
            SearchTabView()
        case .settings:
            SettingsView()
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: Destination) -> some View {
        switch destination {
        case .timeline:
            ATTimelineView_experimental()
        case .computedTimeline:
            ComputedTimelineView()
        case .search:
            SearchTabView()
        case .searchPosts(let query):
            SearchTabView(initialQuery: query, initialMode: .posts)
        case .postThreadWrapped(let postThread):
            ThreadWrappedView(postThread: postThread)
        case .safari(let url):
            SafariTabView(safariURL: url)
        case .favorites:
            FavoritesViews()
        case .settings:
            SettingsView()
        case .actor(let actorDID):
            ActorView(actorDID: actorDID)
        case .listTimeline(let source):
            ListTimelineView(source: source, isTopbarHidden: $isTopbarHidden)
        case .listManagement:
            ListManagementView()
        case .listMembers(let list):
            ListMembersView(list: list)
        case .feedManagement:
            FeedManagementView()
        case .feedTimeline(let uri, let displayName):
            FeedTimelineView(feedURI: uri, feedDisplayName: displayName)
        case .bookmarkListManagement:
            BookmarkListManagementView()
        }
    }
    
    @ViewBuilder
    private func sheetView(for sheet: Sheet) -> some View {
        switch sheet {
        case .none:
            EmptyView()
        case .fullScreenImage(let images, let initialIndex, let namespace):
                FullScreenImageView(
                    images: images,
                    initialIndex: initialIndex,
                    namespace: namespace,
                    onDismiss: { router.presentedSheet = nil }
                )
        case .login:
            LoginTabView(
                onDismiss: { router.presentedSheet = nil }
            )
        case .composePost(let quotedPost, let replyTo):
            ComposePostView(quotedPost: quotedPost, replyTo: replyTo)
        case .aiExplanation(let postWrapper):
            AIExplanationBottomSheet(postWrapper: postWrapper)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        case .aiSummary(let favoriteURL):
            AISummaryBottomSheet(favoriteURL: favoriteURL)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        case .repostOptions(let post):
            RepostOptionsSheet(post: post)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.hidden)
        }
    }
}
    
