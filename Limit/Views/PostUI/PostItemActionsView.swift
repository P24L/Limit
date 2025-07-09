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
                    .font(.callout)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.postAction)
            .monospacedDigit()
            
            Button {
                
            } label: {
                Label("\(postWrapper.repostCount.abbreviated)", systemImage: "arrow.2.squarepath")
                    .lineLimit(1)
                    .font(.callout)
                    .imageScale(.medium)
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
                    .font(.callout)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.postAction)
            .monospacedDigit()
            
            Spacer()
            
            // Right group with smaller spacing
            HStack(spacing: 12) {
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
                        .font(.callout)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .symbolVariant(favoritesPost.isFavorited(postWrapper.uri) ? .fill : .none)
                .symbolEffect(.bounce, value: favoritesPost.isFavorited(postWrapper.uri))
                .foregroundStyle(favoritesPost.isFavorited(postWrapper.uri) ? .mintAccent : .postAction)
                .monospacedDigit()
                
                Button {
                    router.presentedSheet = .aiExplanation(postWrapper: postWrapper)
                } label: {
                    Image(systemName: "brain")
                        .font(.callout)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.postAction)
                
                if !hideMoreActions {
                    Button {
                        // Navigate to thread view
                        //if let postWrapper = postWrapper {
                        router.navigateTo(.postThreadWrapped(postThread: postWrapper))
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.callout)
                            .imageScale(.medium)
                            .foregroundStyle(.postAction)
                    }
                    .buttonStyle(.plain)
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
