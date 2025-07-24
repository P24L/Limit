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
    var bookmarkLists: [BookmarkListView] = []
    private var listsLastCursor: String? = nil
    private var bookmarkListsLastCursor: String? = nil
    
    // Store pinned status and order for lists
    var listPreferences: [String: (isPinned: Bool, order: Int)] = [:] // URI -> (isPinned, order)
    
    // Store pinned status and order for feeds
    var feedPreferences: [String: (isPinned: Bool, order: Int)] = [:] // URI -> (isPinned, order)
    
    // Store pinned status and order for bookmark lists
    var bookmarkListPreferences: [String: (isPinned: Bool, order: Int)] = [:] // URI -> (isPinned, order)
    
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
        lists = []
        feeds = []
        bookmarkLists = []
        listPreferences = [:]
        feedPreferences = [:]
        bookmarkListPreferences = [:]
        DevLogger.shared.log("CurrentUser - clear - clear!")
    }
    
    // Načte seznam vlastních lists
    func refreshLists(client: BlueskyClient, limit: Int = 50) async {
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
    private func refreshListPreferences(client: BlueskyClient) async {
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
    func toggleListPin(listURI: String, client: BlueskyClient) async -> Bool {
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
    func updateListOrder(client: BlueskyClient) async -> Bool {
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

    func refreshFeeds(client: BlueskyClient, limit: Int = 50) async {
        guard let protoClient = await client.protoClient else { return }
        do {
            var feed_uris: [String] = []
            var newFeedPreferences: [String: (isPinned: Bool, order: Int)] = [:]
            
            let userPreferences = try await protoClient.getPreferences()
            for pref in userPreferences.preferences {
                switch pref {
                case .savedFeedsVersion2(let savedV2):
                    // Get ALL feeds, not just pinned ones
                    let feedItems = savedV2.items.filter { $0.feedType == .feed }
                    
                    // Store preferences with order based on array position
                    for (index, item) in feedItems.enumerated() {
                        feed_uris.append(item.value)
                        newFeedPreferences[item.value] = (isPinned: item.isPinned, order: index)
                    }
                default:
                    break
                }
            }
            
            // Update feed preferences
            let finalFeedPreferences = newFeedPreferences
            await MainActor.run {
                self.feedPreferences = finalFeedPreferences
            }
            
            if !feed_uris.isEmpty {
                let feedGenerators = try await protoClient.getFeedGenerators(by: feed_uris)
                
                // Sort feeds based on preferences (pinned first, then by order)
                let sortedFeeds = sortFeedsByPreferences(feedGenerators.feeds)
                
                await MainActor.run {
                    self.feeds = sortedFeeds
                }
                let pinnedCount = newFeedPreferences.filter { $0.value.isPinned }.count
                DevLogger.shared.log("CurrentUser - refreshFeeds - add feeds, count: \(feeds.count), pinned: \(pinnedCount)")
            }

        } catch {
            DevLogger.shared.log("CurrentUser - refreshFeeds unsucessfull")
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
    func toggleFeedPin(feedURI: String, client: BlueskyClient) async -> Bool {
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
    func updateFeedOrder(client: BlueskyClient) async -> Bool {
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
    
    // MARK: - Bookmark Lists
    
    // Načte seznam vlastních bookmark lists
    func refreshBookmarkLists(client: BlueskyClient, limit: Int = 50) async {
        guard !did.isEmpty else { 
            DevLogger.shared.log("CurrentUser - refreshBookmarkLists - did empty")
            return 
        }
        guard let protoClient = await client.protoClient else {
            DevLogger.shared.log("CurrentUser - refreshBookmarkLists - protoClient is nil")
            return
        }
        DevLogger.shared.log("CurrentUser - refreshBookmarkLists - starting")
        
        // Reset cursor for full refresh
        bookmarkListsLastCursor = nil
        
        do {
            let output = try await protoClient.getBookmarkLists(actorDID: did, limit: limit, cursor: nil)
            
            bookmarkListsLastCursor = output.cursor
            DevLogger.shared.log("CurrentUser - refreshBookmarkLists - old count: \(bookmarkLists.count), new count: \(output.lists.count)")
            
            // Sort lists based on preferences
            let sortedLists = sortBookmarkListsByPreferences(output.lists)
            
            await MainActor.run {
                self.bookmarkLists = sortedLists
            }
        } catch {
            DevLogger.shared.log("CurrentUser - refreshBookmarkLists - error: \(error)")
        }
    }
    
    // Sort bookmark lists based on preferences (pinned first, then by order)
    private func sortBookmarkListsByPreferences(_ lists: [BookmarkListView]) -> [BookmarkListView] {
        return lists.sorted { list1, list2 in
            let pref1 = bookmarkListPreferences[list1.uri]
            let pref2 = bookmarkListPreferences[list2.uri]
            
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
            
            // If neither has preferences, maintain original order by creation date
            return list1.record.createdAt > list2.record.createdAt
        }
    }
    
    // Toggle pin status for a bookmark list
    func toggleBookmarkListPin(listURI: String, client: BlueskyClient) async -> Bool {
        let currentPinStatus = bookmarkListPreferences[listURI]?.isPinned ?? false
        let newPinStatus = !currentPinStatus
        
        // For now, just update local state since we don't have server-side preferences for bookmark lists yet
        await MainActor.run {
            if var pref = bookmarkListPreferences[listURI] {
                pref.isPinned = newPinStatus
                bookmarkListPreferences[listURI] = pref
            } else {
                // If not in preferences yet, add it with the last order
                let maxOrder = bookmarkListPreferences.values.map { $0.order }.max() ?? -1
                bookmarkListPreferences[listURI] = (isPinned: newPinStatus, order: maxOrder + 1)
            }
            
            // Re-sort bookmark lists
            bookmarkLists = sortBookmarkListsByPreferences(bookmarkLists)
        }
        
        DevLogger.shared.log("CurrentUser - toggleBookmarkListPin - Updated pin status for \(listURI) to \(newPinStatus)")
        return true
    }
    
    
    func clearBookmarkLists() {
        bookmarkLists = []
        bookmarkListsLastCursor = nil
        bookmarkListPreferences = [:]
    }
}

