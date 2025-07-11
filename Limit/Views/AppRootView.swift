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
                Label {
                    Text(tab.description)
                } icon: {
                    Image(systemName: tab.icon)
                }
            }
            .tag(tab)
          }
        }
        .tint(.mintAccent)
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
        case .safari:
            SafariTabView()
        case .search:
            SearchTabView()
        case .favorites:
            FavoritesViews()
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
        case .aiExplanation(let postWrapper):
            AIExplanationBottomSheet(postWrapper: postWrapper)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        case .aiSummary(let favoriteURL):
            AISummaryBottomSheet(favoriteURL: favoriteURL)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }
}
    
