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
    @Environment(MultiAccountClient.self) private var client
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CurrentUser.self) private var currentUser
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject private var listTimelineCache = ListTimelineViewModelCache()
    
    var body: some View {
        @Bindable var router = router
        let colors = themeManager.colors

        ZStack {
            TabView(selection: $router.selectedTab) {
          ForEach(AppTab.allCases) { tab in
              //GeometryReader { _ in
                NavigationStack(path: $router[tab]) {
                  view(for: tab)
                    .navigationDestination(for: Destination.self) { destination in
                      destinationView(for: destination)
                    }
                }
              //}
            .tabItem {
                Label(tab.description, systemImage: tab.icon)
            }
            .badge(tab == .profile && notificationManager.unreadCount > 0 ? notificationManager.unreadCount : 0)
            .tag(tab)
          }
            }
            //.tint(.mintAccent)
            .background(colors.backgroundPrimary)
            .onAppear {
                themeManager.updateColorScheme(colorScheme)
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
            .onChange(of: colorScheme) { _, newValue in
                themeManager.updateColorScheme(newValue)
                configureTabBarAppearance()
            }
            .onChange(of: currentUser.did) { _, _ in
                listTimelineCache.removeAll()
            }
        }
    }
    
    private func configureTabBarAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()

        // Background
        tabBarAppearance.backgroundColor = UIColor(themeManager.colors.surfacePrimary)

        // Normal state
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(themeManager.colors.textSecondary)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(themeManager.colors.textSecondary)
        ]

        // Selected state
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(themeManager.colors.accent)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(themeManager.colors.accent)
        ]

        // Add subtle shadow
        tabBarAppearance.shadowColor = UIColor(themeManager.colors.border)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    @ViewBuilder
    private func view(for tab: AppTab) -> some View {
        switch tab {
        case .timeline:
            ATTimelineView_experimental()
        case .news:
            NewsView()
        case .bookmarks:
            BookmarksTabView()
        case .search:
            SearchTabView()
        case .profile:
            ProfileTabView()
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
        case .colorTheme:
            ColorThemeView()
        case .actor(let actorDID):
            ActorView(actorDID: actorDID)
        case .listTimeline(let source):
            ListTimelineView(
                viewModel: listViewModel(for: source)
            )
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
        case .bookmarkDetail(let id):
            BookmarkDetailView(bookmarkId: id)
        case .bookmarkEdit(let id):
            BookmarkEditSheet(bookmarkId: id)
        case .externalBookmark(let uri, let isOwner):
            ExternalBookmarkView(bookmarkUri: uri, isOwner: isOwner)
        case .notifications:
            NotificationsListView()
        case .savedPosts:
            SavedPostsView()
        case .newsDetail(let url):
            NewsDetailView(urlString: url)
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
        case .composePost(let quotedPost, let replyTo, let bookmark, let initialText):
            ComposePostView(quotedPost: quotedPost, replyTo: replyTo, bookmark: bookmark, initialText: initialText)
        case .aiExplanation(let type):
            AIExplanationBottomSheet(explanationType: type)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        case .aiSummary(let bookmark):
            AISummaryBottomSheet(bookmark: bookmark)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        case .repostOptions(let post):
            RepostOptionsSheet(post: post)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.hidden)
        case .moreOptions(let post):
            MoreOptionsSheet(post: post)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .bookmarkEdit(let id):
            BookmarkEditSheet(bookmarkId: id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func listViewModel(for source: TimelineContentSource) -> ListTimelineViewModel {
        switch source {
        case .list(let list):
            return currentUser.listViewModel(for: list, client: client)
        default:
            let accountDID = currentUser.did.isEmpty ? nil : currentUser.did
            return listTimelineCache.viewModel(for: source, client: client, accountDID: accountDID)
        }
    }
}
    
