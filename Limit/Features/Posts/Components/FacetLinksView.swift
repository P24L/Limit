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
    @Environment(BookmarkManager.self) private var bookmarkManager
    
    private var uniqueLinks: [TimelinePostWrapper.ProcessedFacet] {
        guard let facets = post.facets else { return [] }
        return facets.uniqueLinks(excluding: post.linkExt?.uri)
    }
    
    var body: some View {
        if !uniqueLinks.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
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
                .frame(maxWidth:.infinity)
            }
            .frame(maxWidth:.infinity)
        }
    }
    
}

struct LinkCardView: View {
    let uri: String
    let isFirst: Bool
    let facet: TimelinePostWrapper.ProcessedFacet
    @Environment(BookmarkManager.self) private var bookmarkManager
    
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
                    .foregroundColor(.mintAccent)
            }
            
            Spacer()
            
            // Bookmark button
            if let url = URL(string: uri) {
                Button {
                    Task {
                        await bookmarkManager.toggleBookmark(for: url, title: facet.title)
                    }
                } label: {
                    Image(systemName: "bookmark")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .symbolVariant(bookmarkManager.isBookmarked(url) ? .fill : .none)
                .symbolEffect(.bounce, value: bookmarkManager.isBookmarked(url))
                .foregroundStyle(bookmarkManager.isBookmarked(url) ? .mintAccent : .postAction)
            }
        }
        .padding(8)
        .frame(maxWidth: cardWidth, minHeight: 80, maxHeight: 80)
        .background(Color.cardSecondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.subtleGray.opacity(0.3), lineWidth: 0.5)
        )
        .cardShadow()
    }
    
    private var faviconPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.subtleGray)
            .overlay(
                Image(systemName: "link")
                    .foregroundColor(.secondaryText)
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
        // Fixed width for consistency
        300
    }
    
    private var displayURL: String {
        if let url = URL(string: uri) {
            return url.host ?? uri
        }
        return uri
    }
}
