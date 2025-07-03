//
//  UsersSearchView.swift
//  Limit
//
//  Created by Claude on 01.07.2025.
//

import SwiftUI
import ATProtoKit
import AppRouter
import SDWebImageSwiftUI

struct UsersSearchView: View {
    let query: String
    
    @Environment(BlueskyClient.self) private var client
    @Environment(AppRouter.self) private var router
    @Environment(CurrentUser.self) private var currentUser
    
    @State private var actors: [AppBskyLexicon.Actor.ProfileViewDefinition] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var cursor: String?
    @State private var followingStates: [String: String?] = [:] // DID -> followingURI
    
    var body: some View {
        Group {
            if isLoading && actors.isEmpty {
                ProgressView("Searching users...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, actors.isEmpty {
                VStack {
                    Text("Error searching users")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await searchUsers()
                        }
                    }
                    .padding(.top)
                }
                .padding()
            } else if actors.isEmpty && !isLoading {
                Text("No users found for \"\(query)\"")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(actors, id: \.actorDID) { actor in
                            FollowerItemView(
                                profile: actor,
                                followingURI: followingStates[actor.actorDID] ?? actor.viewer?.followingURI,
                                onFollowToggle: { did, uri in
                                    followingStates[did] = uri
                                }
                            )
                        }
                        
                        // Load more button if there's a cursor
                        if cursor != nil {
                            Button("Load more") {
                                Task {
                                    await loadMoreUsers()
                                }
                            }
                            .padding()
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .refreshable {
                    await searchUsers()
                }
            }
        }
        .task(id: query) {
            await searchUsers()
        }
    }
    
    private func searchUsers() async {
        guard !query.isEmpty else { return }
        guard !isLoading else { return }
        guard client.isAuthenticated, let protoClient = client.protoClient else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let result = await client.performAuthenticatedRequest {
            try await protoClient.searchActors(matching: query, limit: 25, cursor: nil)
        }
        
        await MainActor.run {
            if let response = result {
                self.actors = response.actors
                self.cursor = response.cursor
                self.error = nil
                // Initialize following states from API response
                for actor in response.actors {
                    if followingStates[actor.actorDID] == nil {
                        followingStates[actor.actorDID] = actor.viewer?.followingURI
                    }
                }
            } else {
                self.error = NSError(domain: "UsersSearchView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to search users"])
                self.actors = []
                self.cursor = nil
            }
        }
    }
    
    private func loadMoreUsers() async {
        guard let cursor = cursor else { return }
        guard !isLoading else { return }
        guard client.isAuthenticated, let protoClient = client.protoClient else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let result = await client.performAuthenticatedRequest {
            try await protoClient.searchActors(matching: query, limit: 25, cursor: cursor)
        }
        
        await MainActor.run {
            if let response = result {
                self.actors.append(contentsOf: response.actors)
                self.cursor = response.cursor
                self.error = nil
                // Initialize following states for new actors
                for actor in response.actors {
                    if followingStates[actor.actorDID] == nil {
                        followingStates[actor.actorDID] = actor.viewer?.followingURI
                    }
                }
            } else {
                self.error = NSError(domain: "UsersSearchView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load more users"])
            }
        }
    }
}

#Preview {
    UsersSearchView(query: "test")
        .environment(BlueskyClient())
        .environment(AppRouter(initialTab: .search))
        .environment(CurrentUser())
}