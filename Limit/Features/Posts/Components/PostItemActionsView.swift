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
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(FavoritePostManager.self) private var favoritesPost
    
    var postWrapper: TimelinePostWrapper
    
    let hideMoreActions = false
    
    @Environment(MultiAccountClient.self) private var client
    
    private var isOwnPost: Bool {
        postWrapper.authorHandle == client.handle || postWrapper.authorID == client.currentDID
    }
    
    private var isRepostedByMe: Bool {
        postWrapper.repostedByHandle == client.handle || postWrapper.repostedByID == client.currentDID
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            
            
            Button {
                router.presentedSheet = .composePost(replyTo: postWrapper)
            } label: {
                Label("\(postWrapper.replyCount.abbreviatedRounded)", systemImage: "quote.bubble")
                    .lineLimit(1)
                    .font(.callout)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.postAction)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .monospacedDigit()
            
            Button {
                router.presentedSheet = .repostOptions(post: postWrapper)
            } label: {
                if isRepostedByMe {
                    Label("Reposted", systemImage: "arrow.2.squarepath")
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .font(.callout)
                        .imageScale(.medium)
                } else {
                    Label("\(postWrapper.repostCount.abbreviatedRounded)", systemImage: postWrapper.isReposted ? "arrow.2.squarepath" : "arrow.2.squarepath")
                        .foregroundStyle(postWrapper.isReposted ? .mintAccent : .postAction)
                        .lineLimit(1)
                        .font(.callout)
                        .imageScale(.medium)
                }
            }
            .buttonStyle(.plain)
            .symbolVariant(postWrapper.isReposted || isRepostedByMe ? .fill : .none)
            .symbolEffect(.bounce, value: postWrapper.isReposted || isRepostedByMe)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .monospacedDigit()
            
            Button {
                Task {
                    await postWrapper.toggleLike(using: client)
                }
            } label: {
                Label("\(postWrapper.likeCount.abbreviatedRounded)", systemImage: postWrapper.isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(postWrapper.isLiked ? .red : .primary)
                    .lineLimit(1)
                    .font(.callout)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.postAction)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .monospacedDigit()
            
            Spacer()
            
            // Right group with a bit more spacing and trailing padding
            HStack(spacing: 16) {
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
                        .font(.body)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .symbolVariant(favoritesPost.isFavorited(postWrapper.uri) ? .fill : .none)
                .symbolEffect(.bounce, value: favoritesPost.isFavorited(postWrapper.uri))
                .foregroundStyle(favoritesPost.isFavorited(postWrapper.uri) ? .mintAccent : .postAction)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .monospacedDigit()
                
                Button {
                    router.presentedSheet = .aiExplanation(type: .singlePost(postWrapper))
                } label: {
                    Image(systemName: "sparkles")
                        .font(.body)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.postAction)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                
                if !hideMoreActions {
                    Button {
                        router.presentedSheet = .moreOptions(post: postWrapper)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .imageScale(.large)
                            .foregroundStyle(.postAction)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
            }
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .font(.caption)
        .padding(.vertical, 4)
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
