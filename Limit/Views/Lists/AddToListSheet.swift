//
//  AddToListSheet.swift
//  Limit
//
//  Created by Claude Code on 11.07.2025.
//

import SwiftUI
import ATProtoKit

struct AddToListSheet: View {
    let actorDID: String
    let actorHandle: String
    let actorDisplayName: String?
    let actorAvatarURL: URL?
    
    @Environment(BlueskyClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(\.dismiss) private var dismiss
    
    @State private var listMemberships: [String: Bool] = [:] // listURI -> isMember
    @State private var isLoading = true
    @State private var isProcessing: Set<String> = [] // listURIs being processed
    
    var body: some View {
        NavigationView {
            VStack {
                // Actor info header
                HStack(spacing: 12) {
                    // Real actor avatar
                    AvatarView(url: actorAvatarURL, size: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let displayName = actorDisplayName, !displayName.isEmpty {
                            Text(displayName)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        Text("@\(actorHandle)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Divider()
                    .padding(.vertical, 8)
                
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading lists...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if currentUser.lists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        
                        Text("No Lists")
                            .font(.headline)
                        
                        Text("Create lists in Settings to organize people you follow")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(currentUser.lists, id: \.uri) { list in
                        ListToggleRow(
                            list: list,
                            isMember: listMemberships[list.uri] ?? false,
                            isProcessing: isProcessing.contains(list.uri)
                        ) { newValue in
                            await toggleMembership(for: list, shouldAdd: newValue)
                        }
                    }
                }
            }
            .navigationTitle("Add to Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadListMemberships()
            }
        }
    }
    
    private func loadListMemberships() async {
        isLoading = true
        defer { isLoading = false }
        
        // Refresh user's lists first
        await currentUser.refreshLists(client: client)
        
        // Check membership for each list
        var memberships: [String: Bool] = [:]
        
        for list in currentUser.lists {
            let isMember = await client.checkActorInList(listURI: list.uri, actorDID: actorDID)
            memberships[list.uri] = isMember
        }
        
        _ = await MainActor.run {
            self.listMemberships = memberships
        }
        
        DevLogger.shared.log("AddToListSheet.swift - Loaded memberships for actor \(actorHandle) in \(memberships.count) lists")
    }
    
    private func toggleMembership(for list: AppBskyLexicon.Graph.ListViewDefinition, shouldAdd: Bool) async {
        let listURI = list.uri
        
        _ = await MainActor.run {
            isProcessing.insert(listURI)
        }
        
        defer {
            Task { @MainActor in
                isProcessing.remove(listURI)
            }
        }
        
        let success: Bool
        if shouldAdd {
            success = await client.addActorToList(listURI: listURI, actorDID: actorDID)
        } else {
            success = await client.removeActorFromList(listURI: listURI, actorDID: actorDID)
        }
        
        if success {
            _ = await MainActor.run {
                listMemberships[listURI] = shouldAdd
            }
            DevLogger.shared.log("AddToListSheet.swift - \(shouldAdd ? "Added" : "Removed") actor \(actorHandle) \(shouldAdd ? "to" : "from") list \(list.name)")
        } else {
            DevLogger.shared.log("AddToListSheet.swift - Failed to \(shouldAdd ? "add" : "remove") actor \(actorHandle) \(shouldAdd ? "to" : "from") list \(list.name)")
        }
    }
}

struct ListToggleRow: View {
    let list: AppBskyLexicon.Graph.ListViewDefinition
    let isMember: Bool
    let isProcessing: Bool
    let onToggle: (Bool) async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // List avatar or placeholder
            Group {
                if let avatarURL = list.avatarImageURL {
                    AvatarView(url: avatarURL, size: 36)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14))
                                .foregroundColor(.mintAccent)
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("\(list.listItemCount ?? 0) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    Task {
                        await onToggle(!isMember)
                    }
                }) {
                    Image(systemName: isMember ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isMember ? .green : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isProcessing {
                Task {
                    await onToggle(!isMember)
                }
            }
        }
    }
}

