//
//  BookmarksTabView.swift
//  Limit
//
//  Created by Assistant on 06.01.2025.
//

import SwiftUI
import SwiftData

struct BookmarksTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(BookmarkManager.self) private var bookmarkManager
    
    @State private var selectedSubTab: BookmarkSubTab = .saved
    @State private var searchText = ""
    
    enum BookmarkSubTab: String, CaseIterable {
        case saved = "Saved"
        case lists = "Lists"
        
        var systemImage: String {
            switch self {
            case .saved: return "bookmark.fill"
            case .lists: return "folder.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch selectedSubTab {
                case .saved:
                    SavedBookmarksListView(searchText: $searchText)
                case .lists:
                    BookmarkListsView()
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search bookmarks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        router.presentedSheet = .bookmarkEdit(id: nil)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.mintAccent)
                    }
                }
            }
            .safeAreaInset(edge: .top) { subTabPicker }
        }
    }
    
    // MARK: - Sub Tab Picker
    @ViewBuilder
    private var subTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(BookmarkSubTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedSubTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.systemImage).font(.footnote)
                        Text(tab.rawValue)
                            .font(.footnote)
                            .fontWeight(selectedSubTab == tab ? .semibold : .regular)
                    }
                    .foregroundColor(selectedSubTab == tab ? .white : .primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSubTab == tab ? Color.mintAccent : Color.clear)
                    )
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}



// MARK: - Bookmark Lists View

struct BookmarkListsView: View {
    @Environment(BookmarkManager.self) var bookmarkManager
    @Environment(AppRouter.self) var router
    
    var body: some View {
        LazyVStack(spacing: 12) {
            if bookmarkManager.bookmarkLists.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No lists yet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Organize your bookmarks into lists")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        router.navigateTo(.bookmarkListManagement)
                    } label: {
                        Label("Create List", systemImage: "plus")
                            .font(.footnote)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.mintAccent)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 60)
                .frame(maxWidth: .infinity)
            } else {
                // Lists
                ForEach(bookmarkManager.bookmarkLists, id: \.uri) { list in
                    BookmarkListRow(list: list)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 8)
    }
}


// MARK: - Bookmark List Row

struct BookmarkListRow: View {
    let list: BookmarkListView
    @Environment(AppRouter.self) var router
    
    var body: some View {
        Button {
            // Navigate to list detail - for now just show management
            router.navigateTo(.bookmarkListManagement)
        } label: {
            HStack {
                // Icon
                Image(systemName: iconForList(list.record.icon))
                    .font(.title3)
                    .foregroundColor(Color(hex: list.record.color ?? "#007AFF"))
                    .frame(width: 40, height: 40)
                    .background(
                        Color(hex: list.record.color ?? "#007AFF").opacity(0.1)
                    )
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.record.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let description = list.record.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Bookmark count
                if let count = list.bookmarkCount, count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func iconForList(_ icon: BookmarkListIcon?) -> String {
        switch icon {
        case .folder:
            return "folder.fill"
        case .list:
            return "list.bullet"
        case .star:
            return "star.fill"
        case .tag:
            return "tag.fill"
        case nil:
            return "folder.fill"
        }
    }
}
