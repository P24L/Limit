//
//  DPoPRequestExecutor.swift
//  Limit
//
//  Custom request executor that adds DPoP headers to all OAuth requests
//

import Foundation
import ATProtoKit

/// Request executor that adds DPoP headers for OAuth authentication
final class DPoPRequestExecutor: ATRequestExecutor, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The account this executor is associated with
    private let accountUUID: UUID
    
    /// Session configuration for getting tokens
    private weak var sessionConfig: OAuthSessionConfiguration?
    
    /// DPoP key context for this account
    private let keyContext: DPoPKeyContext
    
    /// Proof generator
    private let proofGenerator = DPoPProofGenerator.shared
    
    /// Nonce manager
    private let nonceManager = DPoPNonceManager.shared
    
    /// URL session for executing requests
    private let urlSession: URLSession
    
    /// Maximum retry attempts for nonce errors
    private let maxRetries = 2
    
    // MARK: - Initialization
    
    init(accountUUID: UUID, sessionConfig: OAuthSessionConfiguration) throws {
        self.accountUUID = accountUUID
        self.sessionConfig = sessionConfig
        self.keyContext = try DPoPKeyContext(accountUUID: accountUUID)
        
        // Create URL session with the configuration from sessionConfig
        self.urlSession = URLSession(configuration: sessionConfig.configuration)
        
        DevLogger.shared.log("DPoPRequestExecutor - Initialized for account: \(accountUUID)")
    }
    
    // MARK: - ATRequestExecutor Implementation
    
    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Check if this is an OAuth account
        guard let config = sessionConfig, config.authType == .oauth else {
            // Not OAuth, pass through without DPoP
            DevLogger.shared.log("DPoPRequestExecutor - Non-OAuth request, passing through")
            return try await urlSession.data(for: request)
        }
        
        // Execute with retry logic for nonce errors
        return try await executeWithRetry(request, attempt: 0)
    }
    
    // MARK: - Private Methods
    
    private func executeWithRetry(_ originalRequest: URLRequest, attempt: Int) async throws -> (Data, URLResponse) {
        // Get OAuth tokens
        guard let tokens = sessionConfig?.loadTokens() else {
            DevLogger.shared.log("DPoPRequestExecutor - No OAuth tokens available")
            throw DPoPExecutorError.noTokens
        }
        
        // Check if tokens need refresh
        if tokens.needsRefresh {
            DevLogger.shared.log("DPoPRequestExecutor - Tokens need refresh")
            // Token refresh will be handled by OAuthSessionConfiguration
            try await sessionConfig?.refreshSession()
            
            // Reload tokens after refresh
            guard let refreshedTokens = sessionConfig?.loadTokens() else {
                throw DPoPExecutorError.noTokens
            }
            
            return try await executeRequest(originalRequest, with: refreshedTokens, attempt: attempt)
        }
        
        return try await executeRequest(originalRequest, with: tokens, attempt: attempt)
    }
    
    private func executeRequest(_ originalRequest: URLRequest, with tokens: OAuthTokens, attempt: Int) async throws -> (Data, URLResponse) {
        // Create mutable copy of request
        var request = originalRequest
        
        // Generate DPoP proof
        guard let url = request.url,
              let method = request.httpMethod else {
            throw DPoPExecutorError.invalidRequest
        }
        
        let dpopProof = try await proofGenerator.generateProof(
            keyContext: keyContext,
            method: method,
            url: url,
            accessToken: tokens.accessToken
        )
        
        // Add DPoP headers
        request.setValue("DPoP \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        
        // Log request details (only important ones)
        // Commented out for reduced logging - uncomment for debugging
        // DevLogger.shared.log("DPoPRequestExecutor - Executing \(method) \(url.path)")
        // DevLogger.shared.log("DPoPRequestExecutor - Authorization: DPoP (token: \(String(tokens.accessToken.prefix(20)))...)")
        // DevLogger.shared.log("DPoPRequestExecutor - DPoP proof added: \(String(dpopProof.prefix(50)))...")
        
        // Execute request
        let (data, response) = try await urlSession.data(for: request)
        
        // Extract nonce from response for future requests
        await nonceManager.extractNonceFromResponse(response)
        
        // Check for nonce error
        if await nonceManager.isNonceError(response) && attempt < maxRetries {
            DevLogger.shared.log("DPoPRequestExecutor - Nonce error detected, retrying (attempt \(attempt + 1))")
            
            // The nonce has already been extracted, retry with new nonce
            return try await executeWithRetry(originalRequest, attempt: attempt + 1)
        }
        
        // Check for other errors
        if let httpResponse = response as? HTTPURLResponse {
            // Only log non-200 responses
            if httpResponse.statusCode != 200 {
                DevLogger.shared.log("DPoPRequestExecutor - Response: \(httpResponse.statusCode) for \(url.path)")
            }
            
            if httpResponse.statusCode == 401 {
                // Log the error response for debugging
                if let errorString = String(data: data, encoding: .utf8) {
                    DevLogger.shared.log("DPoPRequestExecutor - 401 Error: \(errorString)")
                }
                
                // Check if it's a token scope error
                if errorString(data).contains("Bad token scope") {
                    DevLogger.shared.log("DPoPRequestExecutor - Bad token scope error - OAuth token may not be valid for this endpoint")
                }
            }
        }
        
        return (data, response)
    }
    
    private func errorString(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Errors

enum DPoPExecutorError: LocalizedError {
    case noTokens
    case invalidRequest
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .noTokens:
            return "No OAuth tokens available"
        case .invalidRequest:
            return "Invalid request - missing URL or method"
        case .tokenRefreshFailed:
            return "Failed to refresh OAuth token"
        }
    }
}