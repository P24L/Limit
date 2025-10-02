// EmptySavedState.swift

import SwiftUI

struct EmptySavedState: View {
    let searchText: String
    let addAction: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let colors = themeManager.colors
        VStack(spacing: 14) {
            Image(systemName: searchText.isEmpty ? "bookmark.slash" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No bookmarks yet" : "No bookmarks found")
                .font(.headline)
            
            Text(searchText.isEmpty
                 ? "Save interesting links to find them later"
                 : "No bookmarks match \"\(searchText)\"")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button(action: addAction) {
                    Label("Add Bookmark", systemImage: "plus")
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(colors.accent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}