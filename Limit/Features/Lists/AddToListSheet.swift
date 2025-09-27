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
    
    @Environment(MultiAccountClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var listMemberships: [String: Bool] = [:] // listURI -> isMember
    @State private var isLoading = true
    @State private var isProcessing: Set<String> = [] // listURIs being processed
    
    var body: some View {
        NavigationView {
            VStack {
                let colors = themeManager.colors
                // Actor info header
                HStack(spacing: 12) {
                    // Real actor avatar
                    AvatarView(url: actorAvatarURL, size: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let displayName = actorDisplayName, !displayName.isEmpty {
                            Text(displayName)
                                .font(.headline)
                                .lineLimit(1)
                                .foregroundColor(colors.textPrimary)
                        }
                        Text("@\(actorHandle)")
                            .font(.subheadline)
                            .foregroundColor(colors.textSecondary)
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
                            .foregroundColor(colors.textSecondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if currentUser.lists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 32))
                            .foregroundColor(colors.textSecondary)
                        
                        Text("No Lists")
                            .font(.headline)
                            .foregroundColor(colors.textPrimary)
                        
                        Text("Create lists in Settings to organize people you follow")
                            .foregroundColor(colors.textSecondary)
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
                    let colors = themeManager.colors
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(colors.accent)
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
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        let colors = themeManager.colors
        return HStack(spacing: 12) {
            // List avatar or placeholder
            Group {
                if let avatarURL = list.avatarImageURL {
                    AvatarView(url: avatarURL, size: 36)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colors.accent.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14))
                                .foregroundColor(colors.accent)
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(colors.textPrimary)
                
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(colors.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("\(list.listItemCount ?? 0) members")
                        .font(.caption)
                        .foregroundColor(colors.textSecondary)
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
                        .foregroundColor(isMember ? colors.accent : colors.textSecondary)
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
