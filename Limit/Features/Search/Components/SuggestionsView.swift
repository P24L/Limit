//
//  SuggestionsView.swift
//  Limit
//
//  Created by Claude on 01.07.2025.
//

import SwiftUI
import ATProtoKit

struct SuggestionsView: View {
    @Environment(BlueskyClient.self) private var client
    
    @State private var suggestions: [AppBskyLexicon.Actor.ProfileViewDefinition] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var followingStates: [String: String?] = [:] // DID -> followingURI
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading suggestions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack {
                    Text("Error loading suggestions")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadSuggestions()
                        }
                    }
                    .padding(.top)
                }
                .padding()
            } else if suggestions.isEmpty {
                Text("No suggestions available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(suggestions, id: \.actorDID) { suggestion in
                            FollowerItemView(
                                profile: suggestion,
                                followingURI: followingStates[suggestion.actorDID] ?? suggestion.viewer?.followingURI
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .refreshable {
                    await loadSuggestions()
                }
            }
        }
        .task {
            await loadSuggestions()
        }
    }
    
    private func loadSuggestions() async {
        guard !isLoading else { return }
        guard client.isAuthenticated, let protoClient = client.protoClient else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let result = await client.performAuthenticatedRequest {
            try await protoClient.getSuggestions(limit: 20)
        }
        
        await MainActor.run {
            if let response = result {
                self.suggestions = response.actors
                self.error = nil
                // Initialize following states from API response
                for actor in response.actors {
                    if followingStates[actor.actorDID] == nil {
                        followingStates[actor.actorDID] = actor.viewer?.followingURI
                    }
                }
            } else {
                self.error = NSError(domain: "SuggestionsView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load suggestions"])
            }
        }
    }
}