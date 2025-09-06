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
            if newsService.isLoading && newsService.trendingItems.isEmpty {
                Spacer()
                ProgressView()
                    .tint(.mintAccent)
                    .scaleEffect(1.2)
                Spacer()
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
                .id(newsService.selectedPeriod)
                .overlay(alignment: .center) {
                    if newsService.isLoading {
                        ProgressView()
                            .tint(.mintAccent)
                            .scaleEffect(1.0)
                    }
                }
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
                                    newsService.selectedPeriod = next
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } else {
                                // Swipe right -> previous period
                                if let prev = newsService.selectedPeriod.previous {
                                    newsService.selectedPeriod = prev
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                await newsService.fetchTrending(period: newValue, forceRefresh: true)
            }
        }
    }
}
