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
        await refreshLists(client: client)

    }
    
    func clear() {
        did = ""
        handle = ""
        displayName = ""
        avatarURL = nil
    }
    
    // Načte seznam vlastních lists
    func refreshLists(client: BlueskyClient, limit: Int = 50) async {
        guard let protoClient = await client.protoClient else { return }
        guard !did.isEmpty else { return }
        do {
            let output = try await protoClient.getLists(
                from: did,
                limit: limit,
                cursor: listsLastCursor
            )
            listsLastCursor = output.cursor
            await MainActor.run {
                self.lists = output.lists
            }
        } catch {
            DevLogger.shared.log("CurrentUser - refreshLists se nepovedl")
        }
    }
    
    func clearLists() {
        lists = []
        listsLastCursor = nil
    }
}

