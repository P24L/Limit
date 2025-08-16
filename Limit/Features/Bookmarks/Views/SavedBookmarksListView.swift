// SavedBookmarksListView.swift

import SwiftUI

struct SavedBookmarksListView: View {
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(AppRouter.self) private var router
    
    @Binding var searchText: String
    let filterListUri: String?
    let filterListName: String?
    @State private var isLoadingMore = false
    @State private var selectedTags: Set<String> = []
    @State private var includeArchived = false
    
    init(searchText: Binding<String> = .constant(""), filterListUri: String? = nil, filterListName: String? = nil) {
        self._searchText = searchText
        self.filterListUri = filterListUri
        self.filterListName = filterListName
    }

    // Available tags (unique, case-insensitive, sorted by frequency then name)
    private var availableTags: [String] {
        let tags = allBookmarks.flatMap { $0.record.tags ?? [] }
        guard !tags.isEmpty else { return [] }
        var freq: [String:Int] = [:]
        for t in tags { freq[t, default: 0] += 1 }
        return freq
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
            .map { $0.key }
    }

    private var allBookmarks: [BookmarkView] { 
        // Filter by list if specified
        if let filterListUri = filterListUri {
            return bookmarkManager.bookmarks.filter { bookmark in
                bookmark.record.listUris?.contains(filterListUri) ?? false
            }
        }
        return bookmarkManager.bookmarks
    }

    // MARK: - Filtering
    private var filtered: [BookmarkView] {
        // First filter by archived status
        let archivedFiltered = allBookmarks.filter { bookmark in
            if includeArchived {
                return true // Show all bookmarks
            } else {
                return bookmark.record.archived != true // Hide archived
            }
        }
        
        // Then apply search filter
        let base: [BookmarkView]
        if searchText.isEmpty {
            base = archivedFiltered
        } else {
            base = archivedFiltered.filter { b in
                if b.record.title.localizedCaseInsensitiveContains(searchText) { return true }
                if let d = b.record.description, d.localizedCaseInsensitiveContains(searchText) { return true }
                if b.record.url.localizedCaseInsensitiveContains(searchText) { return true }
                if let n = b.record.note, n.localizedCaseInsensitiveContains(searchText) { return true }
                if let tags = b.record.tags, tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) { return true }
                return false
            }
        }
        // Tag filter (multi-select chips)
        if selectedTags.isEmpty { return base }
        return base.filter { b in
            guard let tags = b.record.tags else { return false }
            return !selectedTags.isDisjoint(with: Set(tags))
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            List {
                ForEach(filtered, id: \.uri) { bookmark in
                    // Tvůj card view přímo v List řádku
                    BookmarkCardView(bookmark: bookmark)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                router.presentedSheet = .bookmarkEdit(id: extractBookmarkId(from: bookmark.uri))
                            } label: { Label("Edit", systemImage: "pencil") }
                            
                            Button {
                                if let url = URL(string: bookmark.record.url) {
                                    router.navigateTo(.safari(url: url))
                                }
                            } label: { Label("Open Link", systemImage: "safari") }
                            
                            Button(role: .destructive) {
                                Task { try? await bookmarkManager.deleteBookmark(bookmark) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        // Leading swipe: rychlé otevření
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                if let url = URL(string: bookmark.record.url) {
                                    router.navigateTo(.safari(url: url))
                                }
                            } label: { Label("Open", systemImage: "safari") }
                        }
                        // Trailing swipe: edit / share / delete
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                router.presentedSheet = .bookmarkEdit(id: extractBookmarkId(from: bookmark.uri))
                            } label: { Label("Edit", systemImage: "pencil") }
                            
                            Button {
                                router.presentedSheet = .composePost(quotedPost: nil, replyTo: nil, bookmark: bookmark)
                            } label: { Label("Share", systemImage: "square.and.arrow.up") }
                            
                            Button(role: .destructive) {
                                Task { try? await bookmarkManager.deleteBookmark(bookmark) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        .onAppear {
                            if searchText.isEmpty && bookmark.uri == filtered.last?.uri {
                                Task { await loadMore() }
                            }
                        }
                }
                
                if bookmarkManager.isLoadingPage {
                    HStack {
                        Spacer()
                        ProgressView().padding()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .background(.warmBackground)
            .safeAreaInset(edge: .top) {
                if !availableTags.isEmpty {
                    TagChipsBar(tags: availableTags,
                                selected: selectedTags,
                                includeArchived: includeArchived,
                                onToggle: { tag in
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                },
                                onClear: {
                                    selectedTags.removeAll()
                                },
                                onToggleArchived: {
                                    includeArchived.toggle()
                                })
                }
            }
            .refreshable {
                await bookmarkManager.fetchAndSyncBookmarks()
            }
            .task {
                if bookmarkManager.bookmarks.isEmpty {
                    await bookmarkManager.fetchAndSyncBookmarks()
                }
            }
            
            if filtered.isEmpty {
                EmptySavedState(searchText: searchText) {
                    router.presentedSheet = .bookmarkEdit(id: nil)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Paging
    private func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        await bookmarkManager.loadNextPage()
        isLoadingMore = false
    }
    
    // MARK: - Helpers
    private func extractBookmarkId(from uri: String) -> String {
        let c = uri.split(separator: "/")
        if let last = c.last { return String(last) }
        return uri
    }
}

// MARK: - Chips Bar
private struct TagChipsBar: View {
    let tags: [String]
    let selected: Set<String>
    let includeArchived: Bool
    let onToggle: (String) -> Void
    let onClear: () -> Void
    let onToggleArchived: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                Button(action: onClear) {
                    HStack(spacing: 6) {
                        Image(systemName: selected.isEmpty ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                        Text("All")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selected.isEmpty ? Color.mintAccent : Color.mintInactive.opacity(0.3))
                    )
                    .foregroundColor(selected.isEmpty ? .white : .primary)
                }
                .buttonStyle(.plain)
                
                // "Archived" chip
                Button(action: onToggleArchived) {
                    HStack(spacing: 6) {
                        Image(systemName: includeArchived ? "archivebox.fill" : "archivebox")
                            .font(.caption)
                        Text("Archived")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(includeArchived ? Color.mintAccent : Color.mintInactive.opacity(0.3))
                    )
                    .foregroundColor(includeArchived ? .white : .primary)
                }
                .buttonStyle(.plain)
                
                ForEach(tags, id: \.self) { tag in
                    let isOn = selected.contains(tag)
                    Button {
                        onToggle(tag)
                    } label: {
                        HStack(spacing: 6) {
                            if isOn { Image(systemName: "checkmark").font(.caption) }
                            Text("#\(tag)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isOn ? Color.mintAccent : Color.mintInactive.opacity(0.3))
                        )
                        .foregroundColor(isOn ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 0)
        }
        .padding(.horizontal, 8)
        .padding(.top, 0)
    }
}