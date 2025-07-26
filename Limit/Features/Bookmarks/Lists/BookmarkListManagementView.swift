//
//  BookmarkListManagementView.swift
//  Limit
//
//  Created by Assistant on 22.07.2025.
//

import SwiftUI
import SwiftData
import ATProtoKit

struct BookmarkListManagementView: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(AppRouter.self) private var router
    @Environment(BookmarkManager.self) private var bookmarkManager
    
    @State private var isLoading = false
    @State private var showCreateList = false
    @State private var listToDelete: BookmarkListView?
    @State private var showDeleteConfirmation = false
    @State private var listToEdit: BookmarkListView?
    
    var body: some View {
        VStack {
            if bookmarkManager.bookmarkLists.isEmpty && !isLoading {
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
                    let sortedLists = bookmarkManager.bookmarkLists.sorted { list1, list2 in
                        let isPinned1 = list1.record.pinned ?? false
                        let isPinned2 = list2.record.pinned ?? false
                        
                        // First sort by pinned status
                        if isPinned1 != isPinned2 {
                            return isPinned1
                        }
                        
                        // Then sort alphabetically by name
                        return list1.record.name.localizedCaseInsensitiveCompare(list2.record.name) == .orderedAscending
                    }
                    
                    ForEach(sortedLists, id: \.uri) { list in
                        BookmarkListManagementItemView(
                            list: list,
                            isPinned: list.record.pinned ?? false,
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
                            listToDelete = sortedLists[index]
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
        
        await bookmarkManager.fetchAndSyncBookmarks()
        DevLogger.shared.log("BookmarkListManagementView.swift - Refreshed bookmark lists, count: \(bookmarkManager.bookmarkLists.count)")
    }
    
    private func deleteList(_ list: BookmarkListView) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await bookmarkManager.deleteBookmarkList(list)
            DevLogger.shared.log("BookmarkListManagementView.swift - Successfully deleted bookmark list: \(list.record.name)")
        } catch {
            DevLogger.shared.log("BookmarkListManagementView.swift - Failed to delete bookmark list: \(error)")
        }
        
        listToDelete = nil
    }
    
    private func togglePin(for list: BookmarkListView) async {
        isLoading = true
        defer { isLoading = false }
        
        let success = await bookmarkManager.updateBookmarkListPinStatus(listURI: list.uri)
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
                Text(list.record.name)
                    .font(.headline)
                    .lineLimit(1)
                
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
            PinButton(isPinned: isPinned, action: onPinToggle)
            
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
    let previewClient = BlueskyClient.preview()
    let previewContainer = try! ModelContainer(for: Schema(BookmarkCacheSchema.allModels))
    let bookmarkManager = BookmarkManager(
        context: previewContainer.mainContext,
        client: previewClient
    )
    
    return NavigationStack {
        BookmarkListManagementView()
    }
    .environment(previewClient)
    .environment(CurrentUser())
    .environment(AppRouter(initialTab: .settings))
    .environment(bookmarkManager)
}