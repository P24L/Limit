//
//  OAuthRefreshService.swift
//  Limit
//
//  Handles OAuth token refresh using the OAuth refresh flow
//

import Foundation

/// Service for refreshing OAuth tokens
final class OAuthRefreshService: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = OAuthRefreshService()
    
    // MARK: - Properties
    
    /// OAuth configuration
    private let authorizationServer = "https://bsky.social"
    private let tokenEndpoint = "/oauth/token"
    private let clientId = "https://auth.hyperlimit.app/client-metadata.json"
    
    /// URLSession for network requests
    private let urlSession: URLSession
    
    /// Active refresh tasks to prevent duplicate refreshes
    private var activeRefreshTasks: [UUID: Task<OAuthTokens, Error>] = [:]
    private let taskQueue = DispatchQueue(label: "com.hyperlimit.oauth.refresh", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// Refresh OAuth tokens
    /// - Parameters:
    ///   - refreshToken: The refresh token
    ///   - accountUUID: The account UUID for DPoP
    /// - Returns: New OAuth tokens
    func refreshTokens(refreshToken: String, accountUUID: UUID) async throws -> OAuthTokens {
        // Check if there's already an active refresh for this account
        if let existingTask = getActiveTask(for: accountUUID) {
            DevLogger.shared.log("OAuthRefreshService - Using existing refresh task for account: \(accountUUID)")
            return try await existingTask.value
        }
        
        // Create new refresh task
        let task = Task<OAuthTokens, Error> {
            do {
                let tokens = try await performRefresh(refreshToken: refreshToken, accountUUID: accountUUID)
                self.removeActiveTask(for: accountUUID)
                return tokens
            } catch {
                self.removeActiveTask(for: accountUUID)
                throw error
            }
        }
        
        setActiveTask(task, for: accountUUID)
        
        return try await task.value
    }
    
    // MARK: - Private Methods
    
    private func performRefresh(refreshToken: String, accountUUID: UUID) async throws -> OAuthTokens {
        DevLogger.shared.log("OAuthRefreshService - Starting token refresh for account: \(accountUUID)")
        
        // Log token details for debugging
        DevLogger.shared.log("OAuthRefreshService - Refresh token (first 20 chars): \(String(refreshToken.prefix(20)))...")
        DevLogger.shared.log("OAuthRefreshService - Authorization server: \(authorizationServer)")
        DevLogger.shared.log("OAuthRefreshService - Client ID: \(clientId)")
        
        // Build token request
        guard let url = URL(string: "\(authorizationServer)\(tokenEndpoint)") else {
            throw OAuthRefreshError.invalidURL
        }
        
        // Try refresh with retry logic for DPoP nonce
        return try await performRefreshWithRetry(
            refreshToken: refreshToken,
            accountUUID: accountUUID,
            url: url,
            maxAttempts: 2
        )
    }
    
    private func performRefreshWithRetry(
        refreshToken: String,
        accountUUID: UUID,
        url: URL,
        maxAttempts: Int,
        attempt: Int = 1
    ) async throws -> OAuthTokens {
        DevLogger.shared.log("OAuthRefreshService - Refresh attempt \(attempt) of \(maxAttempts)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // For OAuth with DPoP, we need to include DPoP proof in refresh request too
        let dpopSupported = true // This should be determined from server metadata
        
        if dpopSupported {
            // Generate DPoP proof for token endpoint
            do {
                let keyContext = try DPoPKeyContext(accountUUID: accountUUID)
                let dpopProof = try await DPoPProofGenerator.shared.generateProof(
                    keyContext: keyContext,
                    method: "POST",
                    url: url,
                    accessToken: nil // No access token for refresh request
                )
                request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
                DevLogger.shared.log("OAuthRefreshService - Added DPoP proof to refresh request")
            } catch {
                DevLogger.shared.log("OAuthRefreshService - Failed to generate DPoP proof: \(error)")
                // Continue without DPoP if generation fails
            }
        }
        
        // Build request body
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientId)
        ]
        
        guard let bodyString = components.query else {
            throw OAuthRefreshError.invalidRequestBody
        }
        
        request.httpBody = bodyString.data(using: .utf8)
        
        // Execute request
        let (data, response) = try await urlSession.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthRefreshError.invalidResponse
        }
        
        // Extract DPoP nonce if present
        if let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
           let host = url.host {
            await DPoPNonceManager.shared.updateNonce(nonce, for: host)
        }
        
        // Check status code
        guard httpResponse.statusCode == 200 else {
            // Log full error response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                DevLogger.shared.log("OAuthRefreshService - Error response: \(responseString)")
            }
            
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DevLogger.shared.log("OAuthRefreshService - Error details: \(errorData)")
                
                if let error = errorData["error"] as? String {
                    DevLogger.shared.log("OAuthRefreshService - Refresh failed with error: \(error)")
                    
                    if let errorDescription = errorData["error_description"] as? String {
                        DevLogger.shared.log("OAuthRefreshService - Error description: \(errorDescription)")
                    }
                    
                    if error == "invalid_grant" {
                        throw OAuthRefreshError.invalidGrant
                    }
                    
                    // Check for DPoP nonce error and retry
                    if error == "use_dpop_nonce" && attempt < maxAttempts {
                        DevLogger.shared.log("OAuthRefreshService - Server requires DPoP nonce, retrying with nonce")
                        // Nonce has already been saved by extractNonceFromResponse above
                        // Retry the request
                        return try await performRefreshWithRetry(
                            refreshToken: refreshToken,
                            accountUUID: accountUUID,
                            url: url,
                            maxAttempts: maxAttempts,
                            attempt: attempt + 1
                        )
                    }
                }
            }
            
            DevLogger.shared.log("OAuthRefreshService - HTTP error: \(httpResponse.statusCode)")
            throw OAuthRefreshError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        
        // Calculate expiration
        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn ?? 3600))
        
        DevLogger.shared.log("OAuthRefreshService - Token refresh successful, new token expires at: \(expiresAt)")
        
        // Note: We need to get handle and DID from somewhere
        // For now, we'll need to pass them through or get from existing tokens
        // This is a limitation we need to address
        
        return OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken, // Use old refresh token if new one not provided
            handle: "", // Will be filled by caller
            did: "", // Will be filled by caller
            pds: "", // Will be filled by caller with correct PDS
            dpopKey: nil, // DPoP key doesn't change during refresh
            expiresAt: expiresAt
        )
    }
    
    // MARK: - Task Management (Thread-Safe)
    
    private func getActiveTask(for accountUUID: UUID) -> Task<OAuthTokens, Error>? {
        taskQueue.sync {
            activeRefreshTasks[accountUUID]
        }
    }
    
    private func setActiveTask(_ task: Task<OAuthTokens, Error>, for accountUUID: UUID) {
        taskQueue.async(flags: .barrier) {
            self.activeRefreshTasks[accountUUID] = task
        }
    }
    
    private func removeActiveTask(for accountUUID: UUID) {
        taskQueue.async(flags: .barrier) {
            self.activeRefreshTasks.removeValue(forKey: accountUUID)
        }
    }
}

// MARK: - OAuth Token Response

struct OAuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Errors

enum OAuthRefreshError: LocalizedError {
    case invalidURL
    case invalidRequestBody
    case invalidResponse
    case invalidGrant
    case httpError(Int)
    case missingTokens
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OAuth token endpoint URL"
        case .invalidRequestBody:
            return "Failed to build refresh request body"
        case .invalidResponse:
            return "Invalid response from OAuth server"
        case .invalidGrant:
            return "Refresh token is invalid or expired"
        case .httpError(let code):
            return "OAuth refresh failed with HTTP \(code)"
        case .missingTokens:
            return "Missing required tokens in response"
        }
    }
}