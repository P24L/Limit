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
    
    let initialQuery: String?
    let initialMode: SearchMode?
    
    @State private var searchState: SearchState = .idle
    @State private var browseMode: BrowseMode = .trends
    @State private var searchMode: SearchMode = .users
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    init(initialQuery: String? = nil, initialMode: SearchMode? = nil) {
        self.initialQuery = initialQuery
        self.initialMode = initialMode
    }
    
    private let searchDebounceTime: TimeInterval = 0.5
    
    private var currentPickerMode: PickerMode {
        searchState == .idle ? .browse(browseMode) : .search(searchMode)
    }
    
    private var shouldShowSearchResults: Bool {
        !searchText.isEmpty || isSearchFocused
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // Search Bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search Bluesky", text: $searchText)
                            .focused($isSearchFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                if !searchText.isEmpty {
                                    debouncedSearchText = searchText
                                }
                            }
                            .onChange(of: isSearchFocused) { _, newValue in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    updateSearchState()
                                }
                            }
                            .onChange(of: searchText) { _, newValue in
                                updateSearchState()
                                Task {
                                    try await Task.sleep(nanoseconds: UInt64(searchDebounceTime * 1_000_000_000))
                                    if searchText == newValue && !newValue.isEmpty {
                                        debouncedSearchText = newValue
                                    } else if newValue.isEmpty {
                                        debouncedSearchText = ""
                                    }
                                }
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if shouldShowSearchResults {
                        Button("Cancel") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchText = ""
                                debouncedSearchText = ""
                                isSearchFocused = false
                                updateSearchState()
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Mode Picker
                HStack {
                    if !shouldShowSearchResults {
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
                .animation(.easeInOut(duration: 0.2), value: shouldShowSearchResults)
                
                // Content
                Group {
                    if !shouldShowSearchResults {
                        switch browseMode {
                        case .trends:
                            TrendsView()
                        case .suggestions:
                            SuggestionsView()
                        }
                    } else {
                        if debouncedSearchText.isEmpty {
                            Text("Start typing to search...")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            switch searchMode {
                            case .users:
                                UsersSearchView(query: debouncedSearchText)
                            case .posts:
                                PostsSearchView(query: debouncedSearchText)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: shouldShowSearchResults)
                .animation(.easeInOut(duration: 0.2), value: browseMode)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Set initial values if provided
            if let query = initialQuery {
                searchText = query
                debouncedSearchText = query
                // Don't set focus when navigating from tag - just activate search state
                updateSearchState()
            }
            if let mode = initialMode {
                searchMode = mode
            }
        }
    }
    
    private func updateSearchState() {
        searchState = shouldShowSearchResults ? .active : .idle
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