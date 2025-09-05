//
//  NewsService.swift
//  Limit
//
//  Created by Claude
//

import Foundation
import SwiftUI

@Observable
final class NewsService {
    private let baseURL = "https://hyperlimit-v2-tkobq.ondigitalocean.app"
    
    @MainActor var trendingItems: [TrendingURL] = []
    @MainActor var selectedPeriod: TrendingPeriod = .oneHour
    @MainActor var isLoading = false
    @MainActor var errorMessage: String?
    
    // Cache to prevent excessive API calls
    private var lastFetchTime: Date?
    private let cacheInterval: TimeInterval = 60 // 1 minute cache
    
    func fetchTrending(period: TrendingPeriod? = nil, forceRefresh: Bool = false) async {
        if let period = period {
            await MainActor.run {
                selectedPeriod = period
            }
        }
        
        // Get current period for API call
        let currentPeriod = await MainActor.run { selectedPeriod }
        
        // Check cache unless force refresh
        if !forceRefresh, let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheInterval {
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let url = URL(string: "\(baseURL)/api/links/trending/\(currentPeriod.rawValue)?limit=50")!
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Check if task was cancelled
            if Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            let response = try JSONDecoder().decode(TrendingResponse.self, from: data)
            
            await MainActor.run {
                trendingItems = response.urls
                isLoading = false
            }
            lastFetchTime = Date()
            
            DevLogger.shared.log("NewsService.swift - fetchTrending: Loaded \(response.urls.count) items for period \(currentPeriod.rawValue)")
        } catch {
            // Don't show error for cancelled tasks
            if error is CancellationError || (error as NSError).code == NSURLErrorCancelled {
                DevLogger.shared.log("NewsService.swift - fetchTrending: Request cancelled (expected during refresh)")
            } else {
                await MainActor.run {
                    errorMessage = "Failed to load trending articles"
                }
                DevLogger.shared.log("NewsService.swift - fetchTrending ERROR: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    func fetchURLDetail(for urlString: String) async -> URLDetailResponse? {
        do {
            guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw URLError(.badURL)
            }
            
            let url = URL(string: "\(baseURL)/api/links/url?url=\(encodedURL)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(URLDetailResponse.self, from: data)
            
            DevLogger.shared.log("NewsService.swift - fetchURLDetail: Loaded detail for \(urlString)")
            return response
        } catch {
            DevLogger.shared.log("NewsService.swift - fetchURLDetail ERROR: \(error.localizedDescription)")
            return nil
        }
    }
    
    func clearCache() {
        lastFetchTime = nil
        Task { @MainActor in
            trendingItems = []
        }
    }
}