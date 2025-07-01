//
//  PostItemActionsView.swift
//  Limit
//
//  Created by Zdenek Indra on 07.06.2025.
//

import AppRouter
import SwiftData
import SwiftUI

struct PostItemActionsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) var context
    @Environment(FavoriteURLManager.self) private var favoritesURL
    @Environment(FavoritePostManager.self) private var favoritesPost
    
    var postWrapper: TimelinePostWrapper
    
    let hideMoreActions = false
    
    @Environment(BlueskyClient.self) private var client
    var body: some View {
        HStack(alignment:.firstTextBaseline, spacing: 16) {
            
            
            Button {
                
            } label: {
                Label("\(postWrapper.replyCount.abbreviated)", systemImage: "quote.bubble")
                    .lineLimit(1)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.postAction)
            .monospacedDigit()
            
            Button {
                
            } label: {
                Label("\(postWrapper.repostCount.abbreviated)", systemImage: "arrow.2.squarepath")
                    .lineLimit(1)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.postAction)
            .monospacedDigit()
            
            /* In Bluesky, "Quote post" is a post that contains another post as a quote, similar to "Quote Tweet" on Twitter. The user creates a new post that contains an embedded other post (as referenced content), often supplemented with their own comment.
            Button {
                
            } label: {
                Label("\(postWrapper.post.quoteCount)", systemImage: "arrow.triangle.2.circlepath")
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blueGray)
            .monospacedDigit() */
            
            Button {
                Task {
                    await postWrapper.toggleLike(using: client)
                }
            } label: {
                Label("\(postWrapper.likeCount.abbreviated)", systemImage: postWrapper.isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(postWrapper.isLiked ? .red : .primary)
                    .lineLimit(1)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.postAction)
            .monospacedDigit()
            
            Button {
                Task {
                    if favoritesPost.isFavorited(postWrapper.uri) {
                        await favoritesPost.removeFavorite(postID: postWrapper.uri)
                    } else {
                        await favoritesPost.addFavorite(postID: postWrapper.uri)
                    }
                }
            } label: {
                Image(systemName: "bookmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .symbolVariant(favoritesPost.isFavorited(postWrapper.uri) ? .fill : .none)
            .symbolEffect(.bounce, value: favoritesPost.isFavorited(postWrapper.uri))
            .foregroundStyle(favoritesPost.isFavorited(postWrapper.uri) ? .mintAccent : .postAction)
            .monospacedDigit()
            
            if let linkExt = postWrapper.linkExt,
               let url = URL(string: linkExt.uri) {
                Button {
                    Task {
                        if favoritesURL.isFavorited(url) {
                            await favoritesURL.removeFavorite(url: url)
                        } else {
                            await favoritesURL.addFavorite(url: url, title: linkExt.title, thumbnailImageURL: linkExt.thumbnailImageURL)
                        }
                    }
                } label: {
                    Image(systemName: "safari")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .symbolVariant(favoritesURL.isFavorited(url) ? .fill : .none)
                .symbolEffect(.bounce, value: favoritesURL.isFavorited(url))
                .foregroundStyle(favoritesURL.isFavorited(url) ? .mintAccent : .postAction)
            }

            
            Spacer()
            
            if !hideMoreActions {
                Button {
                    
                } label: {
                    Image(systemName: "ellipsis")
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.postAction)
                }

            }
        }
        .buttonStyle(.plain)
        .font(.caption)
        .padding(.top, 3)
        .padding(.bottom, 3)
        .controlSize(.regular)
        
    }
}
/*
#Preview {
    PostItemActionsView(postWrapper: SampleData.shared.makeOneSamplePostWrapper())
        .environment(AppRouter(initialTab: .timeline))
        .modelContainer(SampleData.shared.modelContainer)
}
*/
