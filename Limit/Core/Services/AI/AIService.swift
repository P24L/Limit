//
//  AIService.swift
//  Limit
//
//  Created by Zdenek Indra on 05.07.2025.
//

import Foundation
import SwiftUI
import FirebaseCore
import FirebaseFunctions

@Observable
class AIService {
    private var _functions: Functions?
    private var functions: Functions {
        if _functions == nil {
            // Configure Firebase if not already configured
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
                DevLogger.shared.log("AIService.swift - functions - Firebase configured")
            }
            _functions = Functions.functions()
        }
        return _functions!
    }
    
    private var generateText: HTTPSCallable {
        return functions.httpsCallable("generateText")
    }
    
    private var summarizeURL: HTTPSCallable {
        return functions.httpsCallable("summarizeUrl")
    }
    
    var isLoading = false
    var lastError: Error?
    
    init() {
        // Firebase Functions are initialized lazily when first used
    }
    
    
    @MainActor
    func explainPost(_ postWrapper: TimelinePostWrapper) async throws -> String {
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let authorName = postWrapper.authorDisplayName ?? postWrapper.authorHandle
            let prompt = "Explain this post from Bluesky: \(authorName): \(postWrapper.text). Provide clear, concise explanations in English language."
            
            DevLogger.shared.log("AIService.swift - explainPost - starting OpenAI request")
            
            let data = ["prompt": prompt]
            let result = try await generateText.call(data)
            
            guard let responseText = result.data as? String, !responseText.isEmpty else {
                DevLogger.shared.log("AIService.swift - explainPost - empty response received")
                throw AIServiceError.emptyResponse
            }
            
            DevLogger.shared.log("AIService.swift - explainPost - request completed successfully")
            return responseText
            
        } catch {
            DevLogger.shared.log("AIService.swift - explainPost - error: \(error)")
            lastError = error
            throw error
        }
    }
    
    func summarizeURL(_ url: URL) async throws -> URLSummaryResult {
        DevLogger.shared.log("AIService.swift - summarizeURL - starting request for \(url)")
        
        do {
            let data = ["url": url.absoluteString]
            let result = try await summarizeURL.call(data)
            
            guard let responseData = result.data as? [String: Any] else {
                DevLogger.shared.log("AIService.swift - summarizeURL - invalid response format")
                throw AIServiceError.invalidResponse
            }
            
            if let error = responseData["error"] as? String {
                let details = responseData["details"] as? String ?? ""
                let fullErrorMessage = "\(error): \(details)"
                let errorType = URLSummaryErrorType.categorize(from: fullErrorMessage)
                DevLogger.shared.log("AIService.swift - summarizeURL - Firebase function error: \(fullErrorMessage) - Type: \(errorType)")
                throw AIServiceError.urlSummaryFailed(fullErrorMessage, errorType)
            }
            
            guard let summaryText = responseData["summary"] as? String,
                  let urlString = responseData["url"] as? String else {
                DevLogger.shared.log("AIService.swift - summarizeURL - missing required fields in response")
                throw AIServiceError.invalidResponse
            }
            
            let summaryResult = URLSummaryResult(
                url: urlString,
                title: responseData["title"] as? String,
                summary: summaryText,
                excerpt: responseData["excerpt"] as? String,
                wordCount: responseData["wordCount"] as? Int,
                truncated: responseData["truncated"] as? Bool ?? false
            )
            
            DevLogger.shared.log("AIService.swift - summarizeURL - request completed successfully")
            return summaryResult
            
        } catch {
            DevLogger.shared.log("AIService.swift - summarizeURL - error: \(error)")
            lastError = error
            throw error
        }
    }
}

enum URLSummaryErrorType {
    case retryable      // Network errors, timeouts, OpenAI errors
    case permanent      // Paywall, invalid URL, content extraction failed
    
    static func categorize(from errorMessage: String) -> URLSummaryErrorType {
        let message = errorMessage.lowercased()
        
        // Permanent errors - don't retry
        if message.contains("access denied") ||
           message.contains("paywall") ||
           message.contains("subscription") ||
           message.contains("unable to extract") ||
           message.contains("invalid url") ||
           message.contains("unable to access the url") ||
           message.contains("content extraction failed") {
            return .permanent
        }
        
        // Default to retryable for network issues, OpenAI errors, etc.
        return .retryable
    }
}

struct URLSummaryResult {
    let url: String
    let title: String?
    let summary: String
    let excerpt: String?
    let wordCount: Int?
    let truncated: Bool
}

enum AIServiceError: LocalizedError {
    case emptyResponse
    case networkError
    case rateLimitExceeded
    case urlSummaryFailed(String, URLSummaryErrorType)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "AI service returned empty response"
        case .networkError:
            return "Network connection error"
        case .rateLimitExceeded:
            return "Daily rate limit exceeded"
        case .urlSummaryFailed(let message, _):
            return "URL summary failed: \(message)"
        case .invalidResponse:
            return "Invalid response format from AI service"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .urlSummaryFailed(_, let errorType):
            return errorType == .retryable
        case .networkError, .emptyResponse:
            return true
        case .rateLimitExceeded, .invalidResponse:
            return false
        }
    }
}

