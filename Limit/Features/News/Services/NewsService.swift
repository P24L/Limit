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
    @MainActor var selectedLanguage: String? = nil  // nil = all languages
    @MainActor var availableLanguages: [Language] = []
    @MainActor var isLoading = false
    @MainActor var isLoadingLanguages = false
    @MainActor var errorMessage: String?
    
    // Cache to prevent excessive API calls
    private var lastFetchTime: Date?
    private let cacheInterval: TimeInterval = 60 // 1 minute cache
    private var lastLanguagesFetchTime: Date?
    private let languagesCacheInterval: TimeInterval = 604800 // 7 days cache
    
    @MainActor
    init() {
        // Load saved language preference
        if let savedLang = UserDefaults.standard.string(forKey: "selectedNewsLanguage") {
            self.selectedLanguage = savedLang.isEmpty ? nil : savedLang
        }
    }
    
    func fetchTrending(period: TrendingPeriod? = nil, forceRefresh: Bool = false) async {
        if let period = period {
            await MainActor.run {
                selectedPeriod = period
            }
        }
        
        // Get current period and language for API call
        let currentPeriod = await MainActor.run { selectedPeriod }
        let currentLanguage = await MainActor.run { selectedLanguage }
        
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
            // Build URL with optional language parameter
            var urlString = "\(baseURL)/api/links/trending/\(currentPeriod.rawValue)?limit=50"
            if let lang = currentLanguage {
                urlString += "&lang=\(lang)"
            }
            let url = URL(string: urlString)!
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
            
            let langInfo = currentLanguage ?? "all"
            DevLogger.shared.log("NewsService.swift - fetchTrending: Loaded \(response.urls.count) items for period \(currentPeriod.rawValue), language: \(langInfo)")
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
    
    func fetchLanguages() async {
        // Check cache
        if let lastFetch = lastLanguagesFetchTime,
           Date().timeIntervalSince(lastFetch) < languagesCacheInterval {
            let hasLanguages = await MainActor.run { !availableLanguages.isEmpty }
            if hasLanguages {
                return
            }
        }
        
        await MainActor.run {
            isLoadingLanguages = true
        }
        
        do {
            let url = URL(string: "\(baseURL)/api/links/languages")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LanguagesResponse.self, from: data)
            
            await MainActor.run {
                availableLanguages = response.languages
                isLoadingLanguages = false
            }
            lastLanguagesFetchTime = Date()
            
            DevLogger.shared.log("NewsService.swift - fetchLanguages: Loaded \(response.count) languages")
        } catch {
            await MainActor.run {
                isLoadingLanguages = false
            }
            DevLogger.shared.log("NewsService.swift - fetchLanguages ERROR: \(error.localizedDescription)")
        }
    }
    
    func setLanguage(_ language: String?) async {
        await MainActor.run {
            selectedLanguage = language
        }
        
        // Save preference
        UserDefaults.standard.set(language ?? "", forKey: "selectedNewsLanguage")
        
        // Clear cache to force refresh with new language
        lastFetchTime = nil
        
        // Fetch with new language
        await fetchTrending(forceRefresh: true)
    }
    
    func clearCache() {
        lastFetchTime = nil
        Task { @MainActor in
            trendingItems = []
        }
    }
}