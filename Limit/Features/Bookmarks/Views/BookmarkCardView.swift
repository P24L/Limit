//
//  BookmarkCardView.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct BookmarkCardView: View {
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(AppRouter.self) private var router
    
    let bookmark: BookmarkView
    @State private var isBookmarkAnimating = false
    @State private var isSummaryPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Section: Thumbnail + Content + Bookmark
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                thumbnailView
                
                // Content Area
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.record.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let url = URL(string: bookmark.record.url) {
                        Text(url.host ?? bookmark.record.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
                            try? await bookmarkManager.deleteBookmark(bookmark)
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
            
            // User Description Section - Full Width
            if let description = bookmark.record.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // AI Summary Section - Full Width
            if let summary = bookmark.record.summary, !summary.isEmpty {
                summarySection(summary: summary)
            }
            
            // Tags
            if let tags = bookmark.record.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Date
            Text(bookmark.record.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if let url = URL(string: bookmark.record.url) {
                router.navigateTo(.safari(url: url))
            }
        }
        .onAppear {
            // Track access for LRU cache
            bookmarkManager.trackAccess(for: bookmark.uri)
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if let imageUrl = bookmark.record.imageUrl,
               let url = URL(string: imageUrl) {
                WebImage(url: url) { phase in
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
            } else if let imageBlob = getCachedImageBlob() {
                // Show image from blob
                if let uiImage = UIImage(data: imageBlob) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    defaultThumbnail
                }
            } else {
                defaultThumbnail
            }
        }
    }
    
    @ViewBuilder
    private var defaultThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.gray.opacity(0.2))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
            )
    }
    
    @ViewBuilder
    private func summarySection(summary: String) -> some View {
        Button {
            router.presentedSheet = .aiSummary(bookmark: bookmark)
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.top, 2)
                
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .scaleEffect(isSummaryPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0.1) {
            // Nothing on release
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isSummaryPressed = pressing
            }
        }
    }
    
    private func getCachedImageBlob() -> Data? {
        // This would need to access the cached bookmark from SwiftData
        // For now, return nil
        return nil
    }
}