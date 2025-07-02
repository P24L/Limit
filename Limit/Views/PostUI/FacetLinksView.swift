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
    @Environment(\.modelContext) private var context
    
    @State private var facets: [PostFacet] = []
    
    private var uniqueLinks: [(facet: TimelinePostWrapper.ProcessedFacet, dbFacet: PostFacet?)] {
        guard let postFacets = post.facets else { return [] }
        let uniqueProcessedFacets = postFacets.uniqueLinks(excluding: post.linkExt?.uri)
        
        return uniqueProcessedFacets.map { processedFacet in
            if case .link(let uri) = processedFacet.data {
                let dbFacet = facets.first { $0.uri == uri }
                return (facet: processedFacet, dbFacet: dbFacet)
            }
            return (facet: processedFacet, dbFacet: nil)
        }
    }
    
    var body: some View {
        if !uniqueLinks.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(uniqueLinks.enumerated()), id: \.offset) { index, linkData in
                        if case .link(let uri) = linkData.facet.data {
                            LinkCardView(
                                uri: uri,
                                isFirst: index == 0,
                                dbFacet: linkData.dbFacet
                            )
                            .onTapGesture {
                                if let url = URL(string: uri) {
                                    router.navigateTo(.safari(url: url))
                                }
                            }
                            .task {
                                // Fetch metadata if not already fetched
                                if let dbFacet = linkData.dbFacet, !dbFacet.metadataFetched {
                                    await LinkMetadataService.shared.fetchMetadata(for: dbFacet)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .task {
                await loadFacets()
            }
        }
    }
    
    private func loadFacets() async {
        do {
            // Load all facets and filter in code due to SwiftData relationship limitations
            let descriptor = FetchDescriptor<PostFacet>(
                sortBy: [SortDescriptor(\PostFacet.startIndex)]
            )
            let allFacets = try context.fetch(descriptor)
            facets = allFacets.filter { $0.timelinePost?.uri == post.uri }
        } catch {
            DevLogger.shared.log("FacetLinksView - Failed to load facets: \(error.localizedDescription)")
        }
    }
}

struct LinkCardView: View {
    let uri: String
    let isFirst: Bool
    let dbFacet: PostFacet?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Favicon on the left
            Group {
                if let thumbnailURL = dbFacet?.thumbnailURL, let url = URL(string: thumbnailURL) {
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
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                // URL preview
                Text(displayURL)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(width: cardWidth)
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
        if let title = dbFacet?.title, !title.isEmpty {
            return title
        }
        return dbFacet?.metadataFetched == true ? displayURL : "Loading..."
    }
    
    private var cardWidth: CGFloat {
        // First card 80% width, subsequent cards 100% width
        let screenWidth = UIScreen.main.bounds.width - 32 // Account for padding
        return isFirst ? screenWidth * 0.8 : screenWidth
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