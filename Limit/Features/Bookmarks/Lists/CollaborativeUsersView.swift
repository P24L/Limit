//
//  CollaborativeUsersView.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import SwiftUI

struct CollaborativeUsersView: View {
    @Binding var collaborativeUsers: [CollaborativeUser]
    @State private var handleInput = ""
    @State private var suggestions: [HandleSuggestion] = []
    @State private var isSearching = false
    @State private var showingSuggestions = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    
    @Environment(BlueskyClient.self) private var client
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collaborative Users")
                .font(.headline)
            
            Text("Add users who can add bookmarks to this list")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Input field with autocomplete
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("Enter handle (e.g. user.bsky.social)", text: $handleInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                        .onChange(of: handleInput) { _, newValue in
                            // Cancel previous search
                            searchTask?.cancel()
                            
                            if newValue.isEmpty {
                                suggestions = []
                                showingSuggestions = false
                            } else if newValue.count >= 2 {
                                // Start new search after a short delay
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                                    
                                    if !Task.isCancelled {
                                        await searchForHandles(prefix: newValue)
                                    }
                                }
                            }
                        }
                        .onSubmit {
                            Task {
                                await addUserFromInput()
                            }
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Button("Add") {
                        Task {
                            await addUserFromInput()
                        }
                    }
                    .disabled(handleInput.isEmpty || isSearching)
                }
                
                // Autocomplete suggestions
                if showingSuggestions && !suggestions.isEmpty {
                    AutocompleteSuggestionsView(
                        suggestions: suggestions,
                        onSelect: selectSuggestion
                    )
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // List of added users
            if !collaborativeUsers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Added users:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(collaborativeUsers) { user in
                        HStack {
                            VStack(alignment: .leading) {
                                if let displayName = user.displayName {
                                    Text(displayName)
                                        .font(.subheadline)
                                }
                                Text("@\(user.handle)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                removeUser(user)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
        .onTapGesture {
            // Hide suggestions when tapping outside
            showingSuggestions = false
        }
    }
    
    private func searchForHandles(prefix: String) async {
        guard let protoClient = client.protoClient else { return }
        
        let validator = HandleValidator(atProtoKit: protoClient)
        
        await MainActor.run {
            isSearching = true
            errorMessage = nil
        }
        
        do {
            let results = try await validator.getSuggestedHandles(for: prefix, limit: 5)
            
            await MainActor.run {
                // Filter out already added users
                let existingHandles = Set(collaborativeUsers.map { $0.handle })
                suggestions = results.filter { !existingHandles.contains($0.handle) }
                showingSuggestions = !suggestions.isEmpty
                isSearching = false
            }
        } catch {
            await MainActor.run {
                suggestions = []
                showingSuggestions = false
                isSearching = false
            }
        }
    }
    
    private func selectSuggestion(_ suggestion: HandleSuggestion) {
        let newUser = CollaborativeUser(
            did: suggestion.did,
            handle: suggestion.handle,
            displayName: suggestion.displayName,
            avatarURL: suggestion.avatarURL
        )
        
        // Check if user already exists
        if !collaborativeUsers.contains(where: { $0.did == newUser.did }) {
            collaborativeUsers.append(newUser)
        }
        
        // Clear input and suggestions
        handleInput = ""
        suggestions = []
        showingSuggestions = false
        errorMessage = nil
    }
    
    private func addUserFromInput() async {
        let trimmedHandle = handleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHandle.isEmpty else { return }
        
        guard let protoClient = client.protoClient else {
            errorMessage = "Not authenticated"
            return
        }
        
        let validator = HandleValidator(atProtoKit: protoClient)
        
        isSearching = true
        errorMessage = nil
        
        do {
            // Validate and get DID
            let did = try await validator.validateHandleAndGetDID(trimmedHandle)
            
            // Check if user already exists
            if collaborativeUsers.contains(where: { $0.did == did }) {
                errorMessage = "User already added"
                isSearching = false
                return
            }
            
            // Try to get more info about the user
            if let results = try? await validator.searchHandles(matching: trimmedHandle, limit: 1),
               let userInfo = results.first(where: { $0.handle == trimmedHandle }) {
                let newUser = CollaborativeUser(
                    did: did,
                    handle: trimmedHandle,
                    displayName: userInfo.displayName,
                    avatarURL: userInfo.avatarURL
                )
                collaborativeUsers.append(newUser)
            } else {
                // Add with minimal info
                let newUser = CollaborativeUser(
                    did: did,
                    handle: trimmedHandle,
                    displayName: nil,
                    avatarURL: nil
                )
                collaborativeUsers.append(newUser)
            }
            
            // Clear input
            handleInput = ""
            suggestions = []
            showingSuggestions = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSearching = false
    }
    
    private func removeUser(_ user: CollaborativeUser) {
        collaborativeUsers.removeAll { $0.id == user.id }
    }
}

// MARK: - Subviews

struct AutocompleteSuggestionsView: View {
    let suggestions: [HandleSuggestion]
    let onSelect: (HandleSuggestion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.handle) { suggestion in
                Button(action: { onSelect(suggestion) }) {
                    suggestionRow(for: suggestion)
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion.handle != suggestions.last?.handle {
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private func suggestionRow(for suggestion: HandleSuggestion) -> some View {
        HStack(spacing: 8) {
            // Avatar
            Group {
                if let avatarURL = suggestion.avatarURL {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                if let displayName = suggestion.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Text("@\(suggestion.handle)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct CollaborativeUserRow: View {
    let user: CollaborativeUser
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let displayName = user.displayName {
                    Text(displayName)
                        .font(.subheadline)
                }
                Text("@\(user.handle)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Types

struct CollaborativeUser: Identifiable, Equatable {
    let id = UUID()
    let did: String
    let handle: String
    let displayName: String?
    let avatarURL: String?
}