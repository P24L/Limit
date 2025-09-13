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
    @State private var isTransitioning = false
    @State private var contentOpacity: Double = 1.0
    
    var body: some View {
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
            .background(Color.warmBackground)
            
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
                        .foregroundColor(.secondaryText)
                    Button("Retry") {
                        Task {
                            await newsService.fetchTrending(forceRefresh: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mintAccent)
                }
                Spacer()
            } else if newsService.trendingItems.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 60))
                        .foregroundColor(.mintAccent.opacity(0.5))
                    Text("No trending articles")
                        .font(.headline)
                        .foregroundColor(.secondaryText)
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
        .background(Color.warmBackground.opacity(0.3))
        .navigationTitle("🔥 Trending News")
        .navigationBarTitleDisplayMode(.inline)
        .task {
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
}
