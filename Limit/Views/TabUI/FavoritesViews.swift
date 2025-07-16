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
    @Environment(\EnvironmentValues.modelContext) private var context
    @Environment(BlueskyClient.self) private var client
    @Environment(FavoriteURLManager.self) private var favoritesURL
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
        HStack(spacing: 0) {
            ForEach(FavoriteCategory.allCases, id: \.self) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 4) {
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
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedCategory == category ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
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
    @Environment(FavoriteURLManager.self) private var favoritesURL
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            let sortedFavorites = favoritesURL.favorites.sorted { $0.saveTime > $1.saveTime }
            
            if sortedFavorites.isEmpty {
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
                    ForEach(sortedFavorites, id: \.id) { favURL in
                        FavoriteLinkCardView(favoriteURL: favURL)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FavoriteLinkCardView: View {
    @Environment(FavoriteURLManager.self) private var favoritesURL
    @Environment(AppRouter.self) private var router
    
    let favoriteURL: FavoriteURL
    @State private var isBookmarkAnimating = false
    @State private var isSummaryPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Section: Thumbnail + Content + Bookmark
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                if let thumbnailURL = favoriteURL.thumbnailImageURL {
                    WebImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().foregroundStyle(.gray.opacity(0.3))
                        case .success(let image):
                            image.resizable()
                        case .failure:
                            Rectangle().foregroundStyle(.gray.opacity(0.3))
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Default placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                        )
                }
                
                // Content Area
                VStack(alignment: .leading, spacing: 2) {
                    if let title = favoriteURL.title {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(favoriteURL.url.host ?? favoriteURL.url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(favoriteURL.url.absoluteString)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // Bookmark Toggle
                VStack {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isBookmarkAnimating = true
                        }
                        
                        Task {
                            await favoritesURL.removeFavorite(url: favoriteURL.url)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isBookmarkAnimating = false
                        }
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                            .scaleEffect(isBookmarkAnimating ? 1.2 : 1.0)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
            
            // AI Summary Section - Full Width
            if favoriteURL.safeSummaryStatus == .completed, let summary = favoriteURL.summary {
                Button {
                    router.presentedSheet = .aiSummary(favoriteURL: favoriteURL)
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.headline)
                                .foregroundStyle(.blue.opacity(0.7))
                            Spacer()
                        }
                    }
                    .padding(8)
                    .background(.blue.opacity(isSummaryPressed ? 0.1 : 0.05))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.blue.opacity(0.2), lineWidth: 0.5)
                    )
                    .scaleEffect(isSummaryPressed ? 0.98 : 1.0)
                }
                .buttonStyle(.plain)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isSummaryPressed = pressing
                    }
                }, perform: {})
                
            } else if favoriteURL.safeSummaryStatus == .processing {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    ProgressView()
                        .scaleEffect(0.6)
                    
                    Text("Generating summary...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.blue.opacity(0.03))
                .cornerRadius(6)
                
            } else if favoriteURL.safeSummaryStatus == .failed && favoriteURL.canRetrySummarization {
                Button {
                    Task {
                        await favoritesURL.retrySummary(for: favoriteURL)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        Text("Tap to retry summary")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    .padding(8)
                    .background(.orange.opacity(0.05))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.mintAccent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            router.navigateTo(.safari(url: favoriteURL.url))
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
