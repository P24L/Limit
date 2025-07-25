//
//  FavoritesViews.swift
//  Limit
//
//  Created by Zdenek Indra on 05.06.2025.
//

import SwiftData
import SwiftUI
import SDWebImageSwiftUI

struct FavoritesViews: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(BlueskyClient.self) private var client
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(FavoritePostManager.self) private var favoritesPost
    @Environment(NotificationManager.self) private var notificationManager
    
    @State private var selectedCategory: FavoriteCategory? = .links
    @State private var posts: [TimelinePostWrapper]? = nil
    @State private var showMarkAllReadButton = false
    
    var selectedCategories: [FavoriteCategory] = FavoriteCategory.allCases
    
    var body: some View {
        ScrollView {
            LazyVStack(pinnedViews: [.sectionHeaders]) {
                Section(header: sectionPicker) {
                    switch selectedCategory {
                    case .links:
                        FavoriteLinksSectionView()
                    case .posts:
                        if let posts {
                            FavoritePostsSectionView(posts: posts)
                        }
                    case .notifications:
                        NotificationsListView()
                    case .none:
                        EmptyView()
                    }
                }
            }
        }
        .task {
            let ids = favoritesPost.favorites.map { $0.postID }
            if ids.count > 0 {
                let rawPosts = await client.fetchPostWrappersByID(for: ids)
                if rawPosts.count > 0 {
                    posts = rawPosts.sorted { $0.createdAt > $1.createdAt }
                }
            }
        }
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Mark All Read button for notifications
            if selectedCategory == .notifications && notificationManager.unreadCount > 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await notificationManager.markAllAsRead()
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.mintAccent)
                    }
                }
            }
        }
    }

    // MARK: - Section Picker
    @ViewBuilder
    private var sectionPicker: some View {
        ViewThatFits(in: .horizontal) {
            // Plná verze s textem
            pickerWithText
            
            // Kompaktní verze pouze s ikonami
            pickerWithIcons
        }
    }
    
    @ViewBuilder
    private var pickerWithText: some View {
        HStack(spacing: 0) {
            ForEach(FavoriteCategory.allCases, id: \.self) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(category.rawValue)
                            .font(.footnote)
                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                        
                        // Badge pro notifikace
                        if category == .notifications && notificationManager.unreadCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedCategory == category ? Color.mintAccent : Color.clear)
                    )
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var pickerWithIcons: some View {
        HStack(spacing: 0) {
            ForEach(FavoriteCategory.allCases, id: \.self) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 16))
                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedCategory == category ? Color.mintAccent : Color.clear)
                            )
                        
                        // Badge pro notifikace
                        if category == .notifications && notificationManager.unreadCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: -8, y: 8)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    
    private struct FavoritePostsSectionView: View {
        let posts: [TimelinePostWrapper]

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(posts, id: \.id) { post in
                        PostItemWrappedView(post: post, isThreadView: true) //, postViewType: .favorites
                            .id(post.id)
                    }
                }
                .padding(15)
                //.padding(.horizontal, 10)
                .background(.warmBackground)
            }
        }
    }

}

struct FavoriteLinksSectionView: View {
    @Environment(BookmarkManager.self) var bookmarkManager
    @Environment(AppRouter.self) var router

    var body: some View {
        ScrollView {
            let sortedBookmarks = bookmarkManager.bookmarks
                .filter { $0.record.archived != true }
                .sorted { $0.record.createdAt > $1.record.createdAt }
            
            if sortedBookmarks.isEmpty && !bookmarkManager.isSyncing {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                    
                    Text("No Saved Links")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text("Save links from posts and web pages to find them here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 300)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sortedBookmarks, id: \.uri) { bookmark in
                        BookmarkCardView(bookmark: bookmark)
                            .onAppear {
                                // Load more when we reach near the end
                                if let index = sortedBookmarks.firstIndex(where: { $0.uri == bookmark.uri }),
                                   index == sortedBookmarks.count - 3 {
                                    Task {
                                        await bookmarkManager.loadNextPage()
                                    }
                                }
                            }
                    }
                    
                    // Loading indicator
                    if bookmarkManager.isLoadingPage {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading more bookmarks...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding(.horizontal)
            }
        }
        .refreshable {
            await bookmarkManager.fetchAndSyncBookmarks()
        }
    }
}


#Preview {
    struct FavoritesViewPreviewContainer: View {
        @State private var navigation = NavigationState()
        
        var body: some View {
            FavoritesViews()
                .modelContainer(SampleData.shared.modelContainer)
                .environment(navigation)
        }
    }
    
    return FavoritesViewPreviewContainer()
}
