//
//  NewsView.swift
//  Limit
//
//  Created by Zdenek Indra
//

import SwiftUI
import UIKit

struct NewsView: View {
    @State private var newsService = NewsService()
    @Environment(AppRouter.self) private var router
    @Environment(\.refresh) private var refresh
    @Environment(ThemeManager.self) private var themeManager
    @State private var isTransitioning = false
    @State private var contentOpacity: Double = 1.0
    
    var body: some View {
        let colors = themeManager.colors
        VStack(spacing: 0) {
            // Period selector
            Picker("Period", selection: $newsService.selectedPeriod) {
                ForEach(TrendingPeriod.allCases, id: \.self) { period in
                    Text(period.displayName)
                        .tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(colors.backgroundSecondary)
            
            // Content
            if isTransitioning || (newsService.isLoading && newsService.trendingItems.isEmpty) {
                // Show skeleton loading for period transitions
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { _ in
                            TrendingCardSkeletonView()
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .transition(.opacity)
            } else if let error = newsService.errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(colors.textSecondary)
                    Button("Retry") {
                        Task {
                            await newsService.fetchTrending(forceRefresh: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(colors.accent)
                }
                Spacer()
            } else if newsService.trendingItems.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 60))
                        .foregroundColor(colors.accent.opacity(0.5))
                    Text("No trending articles")
                        .font(.headline)
                        .foregroundColor(colors.textSecondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Filter out items without title
                        ForEach(newsService.trendingItems.filter { $0.embedTitle != nil }) { item in
                            TrendingCardView(item: item) {
                                // Navigate to detail
                                router.navigateTo(.newsDetail(url: item.url))
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .opacity(contentOpacity)
                .animation(.easeInOut(duration: 0.3), value: contentOpacity)
                .id(newsService.selectedPeriod)
                .refreshable {
                    await newsService.fetchTrending(forceRefresh: true)
                }
                // Horizontal swipe to change period (left = next, right = previous)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            let t = value.translation
                            // Detect primarily horizontal swipe with sufficient distance
                            guard abs(t.width) > 40, abs(t.width) > abs(t.height) else { return }
                            if t.width < 0 {
                                // Swipe left -> next period
                                if let next = newsService.selectedPeriod.next {
                                    handlePeriodTransition(to: next)
                                }
                            } else {
                                // Swipe right -> previous period
                                if let prev = newsService.selectedPeriod.previous {
                                    handlePeriodTransition(to: prev)
                                }
                            }
                        }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.backgroundPrimary)
        .navigationTitle("🔥 Trending News")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                languageSelector
            }
        }
        .task {
            await newsService.fetchLanguages()
            await newsService.fetchTrending()
        }
        .onChange(of: newsService.selectedPeriod) { oldValue, newValue in
            Task {
                await handlePeriodChange(to: newValue)
            }
        }
    }
    
    private func handlePeriodTransition(to period: TrendingPeriod) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        newsService.selectedPeriod = period
    }
    
    private func handlePeriodChange(to period: TrendingPeriod) async {
        // Start transition
        withAnimation(.easeOut(duration: 0.2)) {
            isTransitioning = true
            contentOpacity = 0.3
        }
        
        // Fetch new data
        await newsService.fetchTrending(period: period, forceRefresh: true)
        
        // End transition
        withAnimation(.easeIn(duration: 0.3)) {
            isTransitioning = false
            contentOpacity = 1.0
        }
    }
    
    @ViewBuilder
    private var languageSelector: some View {
        let colors = themeManager.colors
        Menu {
            // All languages option
            Button {
                Task {
                    await newsService.setLanguage(nil)
                }
            } label: {
                Label {
                    Text("All Languages")
                } icon: {
                    if newsService.selectedLanguage == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            // Available languages
            ForEach(newsService.availableLanguages) { language in
                Button {
                    Task {
                        await newsService.setLanguage(language.lang)
                    }
                } label: {
                    Label {
                        Text(language.label)
                    } icon: {
                        if newsService.selectedLanguage == language.lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.body)
                
                Text(languageDisplayText)
                    .font(.footnote)
                    .fontWeight(.medium)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(colors.accent)
        }
        .disabled(newsService.isLoadingLanguages)
    }
    
    private var languageDisplayText: String {
        if let lang = newsService.selectedLanguage {
            return lang.uppercased()
        } else {
            return "All"
        }
    }
}
