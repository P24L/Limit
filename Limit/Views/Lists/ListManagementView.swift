//
//  ListManagementView.swift
//  Limit
//
//  Created by Claude Code on 11.07.2025.
//

import SwiftUI
import ATProtoKit

struct ListManagementView: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var router
    
    @State private var isLoading = false
    @State private var showCreateList = false
    @State private var listToDelete: AppBskyLexicon.Graph.ListViewDefinition?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack {
            if currentUser.lists.isEmpty && !isLoading {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Lists Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Create your first list to organize people you follow")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showCreateList = true
                    }) {
                        Text("Create List")
                            .fontWeight(.medium)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Lists content
                List {
                    ForEach(currentUser.lists, id: \.uri) { list in
                        ListManagementItemView(list: list)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    listToDelete = list
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { indexSet in
                        // Handle delete action
                        if let index = indexSet.first {
                            listToDelete = currentUser.lists[index]
                            showDeleteConfirmation = true
                        }
                    }
                }
                .refreshable {
                    await refreshLists()
                }
            }
        }
        .navigationTitle("Lists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showCreateList = true
                }) {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
            }
        }
        .task {
            await refreshLists()
        }
        .sheet(isPresented: $showCreateList) {
            CreateListView()
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .alert("Delete List", isPresented: $showDeleteConfirmation, presenting: listToDelete) { list in
            Button("Cancel", role: .cancel) {
                listToDelete = nil
            }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteList(list)
                }
            }
        } message: { list in
            Text("Are you sure you want to delete \"\(list.name)\"? This action cannot be undone.")
        }
    }
    
    private func refreshLists() async {
        isLoading = true
        defer { isLoading = false }
        
        await currentUser.refreshLists(client: client)
        DevLogger.shared.log("ListManagementView.swift - Refreshed lists, count: \(currentUser.lists.count)")
    }
    
    private func deleteList(_ list: AppBskyLexicon.Graph.ListViewDefinition) async {
        isLoading = true
        defer { isLoading = false }
        
        let success = await client.deleteList(listURI: list.uri)
        if success {
            DevLogger.shared.log("ListManagementView.swift - Successfully deleted list: \(list.name)")
            await refreshLists()
        } else {
            DevLogger.shared.log("ListManagementView.swift - Failed to delete list: \(list.name)")
        }
        
        listToDelete = nil
    }
}

struct ListManagementItemView: View {
    let list: AppBskyLexicon.Graph.ListViewDefinition
    @Environment(AppRouter.self) private var router
    
    var body: some View {
        HStack(spacing: 12) {
            // List avatar or placeholder
            Group {
                if let avatarURL = list.avatarImageURL {
                    AvatarView(url: avatarURL, size: 44)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.blue)
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("\(list.listItemCount ?? 0) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: list.indexedAt, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            // Navigate to list members view
            router.navigateTo(.listMembers(list: list))
        }
    }
}

#Preview {
    NavigationStack {
        ListManagementView()
    }
    .environment(BlueskyClient.preview())
    .environment(CurrentUser())
    .environment(AppRouter(initialTab: .settings))
}