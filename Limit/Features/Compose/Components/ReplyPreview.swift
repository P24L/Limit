//
//  ReplyPreview.swift
//  Limit
//
//  Created by Assistant on 19.07.2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct ReplyPreview: View {
    let post: TimelinePostWrapper
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Reply indicator
            HStack(spacing: 4) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                Text("Replying to")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                Text("@\(post.authorHandle)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.mintAccent)
            }
            
            // Post preview
            HStack(alignment: .top, spacing: 12) {
                // Thread connector line
                VStack(spacing: 0) {
                    // Avatar
                    if let avatarURL = post.authorAvatarURL {
                        WebImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                    }
                    
                    // Thread line
                    Rectangle()
                        .fill(Color.mintInactive.opacity(0.5))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 40)
                
                // Post content
                VStack(alignment: .leading, spacing: 4) {
                    // Author info
                    HStack {
                        Text(post.authorDisplayName ?? post.authorHandle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text("@\(post.authorHandle)")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(post.createdAt.relativeFormatted)
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                    }
                    
                    // Post text
                    Text(post.text)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}