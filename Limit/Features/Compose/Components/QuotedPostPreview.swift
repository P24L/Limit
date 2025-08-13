//
//  QuotedPostPreview.swift
//  Limit
//
//  Created by Assistant on 19.07.2025.
//

import SwiftUI
import ATProtoKit

struct QuotedPostPreview: View {
    let post: TimelinePostWrapper
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author info
            HStack(spacing: 8) {
                // Avatar
                if let avatarURL = post.authorAvatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                }
                
                // Name and handle
                VStack(alignment: .leading, spacing: 0) {
                    Text(post.authorDisplayName ?? post.authorHandle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("@\(post.authorHandle)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Timestamp
                Text(post.createdAt.relativeFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Post text
            Text(post.text)
                .font(.caption)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Images preview if any
            if !post.embeds.isEmpty {
                HStack(spacing: 4) {
                    ForEach(post.embeds.prefix(3), id: \.id) { embed in
                        AsyncImage(url: embed.thumbURL ?? embed.url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipped()
                                .cornerRadius(6)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 50, height: 50)
                        }
                    }
                    
                    if post.embeds.count > 3 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text("+\(post.embeds.count - 3)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}