//
//  CurrentUser.swift
//  Limit
//
//  Created by Zdenek Indra on 23.06.2025.
//

import Foundation
import Observation
import ATProtoKit

@Observable
class CurrentUser {
    var did: String = ""
    var handle: String = ""
    var displayName: String = ""
    var avatarURL: URL? = nil
    var lists: [AppBskyLexicon.Graph.ListViewDefinition] = []
    var feeds: [AppBskyLexicon.Feed.GeneratorViewDefinition] = []
    private var listsLastCursor: String? = nil
    
    // Volá se po přihlášení nebo na refresh
    func refreshProfile(client: BlueskyClient) async {
        guard let did = await client.currentDID else { return }
        guard let profile = await client.getProfile(for: did) else { return }
        
        await MainActor.run {
            self.did = did
            self.handle = profile.actorHandle
            self.displayName = profile.displayName ?? ""
            self.avatarURL = profile.avatarImageURL
        }
        DevLogger.shared.log("CurrentUser - refreshProfile - did: \(self.did)")
        await refreshLists(client: client)
        await refreshFeeds(client: client)

    }
    
    func clear() {
        did = ""
        handle = ""
        displayName = ""
        avatarURL = nil
        DevLogger.shared.log("CurrentUser - clear - clear!")
    }
    
    // Načte seznam vlastních lists
    func refreshLists(client: BlueskyClient, limit: Int = 50) async {
        guard let protoClient = await client.protoClient else {
            DevLogger.shared.log("CurrentUser - refreshLists - protoClient empty")
            return 
        }
        guard !did.isEmpty else { 
            DevLogger.shared.log("CurrentUser - refreshLists - did empty")
            return 
        }
        DevLogger.shared.log("CurrentUser - refreshLists - starting")
        do {
            let output = try await protoClient.getLists(
                from: did,
                limit: limit,
                cursor: listsLastCursor
            )
            listsLastCursor = output.cursor
            DevLogger.shared.log("CurrentUser - refreshLists - old count: \(lists.count),new count:\(output.lists.count)")
            await MainActor.run {
                self.lists = output.lists
            }
        } catch {
            DevLogger.shared.log("CurrentUser - refreshLists unsucessfull")
        }
    }

    func refreshFeeds(client: BlueskyClient, limit: Int = 50) async {
        guard let protoClient = await client.protoClient else { return }
        do {
            var feed_uris: [String] = []
            let userPreferences = try await protoClient.getPreferences()
            for pref in userPreferences.preferences {
                switch pref {
                case .savedFeedsVersion2(let savedV2):
                    for item in savedV2.items {
                        if item.feedType == .feed && item.isPinned {
                            feed_uris.append(item.value)
                        }
                    }
                default:
                    break
                }
            }
            if !feed_uris.isEmpty {
                let feedGenerators = try await protoClient.getFeedGenerators(by: feed_uris)
                feeds = feedGenerators.feeds
                DevLogger.shared.log("CurrentUser - refreshFeeds - add feeds, count: \(feeds.count)")
            }

        } catch {
            DevLogger.shared.log("CurrentUser - refreshFeeds unsucessfull")
        }
    }
    
    func clearLists() {
        lists = []
        listsLastCursor = nil
    }
}

