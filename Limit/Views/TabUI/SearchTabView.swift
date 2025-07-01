//
//  SearchTabView.swift
//  Limit
//
//  Created by Claude on 01.07.2025.
//

import SwiftUI
import SwiftData
import AppRouter

struct SearchTabView: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(\.modelContext) var context
    @Environment(AppRouter.self) private var router
    @Environment(CurrentUser.self) private var currentUser
    @Environment(FavoriteURLManager.self) private var favoritesURL
    @Environment(FavoritePostManager.self) private var favoritesPost
    
    var body: some View {
        NavigationView {
            EmptyView()
                .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchTabView()
        .modelContainer(SampleData.shared.modelContainer)
        .environment(AppRouter(initialTab: .search))
        .environment(BlueskyClient())
        .environment(CurrentUser())
        .environment(FavoriteURLManager(context: SampleData.shared.modelContainer.mainContext))
        .environment(FavoritePostManager(context: SampleData.shared.modelContainer.mainContext))
}