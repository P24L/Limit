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
    
    @State private var searchState: SearchState = .idle
    @State private var browseMode: BrowseMode = .trends
    @State private var searchMode: SearchMode = .users
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    private var currentPickerMode: PickerMode {
        searchState == .idle ? .browse(browseMode) : .search(searchMode)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search Bluesky", text: $searchText)
                            .focused($isSearchFocused)
                            .onSubmit {
                                if !searchText.isEmpty {
                                    // TODO: Implement search functionality
                                }
                            }
                            .onChange(of: isSearchFocused) { _, newValue in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    searchState = newValue ? .active : .idle
                                }
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if searchState == .active {
                        Button("Cancel") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchText = ""
                                isSearchFocused = false
                                searchState = .idle
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Mode Picker
                HStack {
                    if searchState == .idle {
                        Picker("Mode", selection: $browseMode) {
                            ForEach(BrowseMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    } else {
                        Picker("Mode", selection: $searchMode) {
                            ForEach(SearchMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .animation(.easeInOut(duration: 0.2), value: searchState)
                
                // Content
                Group {
                    switch searchState {
                    case .idle:
                        switch browseMode {
                        case .trends:
                            TrendsView()
                        case .suggestions:
                            SuggestionsView()
                        }
                    case .active:
                        if searchText.isEmpty {
                            Text("Start typing to search...")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            switch searchMode {
                            case .users:
                                Text("User search results for \"\(searchText)\"")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .posts:
                                Text("Post search results for \"\(searchText)\"")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: searchState)
                .animation(.easeInOut(duration: 0.2), value: browseMode)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
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