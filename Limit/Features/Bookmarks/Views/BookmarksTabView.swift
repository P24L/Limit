//
//  BookmarksTabView.swift
//  Limit
//
//  Created by Assistant on 06.01.2025.
//

import SwiftUI
import SwiftData
import UIKit

struct BookmarksTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var selectedSubTab: BookmarkSubTab = .saved
    @State private var searchText = ""
    @State private var selectedListUri: String?
    @State private var selectedListName: String?
    
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
        let colors = themeManager.colors

        Group {
            switch selectedSubTab {
            case .saved:
                SavedBookmarksListView(
                    searchText: $searchText,
                    filterListUri: selectedListUri,
                    filterListName: selectedListName
                )
            case .lists:
                BookmarkListsView(
                    selectedListUri: $selectedListUri,
                    selectedListName: $selectedListName,
                    selectedSubTab: $selectedSubTab
                )
            }
        }
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText, 
            prompt: selectedListName != nil ? "Search in \(selectedListName!)" : "Search bookmarks"
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if selectedListUri != nil {
                    Button {
                        selectedListUri = nil
                        selectedListName = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.footnote)
                            Text("Clear filter")
                                .font(.footnote)
                        }
                        .foregroundColor(colors.accent)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    router.presentedSheet = .bookmarkEdit(id: nil)
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(colors.accent)
                }
            }
        }
        .safeAreaInset(edge: .top) { subTabPicker }
        .onAppear {
            applySearchAppearance(colors: colors, placeholder: currentSearchPlaceholder())
        }
        .onChange(of: themeManager.paletteID) { _, _ in
            applySearchAppearance(colors: themeManager.colors, placeholder: currentSearchPlaceholder())
        }
        .onChange(of: themeManager.colorScheme) { _, _ in
            applySearchAppearance(colors: themeManager.colors, placeholder: currentSearchPlaceholder())
        }
        .onChange(of: selectedListName) { _, _ in
            applySearchAppearance(colors: themeManager.colors, placeholder: currentSearchPlaceholder())
        }
    }
    
    // MARK: - Sub Tab Picker
    @ViewBuilder
    private var subTabPicker: some View {
        let colors = themeManager.colors
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
                    .foregroundColor(selectedSubTab == tab ? Color.white : colors.textPrimary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSubTab == tab ? colors.accent : Color.clear)
                    )
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colors.backgroundSecondary)
        )
        .padding(.horizontal, 16)
        .padding(.top, 0)
        .padding(.bottom, 0)
    }
}

// MARK: - Search Appearance Helpers
extension BookmarksTabView {
    private func currentSearchPlaceholder() -> String {
        if let name = selectedListName {
            return "Search in \(name)"
        }
        return "Search bookmarks"
    }

    private func applySearchAppearance(colors: ThemeColors, placeholder: String) {
        let searchField = UISearchTextField.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        searchField.backgroundColor = UIColor(colors.backgroundSecondary)
        searchField.textColor = UIColor(colors.textPrimary)
        searchField.tintColor = UIColor(colors.accent)
        searchField.clearButtonMode = .whileEditing
        searchField.layer.cornerRadius = 10
        searchField.layer.masksToBounds = true
        searchField.layer.borderColor = UIColor(colors.border.opacity(0.3)).cgColor
        let displayScale = max(searchField.traitCollection.displayScale, 1)
        searchField.layer.borderWidth = 1 / displayScale
        searchField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(colors.textSecondary)
            ]
        )
    }
}



// MARK: - Bookmark Lists View

struct BookmarkListsView: View {
    @Environment(BookmarkManager.self) var bookmarkManager
    @Environment(AppRouter.self) var router
    @Environment(ThemeManager.self) private var themeManager
    
    @Binding var selectedListUri: String?
    @Binding var selectedListName: String?
    @Binding var selectedSubTab: BookmarksTabView.BookmarkSubTab
    
    var body: some View {
        ScrollView {
            let colors = themeManager.colors
            LazyVStack(spacing: 12) {
                if bookmarkManager.bookmarkLists.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(colors.textSecondary)
                    
                    Text("No lists yet")
                        .font(.headline)
                        .foregroundColor(colors.textPrimary)
                    
                    Text("Organize your bookmarks into lists")
                        .font(.subheadline)
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        router.navigateTo(.bookmarkListManagement)
                    } label: {
                        Label("Create List", systemImage: "plus")
                            .font(.footnote)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(colors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 60)
                .frame(maxWidth: .infinity)
            } else {
                    // Lists - sorted by pinned status then alphabetically
                    let sortedLists = bookmarkManager.bookmarkLists.sorted { list1, list2 in
                        let isPinned1 = list1.record.pinned ?? false
                        let isPinned2 = list2.record.pinned ?? false
                        
                        if isPinned1 != isPinned2 {
                            return isPinned1 // pinned first
                        }
                        
                        return list1.record.name.localizedCaseInsensitiveCompare(list2.record.name) == .orderedAscending
                    }
                    
                    ForEach(sortedLists, id: \.uri) { list in
                        BookmarkListRow(
                            list: list,
                            selectedListUri: $selectedListUri,
                            selectedListName: $selectedListName,
                            selectedSubTab: $selectedSubTab
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}


// MARK: - Bookmark List Row

struct BookmarkListRow: View {
    let list: BookmarkListView
    @Environment(AppRouter.self) var router
    @Environment(ThemeManager.self) private var themeManager
    
    @Binding var selectedListUri: String?
    @Binding var selectedListName: String?
    @Binding var selectedSubTab: BookmarksTabView.BookmarkSubTab
    
    var body: some View {
        let colors = themeManager.colors

        Button {
            // Set filter and switch to saved tab
            selectedListUri = list.uri
            selectedListName = list.record.name
            selectedSubTab = .saved
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
                    HStack(spacing: 4) {
                        if list.record.pinned ?? false {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(colors.accent)
                        }
                        Text(list.record.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(colors.textPrimary)
                    }
                    
                    if let description = list.record.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Bookmark count
                if let count = list.bookmarkCount, count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(colors.backgroundSecondary.opacity(0.6))
                        .cornerRadius(8)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(colors.textSecondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(colors.backgroundSecondary)
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
