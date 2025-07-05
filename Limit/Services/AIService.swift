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
}

enum AIServiceError: LocalizedError {
    case emptyResponse
    case networkError
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "AI service returned empty response"
        case .networkError:
            return "Network connection error"
        case .rateLimitExceeded:
            return "Daily rate limit exceeded"
        }
    }
}

