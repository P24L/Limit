//
//  BookmarkListManagementView.swift
//  Limit
//
//  Created by Assistant on 22.07.2025.
//

import SwiftUI
import ATProtoKit

struct BookmarkListManagementView: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var router
    
    @State private var isLoading = false
    @State private var showCreateList = false
    @State private var listToDelete: BookmarkListView?
    @State private var showDeleteConfirmation = false
    @State private var listToEdit: BookmarkListView?
    
    var body: some View {
        VStack {
            if currentUser.bookmarkLists.isEmpty && !isLoading {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Bookmark Lists Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Create your first bookmark list to organize your saved links")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showCreateList = true
                    }) {
                        Text("Create Bookmark List")
                            .fontWeight(.medium)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Lists content
                List {
                    ForEach(currentUser.bookmarkLists, id: \.uri) { list in
                        BookmarkListManagementItemView(
                            list: list,
                            isPinned: currentUser.bookmarkListPreferences[list.uri]?.isPinned ?? false,
                            onPinToggle: {
                                Task {
                                    await togglePin(for: list)
                                }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                listToDelete = list
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                listToEdit = list
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { indexSet in
                        // Handle delete action
                        if let index = indexSet.first {
                            listToDelete = currentUser.bookmarkLists[index]
                            showDeleteConfirmation = true
                        }
                    }
                }
                .refreshable {
                    await refreshLists()
                }
            }
        }
        .navigationTitle("Bookmark Lists")
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
            CreateBookmarkListView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $listToEdit) { list in
            CreateBookmarkListView(editingList: list)
                .environment(client)
                .environment(currentUser)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Delete Bookmark List", isPresented: $showDeleteConfirmation, presenting: listToDelete) { list in
            Button("Cancel", role: .cancel) {
                listToDelete = nil
            }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteList(list)
                }
            }
        } message: { list in
            Text("Are you sure you want to delete \"\(list.record.name)\"? This action cannot be undone.")
        }
    }
    
    private func refreshLists() async {
        isLoading = true
        defer { isLoading = false }
        
        await currentUser.refreshBookmarkLists(client: client)
        DevLogger.shared.log("BookmarkListManagementView.swift - Refreshed bookmark lists, count: \(currentUser.bookmarkLists.count)")
    }
    
    private func deleteList(_ list: BookmarkListView) async {
        isLoading = true
        defer { isLoading = false }
        
        // Extract repo and rkey from list URI
        // URI format: at://did:plc:xyz/app.hyper-limit.bookmark.list/rkey
        let components = list.uri.split(separator: "/")
        
        guard components.count >= 4 else {
            DevLogger.shared.log("BookmarkListManagementView.swift - Invalid list URI: \(list.uri)")
            return
        }
        
        let repo = String(components[1])
        let rkey = String(components[3])
        
        do {
            guard let protoClient = client.protoClient else {
                DevLogger.shared.log("BookmarkListManagementView.swift - Failed to access ATProto client")
                return
            }
            
            try await protoClient.deleteBookmarkList(repo: repo, rkey: rkey)
            DevLogger.shared.log("BookmarkListManagementView.swift - Successfully deleted bookmark list: \(list.record.name)")
            await refreshLists()
        } catch {
            DevLogger.shared.log("BookmarkListManagementView.swift - Failed to delete bookmark list: \(error)")
        }
        
        listToDelete = nil
    }
    
    private func togglePin(for list: BookmarkListView) async {
        isLoading = true
        defer { isLoading = false }
        
        let success = await currentUser.toggleBookmarkListPin(listURI: list.uri, client: client)
        if !success {
            DevLogger.shared.log("BookmarkListManagementView.swift - Failed to toggle pin for bookmark list: \(list.record.name)")
        }
    }
    
}

struct BookmarkListManagementItemView: View {
    let list: BookmarkListView
    let isPinned: Bool
    let onPinToggle: () -> Void
    @Environment(AppRouter.self) private var router
    
    var body: some View {
        HStack(spacing: 12) {
            // List icon with color
            Group {
                let backgroundColor = list.record.color.map { Color(hex: $0) } ?? Color.orange
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: iconForList(list.record))
                            .foregroundColor(backgroundColor)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(list.record.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if let description = list.record.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    // Visibility indicator
                    Label(list.record.visibility.rawValue.capitalized, systemImage: visibilityIcon(for: list.record.visibility))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let count = list.bookmarkCount {
                        Text("\(count) bookmarks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Pin toggle button
            Button(action: onPinToggle) {
                Image(systemName: isPinned ? "pin.slash" : "pin")
                    .font(.body)
                    .foregroundColor(isPinned ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to bookmark list details view (for future implementation)
            // router.navigateTo(.bookmarkListDetail(list: list))
        }
    }
    
    private func iconForList(_ record: BookmarkListRecord) -> String {
        switch record.icon {
        case .folder:
            return "folder.fill"
        case .list:
            return "list.bullet"
        case .star:
            return "star.fill"
        case .tag:
            return "tag.fill"
        default:
            return "bookmark.fill"
        }
    }
    
    private func visibilityIcon(for visibility: BookmarkListVisibility) -> String {
        switch visibility {
        case .private:
            return "lock.fill"
        case .collaborative:
            return "person.2.fill"
        case .public:
            return "globe"
        }
    }
}


#Preview {
    NavigationStack {
        BookmarkListManagementView()
    }
    .environment(BlueskyClient.preview())
    .environment(CurrentUser())
    .environment(AppRouter(initialTab: .settings))
}