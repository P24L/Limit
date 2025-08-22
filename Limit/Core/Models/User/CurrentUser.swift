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
    
    // Store pinned status and order for lists
    var listPreferences: [String: (isPinned: Bool, order: Int)] = [:] // URI -> (isPinned, order)
    
    // Store pinned status and order for feeds
    var feedPreferences: [String: (isPinned: Bool, order: Int)] = [:] // URI -> (isPinned, order)
    
    // Volá se po přihlášení nebo na refresh
    func refreshProfile(client: MultiAccountClient) async {
        guard let did = await client.currentDID else { return }
        guard let profile = await client.getProfile(for: did) else { return }
        
        await MainActor.run {
            self.did = did
            self.handle = profile.actorHandle
            self.displayName = profile.displayName ?? ""
            self.avatarURL = profile.avatarImageURL
        }
        DevLogger.shared.log("CurrentUser - refreshProfile - did: \(self.did)")
        
        // Defer lists and feeds refresh to background
        Task.detached { [weak self] in
            await self?.refreshLists(client: client)
            await self?.refreshFeeds(client: client)
        }
    }
    
    func clear() {
        did = ""
        handle = ""
        displayName = ""
        avatarURL = nil
        lists = []
        feeds = []
        listPreferences = [:]
        feedPreferences = [:]
        DevLogger.shared.log("CurrentUser - clear - clear!")
    }
    
    // Načte seznam vlastních lists
    func refreshLists(client: MultiAccountClient, limit: Int = 50) async {
        guard !did.isEmpty else { 
            DevLogger.shared.log("CurrentUser - refreshLists - did empty")
            return 
        }
        DevLogger.shared.log("CurrentUser - refreshLists - starting")
        
        let output = await client.getUserLists(for: did, limit: limit, cursor: listsLastCursor)
        
        guard let listsOutput = output else {
            DevLogger.shared.log("CurrentUser - refreshLists unsucessfull")
            return
        }
        
        listsLastCursor = listsOutput.cursor
        DevLogger.shared.log("CurrentUser - refreshLists - old count: \(lists.count),new count:\(listsOutput.lists.count)")
        
        // Get preferences to fetch pinned status and order
        await refreshListPreferences(client: client)
        
        // Sort lists based on preferences
        let sortedLists = sortListsByPreferences(listsOutput.lists)
        
        await MainActor.run {
            self.lists = sortedLists
        }
    }
    
    // Refresh list preferences from server
    private func refreshListPreferences(client: MultiAccountClient) async {
        guard let preferencesOutput = await client.getPreferences() else {
            DevLogger.shared.log("CurrentUser - refreshListPreferences - Failed to get preferences")
            return
        }
        
        var newListPreferences: [String: (isPinned: Bool, order: Int)] = [:]
        
        for preference in preferencesOutput.preferences {
            if case .savedFeedsVersion2(let savedFeeds) = preference {
                // Get only lists from saved feeds
                let listItems = savedFeeds.items.filter { $0.feedType == .list }
                
                // Store preferences with order based on array position
                for (index, item) in listItems.enumerated() {
                    newListPreferences[item.value] = (isPinned: item.isPinned, order: index)
                }
                break
            }
        }
        
        let count = newListPreferences.count
        let finalListPreferences = newListPreferences
        await MainActor.run {
            self.listPreferences = finalListPreferences
        }
        
        DevLogger.shared.log("CurrentUser - refreshListPreferences - Updated \(count) list preferences")
    }
    
    // Sort lists based on preferences (pinned first, then by order)
    private func sortListsByPreferences(_ lists: [AppBskyLexicon.Graph.ListViewDefinition]) -> [AppBskyLexicon.Graph.ListViewDefinition] {
        return lists.sorted { list1, list2 in
            let pref1 = listPreferences[list1.uri]
            let pref2 = listPreferences[list2.uri]
            
            // If both have preferences
            if let p1 = pref1, let p2 = pref2 {
                // Pinned items come first
                if p1.isPinned != p2.isPinned {
                    return p1.isPinned
                }
                // Then sort by order
                return p1.order < p2.order
            }
            
            // If only one has preferences, it comes first
            if pref1 != nil { return true }
            if pref2 != nil { return false }
            
            // If neither has preferences, maintain original order
            return lists.firstIndex(where: { $0.uri == list1.uri }) ?? 0 < lists.firstIndex(where: { $0.uri == list2.uri }) ?? 0
        }
    }
    
    // Toggle pin status for a list
    func toggleListPin(listURI: String, client: MultiAccountClient) async -> Bool {
        let currentPinStatus = listPreferences[listURI]?.isPinned ?? false
        let newPinStatus = !currentPinStatus
        
        let success = await client.updateListInPreferences(listURI: listURI, isPinned: newPinStatus)
        
        if success {
            // Update local state immediately
            await MainActor.run {
                if var pref = listPreferences[listURI] {
                    pref.isPinned = newPinStatus
                    listPreferences[listURI] = pref
                } else {
                    // If not in preferences yet, add it with the last order
                    let maxOrder = listPreferences.values.map { $0.order }.max() ?? -1
                    listPreferences[listURI] = (isPinned: newPinStatus, order: maxOrder + 1)
                }
                
                // Re-sort lists
                lists = sortListsByPreferences(lists)
            }
            
            DevLogger.shared.log("CurrentUser - toggleListPin - Updated pin status for \(listURI) to \(newPinStatus)")
        }
        
        return success
    }
    
    // Update list order after drag-to-reorder
    func updateListOrder(client: MultiAccountClient) async -> Bool {
        // Get current list URIs in their display order
        let listURIs = lists.map { $0.uri }
        
        // Update preferences with new order
        let success = await client.reorderListsInPreferences(listURIs: listURIs)
        
        if success {
            // Update local preferences with new order
            await MainActor.run {
                for (index, uri) in listURIs.enumerated() {
                    if var pref = listPreferences[uri] {
                        pref.order = index
                        listPreferences[uri] = pref
                    } else {
                        listPreferences[uri] = (isPinned: false, order: index)
                    }
                }
            }
            
            DevLogger.shared.log("CurrentUser - updateListOrder - Updated order for \(listURIs.count) lists")
        }
        
        return success
    }

    func refreshFeeds(client: MultiAccountClient, limit: Int = 50) async {
        guard let protoClient = await client.protoClient else { return }
        do {
            var customFeedURIs: [String] = []
            var timelineFeedURIs: [String] = []
            var newFeedPreferences: [String: (isPinned: Bool, order: Int)] = [:]
            
            let userPreferences = try await protoClient.getPreferences()
            for pref in userPreferences.preferences {
                switch pref {
                case .savedFeedsVersion2(let savedV2):
                    // Get ALL feeds including timeline (Following)
                    let allFeedItems = savedV2.items.filter { 
                        $0.feedType == .feed || $0.feedType == .timeline 
                    }
                    
                    // Separate timeline feeds from custom feeds
                    let customFeedItems = allFeedItems.filter { $0.feedType == .feed }
                    let timelineItems = allFeedItems.filter { $0.feedType == .timeline }
                    
                    // Store preferences with order based on array position
                    for (index, item) in allFeedItems.enumerated() {
                        newFeedPreferences[item.value] = (isPinned: item.isPinned, order: index)
                    }
                    
                    // Collect URIs separately
                    customFeedURIs = customFeedItems.map { $0.value }
                    timelineFeedURIs = timelineItems.map { $0.value }
                    
                    DevLogger.shared.log("CurrentUser - refreshFeeds - Found \(customFeedURIs.count) custom feeds and \(timelineFeedURIs.count) timeline feeds")
                default:
                    break
                }
            }
            
            // Update feed preferences
            let finalFeedPreferences = newFeedPreferences
            await MainActor.run {
                self.feedPreferences = finalFeedPreferences
            }
            
            var allFeeds: [AppBskyLexicon.Feed.GeneratorViewDefinition] = []
            
            // Fetch custom feed generators (skip timeline feeds as they don't have generators)
            if !customFeedURIs.isEmpty {
                let feedGenerators = try await protoClient.getFeedGenerators(by: customFeedURIs)
                allFeeds = feedGenerators.feeds
                DevLogger.shared.log("CurrentUser - refreshFeeds - Fetched \(feedGenerators.feeds.count) custom feed generators")
            }
            
            // Note: Timeline feeds like "Following" are built-in and don't have generators
            // They are handled internally by the AT Protocol
            // We just store their preferences but don't fetch generator data
            
            if !timelineFeedURIs.isEmpty {
                DevLogger.shared.log("CurrentUser - refreshFeeds - Timeline feeds (like Following) noted: \(timelineFeedURIs)")
            }
            
            // Sort feeds based on preferences (pinned first, then by order)
            let sortedFeeds = sortFeedsByPreferences(allFeeds)
            
            await MainActor.run {
                self.feeds = sortedFeeds
            }
            
            let pinnedCount = newFeedPreferences.filter { $0.value.isPinned }.count
            DevLogger.shared.log("CurrentUser - refreshFeeds - Total feeds: \(feeds.count), pinned: \(pinnedCount)")

        } catch {
            DevLogger.shared.log("CurrentUser - refreshFeeds error: \(error)")
        }
    }
    
    // Sort feeds based on preferences (pinned first, then by order)
    private func sortFeedsByPreferences(_ feeds: [AppBskyLexicon.Feed.GeneratorViewDefinition]) -> [AppBskyLexicon.Feed.GeneratorViewDefinition] {
        return feeds.sorted(by: { feed1, feed2 in
            let pref1 = feedPreferences[feed1.feedURI]
            let pref2 = feedPreferences[feed2.feedURI]
            
            // If both have preferences
            if let p1 = pref1, let p2 = pref2 {
                // Pinned items come first
                if p1.isPinned != p2.isPinned {
                    return p1.isPinned
                }
                // Then sort by order
                return p1.order < p2.order
            }
            
            // If only one has preferences, it comes first
            if pref1 != nil { return true }
            if pref2 != nil { return false }
            
            // If neither has preferences, maintain original order
            return feeds.firstIndex(where: { $0.feedURI == feed1.feedURI }) ?? 0 < feeds.firstIndex(where: { $0.feedURI == feed2.feedURI }) ?? 0
        })
    }
    
    // Toggle pin status for a feed
    func toggleFeedPin(feedURI: String, client: MultiAccountClient) async -> Bool {
        let currentPinStatus = feedPreferences[feedURI]?.isPinned ?? false
        let newPinStatus = !currentPinStatus
        
        let success = await client.updateFeedInPreferences(feedURI: feedURI, subscribe: true, isPinned: newPinStatus)
        
        if success {
            // Update local state immediately
            await MainActor.run {
                if var pref = feedPreferences[feedURI] {
                    pref.isPinned = newPinStatus
                    feedPreferences[feedURI] = pref
                } else {
                    // If not in preferences yet, add it with the last order
                    let maxOrder = feedPreferences.values.map { $0.order }.max() ?? -1
                    feedPreferences[feedURI] = (isPinned: newPinStatus, order: maxOrder + 1)
                }
                
                // Re-sort feeds
                feeds = sortFeedsByPreferences(feeds)
            }
            
            DevLogger.shared.log("CurrentUser - toggleFeedPin - Updated pin status for \(feedURI) to \(newPinStatus)")
        }
        
        return success
    }
    
    // Update feed order after drag-to-reorder
    func updateFeedOrder(client: MultiAccountClient) async -> Bool {
        // Get current feed URIs in their display order
        let feedURIs = feeds.map { $0.feedURI }
        
        // Update preferences with new order
        let success = await client.reorderFeedsInPreferences(feedURIs: feedURIs)
        
        if success {
            // Update local preferences with new order
            await MainActor.run {
                for (index, uri) in feedURIs.enumerated() {
                    if var pref = feedPreferences[uri] {
                        pref.order = index
                        feedPreferences[uri] = pref
                    } else {
                        feedPreferences[uri] = (isPinned: false, order: index)
                    }
                }
            }
            
            DevLogger.shared.log("CurrentUser - updateFeedOrder - Updated order for \(feedURIs.count) feeds")
        }
        
        return success
    }
    
    func clearLists() {
        lists = []
        listsLastCursor = nil
        listPreferences = [:]
    }
    
    func clearFeeds() {
        feeds = []
        feedPreferences = [:]
    }
}

