//
//  FacetLinksView.swift
//  Limit
//
//  Created by Claude on 02.07.2025.
//

import SwiftUI
import Foundation
import SwiftData
import SDWebImageSwiftUI

struct FacetLinksView: View {
    let post: TimelinePostWrapper
    @Environment(AppRouter.self) private var router
    @Environment(FavoriteURLManager.self) private var favoritesURL
    
    private var uniqueLinks: [TimelinePostWrapper.ProcessedFacet] {
        guard let facets = post.facets else { return [] }
        return facets.uniqueLinks(excluding: post.linkExt?.uri)
    }
    
    var body: some View {
        if !uniqueLinks.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(uniqueLinks.enumerated()), id: \.offset) { index, facet in
                        if case .link(let uri) = facet.data {
                            LinkCardView(
                                uri: uri,
                                isFirst: index == 0,
                                facet: facet
                            )
                            .onTapGesture {
                                if let url = URL(string: uri) {
                                    router.navigateTo(.safari(url: url))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
}

struct LinkCardView: View {
    let uri: String
    let isFirst: Bool
    let facet: TimelinePostWrapper.ProcessedFacet
    @Environment(FavoriteURLManager.self) private var favoritesURL
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Favicon on the left
            Group {
                if let thumbnailURL = facet.thumbnailURL, let url = URL(string: thumbnailURL) {
                    WebImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        faviconPlaceholder
                    }
                    .frame(width: 32, height: 32)
                } else {
                    faviconPlaceholder
                        .frame(width: 32, height: 32)
                }
            }
            .cornerRadius(6)
            
            // Title and URL on the right
            VStack(alignment: .leading, spacing: 4) {
                // Title from metadata or placeholder
                Text(linkTitle)
                    .font(.footnote)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                // URL preview
                Text(displayURL)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Bookmark button
            if let url = URL(string: uri) {
                Button {
                    Task {
                        if favoritesURL.isFavorited(url) {
                            await favoritesURL.removeFavorite(url: url)
                        } else {
                            let thumbnailURL = facet.thumbnailURL.flatMap { URL(string: $0) }
                            await favoritesURL.addFavorite(url: url, title: facet.title, thumbnailImageURL: thumbnailURL)
                        }
                    }
                } label: {
                    Image(systemName: "bookmark")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .symbolVariant(favoritesURL.isFavorited(url) ? .fill : .none)
                .symbolEffect(.bounce, value: favoritesURL.isFavorited(url))
                .foregroundStyle(favoritesURL.isFavorited(url) ? .mintAccent : .postAction)
            }
        }
        .padding(8)
        .frame(maxWidth: cardWidth, minHeight: 80, maxHeight: 80)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var faviconPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Image(systemName: "link")
                    .foregroundColor(.gray)
                    .font(.caption)
            )
    }
    
    private var linkTitle: String {
        if let title = facet.title, !title.isEmpty {
            return title
        }
        return facet.metadataFetched ? displayURL : "Loading..."
    }
    
    private var cardWidth: CGFloat {
        // First card 80% width, subsequent cards 100% width
        let screenWidth = UIScreen.main.bounds.width - 32 // Account for padding
        return isFirst ? screenWidth * 0.8 : screenWidth * 0.8
    }
    
    private var displayURL: String {
        if let url = URL(string: uri) {
            return url.host ?? uri
        }
        return uri
    }
}

#Preview {
    let samplePost = TimelinePostWrapper(
        uri: "at://sample.post/123",
        cid: "sample123",
        createdAt: Date(),
        type: .post,
        authorID: "did:plc:sample",
        authorHandle: "sample.user",
        authorDisplayName: "Sample User",
        authorAvatarURL: nil,
        text: "Check out these links: https://example.com and https://github.com",
        likeCount: 0,
        replyCount: 0,
        repostCount: 0,
        quoteCount: 0,
        facets: TimelinePostWrapper.PostFacets(facets: [
            TimelinePostWrapper.ProcessedFacet(
                range: NSRange(location: 0, length: 10),
                type: .link,
                data: .link(uri: "https://example.com")
            ),
            TimelinePostWrapper.ProcessedFacet(
                range: NSRange(location: 20, length: 10),
                type: .link,
                data: .link(uri: "https://github.com")
            )
        ])
    )
    
    FacetLinksView(post: samplePost)
        .environment(AppRouter(initialTab: .timeline))
        .modelContainer(for: [TimelinePost.self, PostFacet.self])
}