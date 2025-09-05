//
//  TrendingCardView.swift
//  Limit
//
//  Created by Claude
//

import SwiftUI
import SDWebImageSwiftUI

struct TrendingCardView: View {
    let item: TrendingURL
    @Environment(AppRouter.self) private var router
    @Environment(BookmarkManager.self) private var bookmarkManager
    
    var onDetailTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with domain and time
            HStack {
                Text(item.domain)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.mintAccent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Text(item.relativeTime)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Image - only show if we have a valid URL
            if let thumbUrl = item.embedThumbUrl, !thumbUrl.isEmpty, let url = URL(string: thumbUrl) {
                WebImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.subtleGray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .tint(.secondaryText)
                        )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .onTapGesture {
                    openURL()
                }
            }
            
            // Title with bookmark button
            if let title = item.embedTitle {
                HStack(alignment: .top, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            openURL()
                        }
                    
                    // Bookmark button
                    Button {
                        Task {
                            if let url = URL(string: item.url) {
                                await bookmarkManager.toggleBookmark(
                                    for: url, 
                                    title: item.embedTitle,
                                    description: item.embedDescription,
                                    imageUrl: item.embedThumbUrl
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "bookmark")
                            .font(.title2)
                            .symbolVariant(isBookmarked ? .fill : .none)
                            .foregroundColor(isBookmarked ? .mintAccent : .postAction)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            
            // Description
            if let description = item.embedDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .lineLimit(4)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .onTapGesture {
                        openURL()
                    }
            }
            
            Spacer(minLength: 12)
            
            // Bottom bar with stats and actions
            HStack(spacing: 20) {
                // Post count
                Label {
                    Text("\(item.postCount)")
                        .font(.footnote)
                        .foregroundColor(.secondaryText)
                } icon: {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                // Like count
                Label {
                    Text("\(item.likeCount)")
                        .font(.footnote)
                        .foregroundColor(.secondaryText)
                } icon: {
                    Image(systemName: "heart")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                // Detail button with text
                Button {
                    onDetailTap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.body)
                        Text("View Posts")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.postAction)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.warmBackground.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .background(Color.warmBackground)
        .cornerRadius(16)
        .cardShadow()
    }
    
    private var isBookmarked: Bool {
        if let url = URL(string: item.url) {
            return bookmarkManager.isBookmarked(url)
        }
        return false
    }
    
    private func openURL() {
        if let url = URL(string: item.url) {
            router.navigateTo(.safari(url: url))
        }
    }
}
