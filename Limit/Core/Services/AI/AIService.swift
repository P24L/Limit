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
    private var openAIApp: FirebaseApp?
    
    private var functions: Functions {
        if _functions == nil {
            // Configure separate Firebase app for OpenAI functions
            if openAIApp == nil {
                // Load the OpenAI configuration file (GoogleService-Info.plist)
                guard let openAIConfigPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
                    DevLogger.shared.log("AIService.swift - functions - OpenAI config file not found")
                    fatalError("GoogleService-Info.plist not found for OpenAI functions")
                }
                
                guard let openAIOptions = FirebaseOptions(contentsOfFile: openAIConfigPath) else {
                    DevLogger.shared.log("AIService.swift - functions - Failed to load OpenAI config")
                    fatalError("Failed to load GoogleService-Info.plist for OpenAI functions")
                }
                
                // Override bundle ID for dev builds if needed
                let currentBundleID = Bundle.main.bundleIdentifier ?? "P24L.Limit"
                if currentBundleID.hasSuffix(".dev") {
                    openAIOptions.bundleID = currentBundleID
                    DevLogger.shared.log("AIService.swift - functions - Overriding bundle ID to: \(currentBundleID)")
                }
                
                // Check if OpenAI app already exists
                if let existingApp = FirebaseApp.app(name: "openai") {
                    openAIApp = existingApp
                    DevLogger.shared.log("AIService.swift - functions - Using existing OpenAI Firebase app")
                } else {
                    // Configure as a secondary app named "openai"
                    FirebaseApp.configure(name: "openai", options: openAIOptions)
                    openAIApp = FirebaseApp.app(name: "openai")
                    DevLogger.shared.log("AIService.swift - functions - OpenAI Firebase app configured with project: \(openAIOptions.projectID ?? "unknown")")
                }
            }
            
            // Use Functions from the OpenAI app
            if let app = openAIApp {
                _functions = Functions.functions(app: app, region: "us-central1")
                DevLogger.shared.log("AIService.swift - functions - Functions initialized with OpenAI app")
            } else {
                DevLogger.shared.log("AIService.swift - functions - Failed to get OpenAI app")
                fatalError("Failed to initialize OpenAI Firebase app")
            }
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
            let prompt = "Explain this post from Bluesky: \(authorName): \(postWrapper.text). Provide clear, concise explanations in English language. Explain area specific terms and area context. Do not use markdown."
            
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
    
    @MainActor
    func explainThread(_ posts: [TimelinePostWrapper]) async throws -> String {
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Take max 10 posts from thread
            let postsToExplain = Array(posts.prefix(10))
            
            // Build thread context
            var threadContext = "Explain this Bluesky thread conversation:\n\n"
            for (index, post) in postsToExplain.enumerated() {
                let authorName = post.authorDisplayName ?? post.authorHandle
                threadContext += "Post \(index + 1) - \(authorName): \(post.text)\n\n"
            }
            threadContext += "Provide a clear summary of the thread discussion, explain the context, key points, and any area-specific terms used. Help me understand what this conversation is about."
            
            DevLogger.shared.log("AIService.swift - explainThread - starting OpenAI request for \(postsToExplain.count) posts")
            
            let data = ["prompt": threadContext]
            let result = try await generateText.call(data)
            
            guard let responseText = result.data as? String, !responseText.isEmpty else {
                DevLogger.shared.log("AIService.swift - explainThread - empty response received")
                throw AIServiceError.emptyResponse
            }
            
            DevLogger.shared.log("AIService.swift - explainThread - request completed successfully")
            return responseText
            
        } catch {
            DevLogger.shared.log("AIService.swift - explainThread - error: \(error)")
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

