//
//  NewsDetailView.swift
//  Limit
//
//  Created by Claude
//

import SwiftUI

struct NewsDetailView: View {
    let urlString: String
    @State private var urlDetail: URLDetailResponse?
    @State private var recentPosts: [TimelinePostWrapper] = []
    @State private var isLoading = true
    @State private var postsLoading = false
    @State private var errorMessage: String?
    @State private var postsError: String?
    @Environment(AppRouter.self) private var router
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(MultiAccountClient.self) private var client
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        let colors = themeManager.colors

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                contentView
            }
            .padding()
        }
        .background(colors.backgroundPrimary)
        .navigationTitle("Article Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else if let detail = urlDetail {
            detailContentView(detail)
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(themeManager.colors.accent)
                .padding(.top, 50)
            Spacer()
        }
    }
    
    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(themeManager.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
    
    @ViewBuilder
    private func detailContentView(_ detail: URLDetailResponse) -> some View {
        // Show posts or loading/error state
        postsContentView
        
        // Action buttons at the bottom
        actionButtons
    }
    
    @ViewBuilder
    private var postsContentView: some View {
        if postsLoading {
            HStack {
                Spacer()
                ProgressView("Loading posts...")
                    .tint(themeManager.colors.accent)
                Spacer()
            }
            .padding(.vertical, 40)
        } else if let error = postsError {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if recentPosts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(themeManager.colors.accent.opacity(0.5))
                Text("No recent posts")
                    .font(.headline)
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Posts")
                    .font(.headline)
                    .foregroundColor(themeManager.colors.accent)
                
                ForEach(recentPosts, id: \.id) { post in
                    PostItemWrappedView(post: post)
                        .padding(.bottom, 8)
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                if let url = URL(string: urlString) {
                    router.navigateTo(.safari(url: url))
                }
            } label: {
                Label("Open in Browser", systemImage: "safari")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.colors.accent)
            
            Button {
                Task {
                    if let url = URL(string: urlString) {
                        await bookmarkManager.toggleBookmark(for: url, title: nil)
                    }
                }
            } label: {
                Label(isBookmarked ? "Bookmarked" : "Bookmark", 
                      systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isBookmarked ? themeManager.colors.accent : themeManager.colors.textSecondary)
        }
        .padding(.top, 8)
    }
    
    private var isBookmarked: Bool {
        if let url = URL(string: urlString) {
            return bookmarkManager.isBookmarked(url)
        }
        return false
    }
    
    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        
        let service = NewsService()
        if let response = await service.fetchURLDetail(for: urlString) {
            urlDetail = response
            
            // Load actual posts
            await loadPosts(from: response.recentPosts)
        } else {
            errorMessage = "Failed to load article details"
        }
        
        isLoading = false
    }
    
    private func loadPosts(from recentPosts: [RecentPost]) async {
        postsLoading = true
        postsError = nil
        
        // Take max 25 posts (API limit protection)
        let postsToLoad = Array(recentPosts.prefix(25))
        
        // Extract URIs from recent posts
        let uris = postsToLoad.map { $0.postUri }
        
        guard !uris.isEmpty else {
            postsLoading = false
            return
        }
        
        // Fetch actual posts using MultiAccountClient
        let fetchedPosts = await client.fetchPostWrappersByID(for: uris)
        
        if fetchedPosts.isEmpty && !uris.isEmpty {
            postsError = "Failed to load posts"
        } else {
            self.recentPosts = fetchedPosts
        }
        
        postsLoading = false
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}
