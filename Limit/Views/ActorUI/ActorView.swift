//
//  ActorView.swift
//  Limit
//
//  Created by Zdenek Indra on 08.06.2025.
//

import ATProtoKit
import AppRouter
import Foundation
import SDWebImageSwiftUI
import SwiftData
import SwiftUI

@MainActor
struct ActorView: View {
  @Environment(BlueskyClient.self) private var client
  @Environment(\.modelContext) var context

  var actorDID: String
  @State private var actor: ActorWrapper?

  var body: some View {
    ZStack {
      if let actor {
        UserProfileView(actorWrapped: actor)
          .id(actor.actorDID)
      } else {
        ProgressView()
      }
    }
    .task {
      actor = ActorWrapper(client: client, DID: actorDID)
    }
  }
}

struct UserProfileView: View {
  var actorWrapped: ActorWrapper
  @Environment(BlueskyClient.self) private var client
  @State private var selectedSection: ProfileSection = .posts
  @State private var interimFollowingURI: String?

  enum ProfileSection: String, CaseIterable {
    case posts = "Posts"
    case likes = "Likes"
    case followers = "Followers"
    case followees = "Followees"
    case lists = "Lists"
    case feeds = "Feeds"
  }

  private var followingURI: String? {
    if interimFollowingURI == "UNFOLLOWED" {
      return nil
    }
    return interimFollowingURI ?? actorWrapped.profile?.viewer?.followingURI
  }

  var body: some View {
    ScrollView {
      LazyVStack(pinnedViews: [.sectionHeaders]) {
        // Profilová hlavička (není sticky)
        profileHeaderView

        // Sticky sekce pickeru a obsah sekce
        Section(header: sectionPicker) {
          Divider()

          switch selectedSection {
          case .posts:
            PostsSectionView(posts: actorWrapped.posts, isLoading: actorWrapped.isLoadingPosts)
          case .likes:
            PostsSectionView(posts: actorWrapped.likedPosts, isLoading: actorWrapped.isLoadingLikes)
          case .followers:
            FollowersSectionView(
              actorWrapper: actorWrapped,
              sectionType: .followers
            )
          case .followees:
            FollowersSectionView(
              actorWrapper: actorWrapped,
              sectionType: .followees
            )
          case .lists:
            ListsSectionView(lists: actorWrapped.lists, isLoading: actorWrapped.isLoadingLists)
          case .feeds:
            FeedsSectionView(feeds: actorWrapped.feedGenerators, isLoading: actorWrapped.isLoadingFeeds)
          }
        }
      }
    }
    .navigationTitle("Profil")
    .navigationBarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  var sectionPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 20) {
        ForEach(ProfileSection.allCases, id: \.self) { section in
          Button(action: {
            selectedSection = section
          }) {
            Text(section.rawValue)
              .font(.subheadline)
              .fontWeight(selectedSection == section ? .semibold : .regular)
              .foregroundColor(selectedSection == section ? .primary : .secondary)
              .padding(.vertical, 12)
              .padding(.horizontal, 12)
              .background(
                selectedSection == section
                  ? Color.mintAccent.opacity(0.1) : Color.clear
              )
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
      .background(.background)
    }
  }

  @ViewBuilder
  private var profileHeaderView: some View {
    VStack(spacing: 16) {
      if let bannerURL = actorWrapped.profile?.bannerImageURL {
        WebImage(url: bannerURL) { phase in
          switch phase {
          case .empty:
            Color.gray.opacity(0.1)
          case .success(let image):
            image.resizable()
          case .failure:
            Color.gray.opacity(0.1)
          }
        }
        .frame(height: 160)
        .clipped()
      }

      HStack(spacing: 16) {
        AvatarView(url: actorWrapped.profile?.avatarImageURL, size: 64)

        VStack(alignment: .leading) {
          if let name = actorWrapped.profile?.displayName {
            Text(name).font(.title2).bold()
          }
          if let handle = actorWrapped.profile?.actorHandle {
            Text("@\(handle)").foregroundColor(.secondary)
          }
        }

        Spacer()

        if let did = actorWrapped.actorDID as String? {
          Button {
            Task {
              if let uri = followingURI {
                // UNFOLLOW: Set interim state, no refresh wait needed
                interimFollowingURI = "UNFOLLOWED"
                await client.deleteFollowRecord(recordID: uri)
              } else {
                // FOLLOW: Set interim state, then refresh to get real URI
                let tempURI = "temp_follow_uri"
                interimFollowingURI = tempURI
                _ = await client.followActor(actor: did)
                await actorWrapped.refreshProfile()
                interimFollowingURI = nil
              }
            }
          } label: {
            Text(followingURI == nil ? "Follow" : "Unfollow")
              .font(.subheadline)
              .fontWeight(.medium)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(
                followingURI == nil ? Color.mintAccent : Color.mintInactive
              )
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 20))
              .overlay(
                RoundedRectangle(cornerRadius: 20)
                  .stroke(
                    followingURI == nil
                      ? Color.mintInactive : Color.mintAccent,
                    lineWidth: 1)
              )
          }
        }
      }
      .padding(.horizontal)

      if let bio = actorWrapped.profile?.description {
        Text(bio)
          .padding(.horizontal)
          .font(.body)
          .multilineTextAlignment(.leading)
      }

      HStack(spacing: 24) {
        if let followers = actorWrapped.profile?.followerCount {
          Label("\(followers)", systemImage: "person.2.fill")
        }
        if let follows = actorWrapped.profile?.followCount {
          Label("\(follows)", systemImage: "person.fill.checkmark")
        }
        if let posts = actorWrapped.profile?.postCount {
          Label("\(posts)", systemImage: "text.bubble.fill")
        }
      }
      .padding(.horizontal)
      .font(.subheadline)
      .foregroundColor(.secondary)
    }
  }
}

// MARK: - Section Views

struct PostsSectionView: View {
  let posts: [TimelinePostWrapper]
  let isLoading: Bool

  var body: some View {
    LazyVStack(spacing: 8) {
      if isLoading && posts.isEmpty {
        HStack {
          ProgressView()
            .scaleEffect(0.8)
          Text("Loading posts...")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
      } else {
        ForEach(posts, id: \.id) { post in
          PostItemWrappedView(post: post, isThreadView: true, postViewType: .timeline, showCard: true)
            .id(post.id)
        }
      }
    }
    .padding(.horizontal, 10)
    .background(.warmBackground)
  }
}

struct FollowersSectionView: View {
  let actorWrapper: ActorWrapper
  let sectionType: SectionType
  @Environment(BlueskyClient.self) private var client
  @State private var isLoadingMore = false
  @State private var hasMoreData = true
  @State private var lastFollowersCount = 0

  enum SectionType {
    case followers
    case followees
  }

  private var followers: [AppBskyLexicon.Actor.ProfileViewDefinition] {
    switch sectionType {
    case .followers:
      return actorWrapper.followers
    case .followees:
      return actorWrapper.followees
    }
  }

  private var isInitialLoading: Bool {
    switch sectionType {
    case .followers:
      return actorWrapper.isLoadingFollowers
    case .followees:
      return actorWrapper.isLoadingFollowees
    }
  }

  var body: some View {
    LazyVStack(spacing: 12) {
      if isInitialLoading && followers.isEmpty {
        HStack {
          ProgressView()
            .scaleEffect(0.8)
          Text("Loading \(sectionType == .followers ? "followers" : "followees")...")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
      } else {
        ForEach(Array(followers.enumerated()), id: \.element.actorDID) { index, follower in
          FollowerItemView(
            profile: follower,
            followingURI: follower.viewer?.followingURI
          )
          .onAppear {
            // Detekce konce seznamu pro načtení dalších položek
            // Načítáme další data, když se zobrazí předposlední item
            if index >= followers.count - 2 && !isLoadingMore && hasMoreData
              && followers.count > lastFollowersCount
            {
              lastFollowersCount = followers.count
              Task {
                await loadMoreData()
              }
            }
          }
        }

        // Loading indicator na konci
        if isLoadingMore {
          HStack {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading more...")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding()
        }
      }
    }
    .padding(.horizontal)
  }

  @MainActor
  private func loadMoreData() async {
    guard !isLoadingMore && hasMoreData else { return }

    isLoadingMore = true

    let success: Bool
    switch sectionType {
    case .followers:
      success = await actorWrapper.loadFollowers()
    case .followees:
      success = await actorWrapper.loadFollowees()
    }

    // Pokud se nepodařilo načíst další data, znamená to, že už nejsou žádná další
    if !success {
      hasMoreData = false
    } else {
      // Resetujeme lastFollowersCount pro další kolo načítání
      lastFollowersCount = 0
    }

    isLoadingMore = false
  }
}

struct FollowerItemView: View {
  let profile: AppBskyLexicon.Actor.ProfileViewDefinition
  @State var followingURI: String?
  @Environment(BlueskyClient.self) private var client
  @Environment(AppRouter.self) private var router

  var body: some View {
    HStack(spacing: 12) {
      AvatarView(url: profile.avatarImageURL, size: 48)
        .onTapGesture {
          router.navigateTo(.actor(userID: profile.actorDID))
        }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            if let name = profile.displayName {
              Text(name).font(.subheadline).fontWeight(.medium)
            }
            Text("@\(profile.actorHandle)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .onTapGesture {
            router.navigateTo(.actor(userID: profile.actorDID))
          }
          Spacer()
          Button {
            Task {
              if let uri = followingURI {
                // UNFOLLOW
                await client.deleteFollowRecord(recordID: uri)
                followingURI = nil
              } else {
                // FOLLOW
                let ref = await client.followActor(actor: profile.actorDID)
                followingURI = ref?.recordURI
              }
            }
          } label: {
            Text(followingURI == nil ? "Follow" : "Unfollow")
              .font(.caption)
              .fontWeight(.medium)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(followingURI == nil ? Color.mintAccent : Color.mintInactive)
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 16))
          }
        }

        if let description = profile.description, !description.isEmpty {
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color.gray.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct ListsSectionView: View {
  let lists: [AppBskyLexicon.Graph.ListViewDefinition]
  let isLoading: Bool

  var body: some View {
    LazyVStack(spacing: 12) {
      if isLoading && lists.isEmpty {
        HStack {
          ProgressView()
            .scaleEffect(0.8)
          Text("Loading lists...")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
      } else {
        ForEach(lists, id: \.uri) { list in
          ListItemView(list: list)
        }
      }
    }
    .padding(.horizontal)
  }
}

struct ListItemView: View {
  let list: AppBskyLexicon.Graph.ListViewDefinition

  var body: some View {
    HStack(spacing: 12) {
      AvatarView(url: list.avatarImageURL, size: 48)

      VStack(alignment: .leading, spacing: 4) {
        Text(list.name)
          .font(.subheadline)
          .fontWeight(.medium)

        if let description = list.description, !description.isEmpty {
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }

        HStack {
          Text("by \(list.creator.displayName ?? list.creator.actorHandle)")
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          if let itemCount = list.listItemCount {
            Text("\(itemCount) items")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color.gray.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct FeedsSectionView: View {
  let feeds: [AppBskyLexicon.Feed.GeneratorViewDefinition]
  let isLoading: Bool

  var body: some View {
    LazyVStack(spacing: 12) {
      if isLoading && feeds.isEmpty {
        HStack {
          ProgressView()
            .scaleEffect(0.8)
          Text("Loading feeds...")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
      } else {
        ForEach(feeds, id: \.cid) { feed in
          FeedItemView(feed: feed)
        }
      }
    }
    .padding(.horizontal)
  }
}

struct FeedItemView: View {
  let feed: AppBskyLexicon.Feed.GeneratorViewDefinition

  var body: some View {
    HStack(spacing: 12) {
      AvatarView(url: feed.avatarImageURL, size: 48)

      VStack(alignment: .leading, spacing: 4) {
        Text(feed.displayName)
          .font(.subheadline)
          .fontWeight(.medium)

        if let description = feed.description, !description.isEmpty {
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }

        HStack {
          Text("by \(feed.creator.displayName ?? feed.creator.actorHandle)")
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          if let likeCount = feed.likeCount {
            Text("\(likeCount) likes")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color.gray.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct AvatarView: View {
  let url: URL?
  let size: CGFloat

  var body: some View {
    if let avatarURL = url {
      WebImage(url: avatarURL) { phase in
        switch phase {
        case .empty:
          Rectangle().foregroundStyle(.gray)
        case .success(let image):
          image.resizable()
        case .failure(_):
          Rectangle().foregroundStyle(.gray)
        }
      }
      .scaledToFit()
      .frame(width: size, height: size)
      .clipShape(Circle())
    } else {  //when I don't have avatarURL
      Color.gray.frame(width: size, height: size)
        .clipShape(Circle())
    }
  }
}
