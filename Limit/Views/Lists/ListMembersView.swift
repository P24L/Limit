//
//  ListMembersView.swift
//  Limit
//
//  Created by Claude Code on 14.07.2025.
//

import SwiftUI
import ATProtoKit

struct ListMembersView: View {
    let list: AppBskyLexicon.Graph.ListViewDefinition
    
    @Environment(BlueskyClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    @State private var members: [AppBskyLexicon.Graph.ListItemViewDefinition] = []
    @State private var isLoading = true
    @State private var memberToRemove: AppBskyLexicon.Graph.ListItemViewDefinition?
    @State private var showRemoveConfirmation = false
    @State private var cursor: String?
    
    var body: some View {
        VStack {
            if isLoading && members.isEmpty {
                VStack {
                    ProgressView()
                    Text("Loading members...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if members.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Members")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("This list doesn't have any members yet")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(members, id: \.listItemURI) { member in
                        ListMemberRow(member: member)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    memberToRemove = member
                                    showRemoveConfirmation = true
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
                .refreshable {
                    await loadMembers()
                }
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadMembers()
        }
        .alert("Remove Member", isPresented: $showRemoveConfirmation, presenting: memberToRemove) { member in
            Button("Cancel", role: .cancel) {
                memberToRemove = nil
            }
            Button("Remove", role: .destructive) {
                Task {
                    await removeMember(member)
                }
            }
        } message: { member in
            Text("Are you sure you want to remove \(member.subject.displayName ?? member.subject.actorHandle) from \"\(list.name)\"?")
        }
    }
    
    private func loadMembers() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let output = try await client.protoClient?.getList(from: list.uri)
            await MainActor.run {
                self.members = output?.items ?? []
                self.cursor = output?.cursor
            }
            DevLogger.shared.log("ListMembersView.swift - Loaded \(members.count) members for list: \(list.name)")
        } catch {
            DevLogger.shared.log("ListMembersView.swift - Error loading members: \(error)")
        }
    }
    
    private func removeMember(_ member: AppBskyLexicon.Graph.ListItemViewDefinition) async {
        isLoading = true
        defer { isLoading = false }
        
        let success = await client.removeActorFromList(listURI: list.uri, actorDID: member.subject.actorDID)
        
        if success {
            await MainActor.run {
                members.removeAll { $0.listItemURI == member.listItemURI }
            }
            DevLogger.shared.log("ListMembersView.swift - Successfully removed member: \(member.subject.actorHandle)")
        } else {
            DevLogger.shared.log("ListMembersView.swift - Failed to remove member: \(member.subject.actorHandle)")
        }
        
        memberToRemove = nil
    }
}

struct ListMemberRow: View {
    let member: AppBskyLexicon.Graph.ListItemViewDefinition
    @Environment(AppRouter.self) private var router
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: member.subject.avatarImageURL, size: 48)
                .onTapGesture {
                    router.navigateTo(.actor(userID: member.subject.actorDID))
                }
            
            VStack(alignment: .leading, spacing: 4) {
                if let displayName = member.subject.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Text("@\(member.subject.actorHandle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let description = member.subject.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            router.navigateTo(.actor(userID: member.subject.actorDID))
        }
    }
}

