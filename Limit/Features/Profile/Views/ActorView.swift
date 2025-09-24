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
  @Environment(MultiAccountClient.self) private var client
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
  @Environment(MultiAccountClient.self) private var client
  @Environment(CurrentUser.self) private var currentUser
  @State private var selectedSection: ProfileSection = .posts
  @State private var interimFollowingURI: String?
  @State private var showAddToListSheet = false

  enum ProfileSection: String, CaseIterable {
    case posts = "Posts"
    case followers = "Followers"
    case following = "Following"
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
            ProfilePostsList(posts: actorWrapped.posts, isLoading: actorWrapped.isLoadingPosts)
          case .followers:
            FollowersSectionView(
              actorWrapper: actorWrapped,
              sectionType: .followers
            )
          case .following:
            FollowersSectionView(
              actorWrapper: actorWrapped,
              sectionType: .following
            )
          case .lists:
            ListsSectionView(lists: actorWrapped.lists, isLoading: actorWrapped.isLoadingLists)
          case .feeds:
            FeedsSectionView(feeds: actorWrapped.feedGenerators, isLoading: actorWrapped.isLoadingFeeds)
          }
        }
      }
    }
    .sheet(isPresented: $showAddToListSheet) {
      if let profile = actorWrapped.profile {
        AddToListSheet(
          actorDID: actorWrapped.actorDID,
          actorHandle: profile.actorHandle,
          actorDisplayName: profile.displayName,
          actorAvatarURL: profile.avatarImageURL
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
      }
    }
    .navigationTitle("Profil")
    .navigationBarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  var sectionPicker: some View {
    Picker("", selection: $selectedSection) {
      ForEach(ProfileSection.allCases, id: \.self) { section in
        Text(section.rawValue).tag(section)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
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
          VStack(spacing: 8) {
            Button {
              Task {
                if let uri = followingURI {
                  interimFollowingURI = "UNFOLLOWED"
                  await client.deleteFollowRecord(recordID: uri)
                } else {
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

            if !currentUser.lists.isEmpty {
              Button {
                showAddToListSheet = true
              } label: {
                HStack(spacing: 6) {
                  Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                  Text("Lists")
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                  RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
              }
            }
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

struct ProfilePostsList: View {
  let posts: [TimelinePostWrapper]
  let isLoading: Bool

  var body: some View {
    VStack(spacing: 0) {
      if isLoading && posts.isEmpty {
        loadingState
          .padding(.vertical, 24)
      } else {
        LazyVStack(spacing: 0) {
          ForEach(posts, id: \.id) { post in
            PostItemWrappedView(
              post: post,
              isThreadView: true,
              postViewType: .timeline,
              useListStyle: true
            )
            .id(post.id)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            if post.id != posts.last?.id {
              Divider()
                .padding(.leading, 72)
            }
          }
        }

        if isLoading {
          loadingState
            .padding(.vertical, 16)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .background(Color.warmBackground)
  }

  private var loadingState: some View {
    HStack(spacing: 8) {
      ProgressView()
        .scaleEffect(0.9)
      Text("Loading posts...")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
  }
}

struct FollowersSectionView: View {
  let actorWrapper: ActorWrapper
  let sectionType: SectionType
  @Environment(MultiAccountClient.self) private var client
  @State private var isLoadingMore = false
  @State private var hasMoreData = true
  @State private var lastFollowersCount = 0

  enum SectionType {
    case followers
    case following
  }

  private var followers: [AppBskyLexicon.Actor.ProfileViewDefinition] {
    switch sectionType {
    case .followers:
      return actorWrapper.followers
    case .following:
      return actorWrapper.followees
    }
  }

  private var isInitialLoading: Bool {
    switch sectionType {
    case .followers:
      return actorWrapper.isLoadingFollowers
    case .following:
      return actorWrapper.isLoadingFollowees
    }
  }

  var body: some View {
    LazyVStack(spacing: 12) {
      if isInitialLoading && followers.isEmpty {
        HStack {
          ProgressView()
            .scaleEffect(0.8)
          Text("Loading \(sectionType == .followers ? "followers" : "following")...")
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
    case .following:
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
  @Environment(MultiAccountClient.self) private var client
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
            .onTapGesture {
              router.navigateTo(.actor(userID: profile.actorDID))
            }
        }
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color.warmBackground)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.subtleGray.opacity(0.3), lineWidth: 0.5)
    )
    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
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
  @Environment(MultiAccountClient.self) private var client
  @Environment(CurrentUser.self) private var currentUser
  @State private var isSubscribed: Bool = false
  @State private var isUpdating: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      AvatarView(url: feed.avatarImageURL, size: 48)

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(feed.displayName)
              .font(.subheadline)
              .fontWeight(.medium)

            if let description = feed.description, !description.isEmpty {
              Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            }
          }
          
          Spacer()
          
          // Subscribe/Unsubscribe button
          Button(action: {
            Task {
              await toggleSubscription()
            }
          }) {
            if isUpdating {
              ProgressView()
                .scaleEffect(0.8)
                .frame(width: 80)
            } else {
              Text(isSubscribed ? "Subscribed" : "Subscribe")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSubscribed ? .secondary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSubscribed ? Color.gray.opacity(0.3) : Color.blue)
                .clipShape(Capsule())
            }
          }
          .disabled(isUpdating)
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
    .onAppear {
      checkSubscriptionStatus()
    }
  }
  
  private func checkSubscriptionStatus() {
    // Check if this feed is in currentUser's subscribed feeds
    isSubscribed = currentUser.feeds.contains { $0.feedURI == feed.feedURI }
  }
  
  private func toggleSubscription() async {
    isUpdating = true
    defer { isUpdating = false }
    
    let newStatus = !isSubscribed
    let success = await client.updateFeedInPreferences(
      feedURI: feed.feedURI, 
      subscribe: newStatus,
      isPinned: false
    )
    
    if success {
      isSubscribed = newStatus
      // Refresh currentUser feeds to reflect the change
      await currentUser.refreshFeeds(client: client)
      DevLogger.shared.log("FeedItemView - Successfully \(newStatus ? "subscribed to" : "unsubscribed from") feed: \(feed.displayName)")
    } else {
      DevLogger.shared.log("FeedItemView - Failed to update subscription for feed: \(feed.displayName)")
    }
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
