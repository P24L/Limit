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
    
    @State private var selectedCategory: FavoriteCategory? = .links
    @State private var posts: [TimelinePostWrapper]? = nil
    
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
                    posts = rawPosts
                }
            }
        }
        .navigationTitle("Favorites")
    }

    // MARK: - Section Picker
    @ViewBuilder
    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(FavoriteCategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }) {
                        Text(category.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                            .foregroundColor(selectedCategory == category ? .primary : .secondary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        selectedCategory == category
                                            ? Color.mintAccent.opacity(0.1) : Color.clear
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
    }
    
    // MARK: - Helpers
 



    private struct FavoritePostsSectionView: View {
        let posts: [TimelinePostWrapper]

        var body: some View {
            ForEach(posts, id: \.id) { post in
                PostItemWrappedView(post: post, isThreadView: true) //, postViewType: .favorites
                    .id(post.id)
            }
            .padding(15)
        }
    }

}

struct FavoriteLinksSectionView: View {
    @Environment(FavoriteURLManager.self) private var favoritesURL
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            let sortedFavorites = favoritesURL.favorites.sorted { $0.saveTime > $1.saveTime }
            LazyVStack(spacing: 12) {
                ForEach(sortedFavorites, id: \.id) { favURL in
                    HStack(alignment: .top, spacing: 12) {
                        if let thumbnailURL = favURL.thumbnailImageURL {
                            WebImage(url: thumbnailURL) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle().foregroundStyle(.gray)
                                case .success(let image):
                                    image.resizable()
                                case .failure:
                                    Rectangle().foregroundStyle(.gray)
                                }
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            if let favTitle = favURL.title {
                                Text(favTitle)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Text(favURL.url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.mintAccent.opacity(0.1))
                    .cornerRadius(8)
                    .onTapGesture {
                        router.selectedTab = .safari
                        router.navigateTo(.safari(url: favURL.url), for: .safari)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task {
                                await favoritesURL.removeFavorite(url: favURL.url)
                            }
                        } label: {
                            Label("Smazat", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
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
