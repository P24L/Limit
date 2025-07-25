import ATProtoKit
//
//  Actor.swift
//  Limit
//
//  Created by Zdenek Indra on 21.06.2025.
//
import Foundation
import Observation

@Observable
class ActorWrapper {
  let client: BlueskyClient

  let actorDID: String

  private(set) var profile: AppBskyLexicon.Actor.ProfileViewDetailedDefinition?

  private(set) var followees: [AppBskyLexicon.Actor.ProfileViewDefinition] = []
  private var followeesLastCursor: String?
  private(set) var isLoadingFollowees: Bool = true

  private(set) var followers: [AppBskyLexicon.Actor.ProfileViewDefinition] = []
  private var followersLastCursor: String?
  private(set) var isLoadingFollowers: Bool = true

  private(set) var lists: [AppBskyLexicon.Graph.ListViewDefinition] = []
  private var listsLastCursor: String?
  private(set) var isLoadingLists: Bool = true

  private(set) var feedGenerators: [AppBskyLexicon.Feed.GeneratorViewDefinition] = []
  private var feedGeneratorsLastCursor: String?
  private(set) var isLoadingFeeds: Bool = true

  private(set) var posts: [TimelinePostWrapper] = []
  private var postsLastCursor: String?
  private(set) var isLoadingPosts: Bool = true

  private(set) var likedPosts: [TimelinePostWrapper] = []
  private var likedPostsLastCursor: String?
  private(set) var isLoadingLikes: Bool = true

  init(client: BlueskyClient, DID: String) {
    self.client = client
    self.actorDID = DID

    Task {
      await loadInitialData()
    }
  }

  func loadInitialData() async {
    guard let protoClient = await client.protoClient else { return }

    do {
      let profile = try await protoClient.getProfile(for: actorDID)
      DevLogger.shared.log("ActorWrapper - init - actorDID: \(actorDID)")
      DevLogger.shared.log(
        "ActorWrapper - init - followingURI: \(profile.viewer?.followingURI ?? "")")
      await MainActor.run {
        self.profile = profile
      }
    } catch {
      DevLogger.shared.log("ActorWrapper - getProfile se nepovedl")
    }

    _ = await loadFollowers()
    _ = await loadFollowees()
    _ = await getLists()
    _ = await getFeedGenerators()
    _ = await getPosts()
    _ = await getLikedPosts()
  }

  // Načtení followerů s podporou donahrávání pomocí cursoru
  func loadFollowers(limit: Int = 50) async -> Bool {
    guard let protoClient = await client.protoClient else { return false }

    await MainActor.run {
      self.isLoadingFollowers = true
    }

    // Pokud ještě nejsou načteni žádní followers, načteme první dávku
    if followers.count == 0 {
      do {
        let output = try await protoClient.getFollowers(
          by: actorDID,
          limit: limit,
          cursor: nil
        )

        // aktualizace cursoru pro případné další načítání
        if let newCursor = output.cursor, !newCursor.isEmpty {
          followersLastCursor = newCursor
        } else {
          followersLastCursor = nil
        }

        // přidání followerů na main thread
        await MainActor.run {
          for follower in output.followers {
            self.followers.append(follower)
          }
          self.isLoadingFollowers = false
        }

        // Vrátíme true, pokud jsou ještě další data k načtení
        return !output.followers.isEmpty && followersLastCursor != nil
      } catch {
        DevLogger.shared.log("ActorWrapper - loadFollowers failed")
        await MainActor.run {
          self.isLoadingFollowers = false
        }
        return false
      }
    }

    // Pokud už jsou nějací followers načteni, načteme další dávku
    guard let cursor = followersLastCursor else { return false }

    do {
      let output = try await protoClient.getFollowers(
        by: actorDID,
        limit: limit,
        cursor: cursor
      )

      // aktualizace cursoru pro případné další načítání
      if let newCursor = output.cursor, !newCursor.isEmpty {
        followersLastCursor = newCursor
      } else {
        followersLastCursor = nil
      }

      // přidání nových followerů na main thread
      await MainActor.run {
        for follower in output.followers {
          self.followers.append(follower)
        }
        self.isLoadingFollowers = false
      }

      // Vrátíme true, pokud jsou ještě další data k načtení
      return !output.followers.isEmpty && followersLastCursor != nil
    } catch {
      DevLogger.shared.log("ActorWrapper - loadMoreFollowers failed")
      await MainActor.run {
        self.isLoadingFollowers = false
      }
      return false
    }
  }

  // Načtení followees s podporou donahrávání pomocí cursoru
  func loadFollowees(limit: Int = 50) async -> Bool {
    guard let protoClient = await client.protoClient else { return false }

    await MainActor.run {
      self.isLoadingFollowees = true
    }

    // Pokud ještě nejsou načteni žádní followees, načteme první dávku
    if followees.count == 0 {
      do {
        let output = try await protoClient.getFollows(
          from: actorDID,
          limit: limit,
          cursor: nil
        )

        // aktualizace cursoru pro případné další načítání
        if let newCursor = output.cursor, !newCursor.isEmpty {
          followeesLastCursor = newCursor
        } else {
          followeesLastCursor = nil
        }

        // přidání followees na main thread
        await MainActor.run {
          for followee in output.follows {
            self.followees.append(followee)
          }
          self.isLoadingFollowees = false
        }

        // Vrátíme true, pokud jsou ještě další data k načtení
        return !output.follows.isEmpty && followeesLastCursor != nil
      } catch {
        DevLogger.shared.log("ActorWrapper - loadFollowees se nepovedl")
        await MainActor.run {
          self.isLoadingFollowees = false
        }
        return false
      }
    }

    // Pokud už jsou nějací followees načteni, načteme další dávku
    guard let cursor = followeesLastCursor else { return false }

    do {
      let output = try await protoClient.getFollows(
        from: actorDID,
        limit: limit,
        cursor: cursor
      )

      // aktualizace cursoru pro případné další načítání
      if let newCursor = output.cursor, !newCursor.isEmpty {
        followeesLastCursor = newCursor
      } else {
        followeesLastCursor = nil
      }

      // přidání nových followees na main thread
      await MainActor.run {
        for followee in output.follows {
          self.followees.append(followee)
        }
        self.isLoadingFollowees = false
      }

      // Vrátíme true, pokud jsou ještě další data k načtení
      return !output.follows.isEmpty && followeesLastCursor != nil
    } catch {
      DevLogger.shared.log("ActorWrapper - loadMoreFollowees se nepovedl")
      await MainActor.run {
        self.isLoadingFollowees = false
      }
      return false
    }
  }

  // Seznam jeho vlastních listů
  func getLists(limit: Int = 50) async -> [AppBskyLexicon.Graph.ListViewDefinition] {
    guard let protoClient = await client.protoClient else { return [] }

    await MainActor.run {
      self.isLoadingLists = true
    }

    if lists.count == 0 {
      do {
        let output = try await protoClient.getLists(
          from: actorDID,
          limit: limit,
          cursor: listsLastCursor
        )
        listsLastCursor = output.cursor
        await MainActor.run {
          for list in output.lists {
            self.lists.append(list)
          }
          self.isLoadingLists = false
        }
      } catch {
        DevLogger.shared.log("ActorWrapper - getLists se nepovedl")
        await MainActor.run {
          self.isLoadingLists = false
        }
      }
    } else {
      await MainActor.run {
        self.isLoadingLists = false
      }
    }
    return lists
  }

  // Seznam feed generatorů (pokud jsou veřejné)
  func getFeedGenerators(limit: Int = 50) async -> [AppBskyLexicon.Feed.GeneratorViewDefinition] {
    guard let protoClient = await client.protoClient else { return [] }

    await MainActor.run {
      self.isLoadingFeeds = true
    }

    if feedGenerators.count == 0 {
      do {
        let output = try await protoClient.getActorFeeds(
          by: actorDID,
          limit: limit,
          cursor: feedGeneratorsLastCursor
        )
        feedGeneratorsLastCursor = output.cursor
        await MainActor.run {
          for feedGenerator in output.feeds {
            self.feedGenerators.append(feedGenerator)
          }
          self.isLoadingFeeds = false
        }
      } catch {
        DevLogger.shared.log("ActorWrapper - getFeedGenerators se nepovedl")
        await MainActor.run {
          self.isLoadingFeeds = false
        }
      }
    } else {
      await MainActor.run {
        self.isLoadingFeeds = false
      }
    }
    return feedGenerators
  }

  // Jeho vlastní posty
  func getPosts(limit: Int = 50) async -> [TimelinePostWrapper] {
    guard let protoClient = await client.protoClient else { return [] }

    await MainActor.run {
      self.isLoadingPosts = true
    }

    if posts.count == 0 {
      do {
        let output = try await protoClient.getAuthorFeed(
          by: actorDID,
          limit: limit,
          cursor: postsLastCursor,
          shouldIncludePins: true
        )
        postsLastCursor = output.cursor
        await MainActor.run {
          for post in output.feed {
            if let postWrap = TimelinePostWrapper(from: post) {
              self.posts.append(postWrap)
            }
          }
          self.isLoadingPosts = false
        }
      } catch {
        DevLogger.shared.log("ActorWrapper - getPosts se nepovedl")
        await MainActor.run {
          self.isLoadingPosts = false
        }
      }
    } else {
      await MainActor.run {
        self.isLoadingPosts = false
      }
    }
    return posts
  }

  func getLikedPosts(limit: Int = 50) async -> [TimelinePostWrapper] {
    guard let protoClient = await client.protoClient else { return [] }

    await MainActor.run {
      self.isLoadingLikes = true
    }

    if likedPosts.count == 0 {
      do {
        let output = try await protoClient.getActorLikes(
          by: actorDID,
          limit: limit,
          cursor: likedPostsLastCursor
        )
        likedPostsLastCursor = output.cursor
        await MainActor.run {
          for post in output.feed {
            if let postWrap = TimelinePostWrapper(from: post) {
              self.likedPosts.append(postWrap)
            }
          }
          self.isLoadingLikes = false
        }
      } catch {
        DevLogger.shared.log("ActorWrapper - getLikedPosts failed")
        await MainActor.run {
          self.isLoadingLikes = false
        }
      }
    } else {
      await MainActor.run {
        self.isLoadingLikes = false
      }
    }
    return likedPosts
  }

  func refreshProfile() async {
    guard let protoClient = await client.protoClient else { return }

    do {
      let profile = try await protoClient.getProfile(for: actorDID)
      DevLogger.shared.log("ActorWrapper - refreshProfile - followingURI: \(profile.viewer?.followingURI ?? "")")
      await MainActor.run {
        self.profile = profile
      }
    } catch {
      DevLogger.shared.log("ActorWrapper - refreshProfile failed")
    }
  }

}
