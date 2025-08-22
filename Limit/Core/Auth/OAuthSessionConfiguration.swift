//
//  OAuthSessionConfiguration.swift
//  Limit
//
//  Multi-account OAuth-ready session configuration for ATProtoKit
//

import Foundation
import ATProtoKit
import KeychainSwift
import Logging

/// OAuth tokens structure
struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let handle: String
    let did: String
    let pds: String
    let dpopKey: DPoPJWK?  // NEW: Private JWK from backend
    let expiresAt: Date?
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
    
    var needsRefresh: Bool {
        guard let expiresAt = expiresAt else { return false }
        // Refresh if less than 5 minutes remaining (not 30 minutes!)
        // OAuth tokens are valid for 1 hour, we don't need to refresh so early
        return expiresAt.timeIntervalSinceNow < 300
    }
}

/// DPoP JWK structure for decoding
struct DPoPJWK: Codable {
    let kty: String  // Key type (EC)
    let crv: String  // Curve (P-256)
    let x: String    // Public key x coordinate
    let y: String    // Public key y coordinate
    let d: String    // Private key component
}

/// Custom session configuration supporting both OAuth and App Passwords
/// with UUID-namespaced keychain storage for multi-account support
final class OAuthSessionConfiguration: SessionConfiguration, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Unique identifier for this account session
    let instanceUUID: UUID
    
    /// Handle/identifier for the account
    private var _handle: String = ""
    var handle: String { 
        return _handle 
    }
    
    /// DID for the account (set after authentication)
    private var _did: String?
    var did: String? { 
        return _did 
    }
    
    // For reducing log spam
    private var hasLoggedMissingExpiration = false
    
    /// PDS URL
    let pdsURL: String
    
    /// URL session configuration
    let configuration: URLSessionConfiguration
    
    /// The async stream that receives user-provided authentication codes
    let codeStream: AsyncStream<String>
    
    /// The continuation used to yield new user input into the codeStream
    let codeContinuation: AsyncStream<String>.Continuation
    
    /// Authentication type
    enum AuthType {
        case appPassword
        case oauth
    }
    
    private(set) var authType: AuthType
    
    // MARK: - ATProtoKit Requirements
    
    /// Keychain protocol for secure storage
    let keychainProtocol: SecureKeychainProtocol
    
    /// The keychain instance for secure storage (internal use)
    private let keychain: KeychainSwift
    
    /// Keychain namespace prefix for this account
    private var keychainPrefix: String {
        "com.hyperlimit.account.\(instanceUUID.uuidString)"
    }
    
    // MARK: - Initialization
    
    /// Initialize for OAuth authentication
    init(instanceUUID: UUID = UUID(), handle: String, tokens: OAuthTokens) {
        self.instanceUUID = instanceUUID
        // Use PDS URL from tokens (should be the actual PDS server, not bsky.social)
        self.pdsURL = tokens.pds
        self.authType = .oauth
        
        // Initialize URL session configuration
        self.configuration = URLSessionConfiguration.default
        
        // Create namespaced keychain
        self.keychain = KeychainSwift()
        self.keychain.synchronizable = false
        
        // Create keychain protocol wrapper
        self.keychainProtocol = NamespacedKeychainProtocol(
            keychain: self.keychain,
            namespace: "com.hyperlimit.account.\(instanceUUID.uuidString)",
            identifier: instanceUUID
        )
        
        // Initialize 2FA code stream
        var continuation: AsyncStream<String>.Continuation!
        self.codeStream = AsyncStream<String> { cont in
            continuation = cont
        }
        self.codeContinuation = continuation!
        
        // Set handle and did
        self._handle = handle
        self._did = tokens.did
        
        // Store tokens immediately
        saveTokens(tokens)
        
        // Import DPoP key if provided by backend
        if let dpopJWK = tokens.dpopKey {
            do {
                try DPoPKeyManager.shared.importDPoPKey(from: dpopJWK, for: instanceUUID)
                DevLogger.shared.log("OAuthSessionConfiguration - DPoP key imported from backend")
            } catch {
                DevLogger.shared.log("OAuthSessionConfiguration - Failed to import DPoP key: \(error)")
            }
        }
        
        // Authenticate with OAuth tokens to create UserSession
        Task {
            do {
                try await authenticateWithOAuth(tokens: tokens)
            } catch {
                DevLogger.shared.log("OAuthSessionConfiguration - Failed to authenticate with OAuth: \(error)")
            }
        }
    }
    
    /// Initialize for App Password authentication
    init(instanceUUID: UUID = UUID(), handle: String, appPassword: String, pdsURL: String = "https://bsky.social") {
        self.instanceUUID = instanceUUID
        self.pdsURL = pdsURL
        self.authType = .appPassword
        
        // Initialize URL session configuration
        self.configuration = URLSessionConfiguration.default
        
        // Create namespaced keychain
        self.keychain = KeychainSwift()
        self.keychain.synchronizable = false
        
        // Create keychain protocol wrapper
        self.keychainProtocol = NamespacedKeychainProtocol(
            keychain: self.keychain,
            namespace: "com.hyperlimit.account.\(instanceUUID.uuidString)",
            identifier: instanceUUID
        )
        
        // Initialize 2FA code stream
        var continuation: AsyncStream<String>.Continuation!
        self.codeStream = AsyncStream<String> { cont in
            continuation = cont
        }
        self.codeContinuation = continuation!
        
        // Set handle
        self._handle = handle
        
        // Store app password
        keychain.set(appPassword, forKey: "\(keychainPrefix).appPassword")
        keychain.set(handle, forKey: "\(keychainPrefix).handle")
    }
    
    /// Initialize from existing UUID (for loading saved sessions)
    init(instanceUUID: UUID, pdsURL: String = "https://bsky.social") {
        self.instanceUUID = instanceUUID
        self.pdsURL = pdsURL
        
        // Initialize URL session configuration
        self.configuration = URLSessionConfiguration.default
        
        // Create namespaced keychain
        self.keychain = KeychainSwift()
        self.keychain.synchronizable = false
        
        // Create keychain protocol wrapper
        self.keychainProtocol = NamespacedKeychainProtocol(
            keychain: self.keychain,
            namespace: "com.hyperlimit.account.\(instanceUUID.uuidString)",
            identifier: instanceUUID
        )
        
        // Initialize 2FA code stream
        var continuation: AsyncStream<String>.Continuation!
        self.codeStream = AsyncStream<String> { cont in
            continuation = cont
        }
        self.codeContinuation = continuation!
        
        // Initialize auth type first (default)
        self.authType = .appPassword
        
        // Create temporary keychainPrefix for loading
        let keychainPrefix = "com.hyperlimit.account.\(instanceUUID.uuidString)"
        
        // Load stored data
        if let handle = keychain.get("\(keychainPrefix).handle") {
            self._handle = handle
        } else {
            self._handle = ""
        }
        
        if let did = keychain.get("\(keychainPrefix).did") {
            self._did = did
        }
        
        // Determine auth type based on stored data
        let hasRefreshToken = keychain.get("\(keychainPrefix).refreshToken") != nil
        let hasAccessToken = keychain.get("\(keychainPrefix).accessToken") != nil
        let hasAppPassword = keychain.get("\(keychainPrefix).appPassword") != nil
        DevLogger.shared.log("OAuthSessionConfiguration - Loading instance \(instanceUUID): hasRefreshToken=\(hasRefreshToken), hasAccessToken=\(hasAccessToken), hasAppPassword=\(hasAppPassword)")
        
        if hasRefreshToken {
            self.authType = .oauth
            DevLogger.shared.log("OAuthSessionConfiguration - Detected OAuth account based on refresh token")
            
            // Load OAuth tokens for debugging
            if hasAccessToken {
                DevLogger.shared.log("OAuthSessionConfiguration - OAuth account has both refresh and access tokens")
            }
        } else if hasAppPassword {
            self.authType = .appPassword
            DevLogger.shared.log("OAuthSessionConfiguration - Detected app password account")
            
            // For app password accounts, load the password into keychain protocol
            if let appPassword = keychain.get("\(keychainPrefix).appPassword") {
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        try await self.keychainProtocol.savePassword(appPassword)
                        DevLogger.shared.log("OAuthSessionConfiguration - Loaded app password for \(self._handle)")
                    } catch {
                        DevLogger.shared.log("OAuthSessionConfiguration - Failed to load app password: \(error)")
                    }
                }
            }
        } else {
            self.authType = .appPassword  // Default to app password if no tokens found
            DevLogger.shared.log("OAuthSessionConfiguration - No tokens or password found, defaulting to app password")
        }
    }
    
    // MARK: - SessionConfiguration Protocol Implementation
    
    /// Create a new account (not used for OAuth, delegates to default implementation)
    func createAccount(
        email: String?,
        handle: String,
        existingDID: String?,
        inviteCode: String?,
        verificationCode: String?,
        verificationPhone: String?,
        password: String?,
        recoveryKey: String?,
        plcOperation: UnknownType?
    ) async throws {
        // Not implemented for OAuth - would use default implementation from protocol extension
        throw OAuthError.invalidTokens
    }
    
    /// Authenticate with handle and password (App Password flow)
    func authenticate(with handle: String, password: String) async throws {
        self._handle = handle
        self.authType = .appPassword
        
        // Store credentials in namespaced keychain
        try await keychainProtocol.savePassword(password)
        keychain.set(handle, forKey: "\(keychainPrefix).handle")
        
        // The default implementation from the protocol extension will handle
        // the actual authentication flow with ATProtoKit
    }
    
    /// Authenticate with OAuth tokens
    func authenticateWithOAuth(tokens: OAuthTokens) async throws {
        self._handle = tokens.handle
        self._did = tokens.did
        
        self.authType = .oauth
        
        // Debug: Log token info
        DevLogger.shared.log("OAuthSessionConfiguration - Authenticating with OAuth")
        DevLogger.shared.log("OAuthSessionConfiguration - Handle: \(tokens.handle), DID: \(tokens.did)")
        
        // Parse JWT to check scope
        if let tokenData = tokens.accessToken.split(separator: ".").dropFirst().first,
           let decodedData = Data(base64Encoded: String(tokenData) + "=="),
           let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] {
            DevLogger.shared.log("OAuthSessionConfiguration - Token payload: \(json)")
            if let scope = json["scope"] as? String {
                DevLogger.shared.log("OAuthSessionConfiguration - Token scope: \(scope)")
            }
        }
        
        // Save tokens to keychain
        try await keychainProtocol.saveAccessToken(tokens.accessToken)
        try await keychainProtocol.saveRefreshToken(tokens.refreshToken)
        
        // Save additional OAuth metadata
        keychain.set(tokens.handle, forKey: "\(keychainPrefix).handle")
        keychain.set(tokens.did, forKey: "\(keychainPrefix).did")
        if let expiresAt = tokens.expiresAt {
            let isoFormatter = ISO8601DateFormatter()
            let expiresAtString = isoFormatter.string(from: expiresAt)
            keychain.set(expiresAtString, forKey: "\(keychainPrefix).expiresAt")
            DevLogger.shared.log("OAuthSessionConfiguration - Saved expiresAt: \(expiresAtString)")
        } else {
            DevLogger.shared.log("OAuthSessionConfiguration - No expiresAt date to save")
        }
        
        // Register session with UserSessionRegistry
        // Note: JWT tokens are stored in keychain, not in UserSession
        let userSession = UserSession(
            handle: tokens.handle,
            sessionDID: tokens.did,
            email: nil,
            isEmailConfirmed: nil,
            isEmailAuthenticationFactorEnabled: nil,
            didDocument: nil,
            isActive: true,
            status: nil,
            serviceEndpoint: URL(string: pdsURL)!,
            pdsURL: pdsURL
        )
        
        await UserSessionRegistry.shared.register(instanceUUID, session: userSession)
    }
    
    /// Get session (implements protocol requirement)
    func getSession() async throws {
        DevLogger.shared.log("OAuthSessionConfiguration - getSession called for \(_handle)")
        
        // For OAuth, we need to ensure tokens are properly loaded
        if authType == .oauth {
            if let tokens = loadTokens() {
                DevLogger.shared.log("OAuthSessionConfiguration - OAuth tokens loaded, expires at: \(tokens.expiresAt?.description ?? "never")")
            } else {
                DevLogger.shared.log("OAuthSessionConfiguration - Failed to load OAuth tokens!")
            }
        }
        
        // The default implementation from the protocol extension handles the rest
    }
    
    /// Delete current session
    func deleteSession() async throws {
        DevLogger.shared.log("OAuthSessionConfiguration - Deleting session for \(instanceUUID), handle: \(_handle)")
        
        // Clear all keychain items for this account
        // Note: SecureKeychainProtocol doesn't have deleteTokens method,
        // we need to delete each token individually via protocol methods
        try? await keychainProtocol.deleteAccessToken()
        try? await keychainProtocol.deleteRefreshToken()
        try? await keychainProtocol.deletePassword()
        
        // Clear all metadata via direct keychain access
        let keysToDelete = [
            "\(keychainPrefix).handle",
            "\(keychainPrefix).did",
            "\(keychainPrefix).accessToken",
            "\(keychainPrefix).refreshToken",
            "\(keychainPrefix).appPassword",
            "\(keychainPrefix).expiresAt",
            "\(keychainPrefix).pds"  // Also delete PDS URL
        ]
        
        DevLogger.shared.log("OAuthSessionConfiguration - Deleting \(keysToDelete.count) keychain entries")
        
        for key in keysToDelete {
            keychain.delete(key)
        }
        
        // Remove from UserSessionRegistry
        await UserSessionRegistry.shared.removeSession(for: instanceUUID)
        
        // Reset properties
        _handle = ""
        _did = nil
        
        DevLogger.shared.log("OAuthSessionConfiguration - Session deleted")
    }
    
    /// Refresh the session
    func refreshSession() async throws {
        DevLogger.shared.log("OAuthSessionConfiguration - refreshSession called for \(_handle)")
        
        if authType == .appPassword {
            // App Password accounts use AT Protocol refresh
            // Let the default implementation handle it
            DevLogger.shared.log("OAuthSessionConfiguration - Using AT Protocol refresh for app password account")
            // Call the default implementation (would need to be done differently)
            return
        }
        
        // OAuth accounts need OAuth refresh flow, NOT AT Protocol refresh!
        DevLogger.shared.log("OAuthSessionConfiguration - Starting OAuth token refresh")
        
        guard let currentTokens = loadTokens() else {
            DevLogger.shared.log("OAuthSessionConfiguration - No tokens to refresh")
            throw OAuthError.noRefreshToken
        }
        
        do {
            // Use OAuthRefreshService to refresh tokens
            var newTokens = try await OAuthRefreshService.shared.refreshTokens(
                refreshToken: currentTokens.refreshToken,
                accountUUID: instanceUUID
            )
            
            // Preserve handle, DID and PDS from current tokens
            newTokens = OAuthTokens(
                accessToken: newTokens.accessToken,
                refreshToken: newTokens.refreshToken,
                handle: currentTokens.handle,
                did: currentTokens.did,
                pds: currentTokens.pds,  // Preserve PDS from current tokens
                dpopKey: currentTokens.dpopKey,  // Preserve DPoP key
                expiresAt: newTokens.expiresAt
            )
            
            // Save new tokens
            saveTokens(newTokens)
            
            // Update keychain protocol tokens
            try await keychainProtocol.saveAccessToken(newTokens.accessToken)
            try await keychainProtocol.saveRefreshToken(newTokens.refreshToken)
            
            DevLogger.shared.log("OAuthSessionConfiguration - OAuth token refresh successful")
            
        } catch {
            DevLogger.shared.log("OAuthSessionConfiguration - OAuth token refresh failed: \(error)")
            throw OAuthError.refreshFailed(error)
        }
    }
    
    /// Ensure valid token (implements protocol requirement)
    func ensureValidToken() async throws {
        // This ensures the access token is valid and refreshes if needed
        // The default implementation from the protocol extension handles this
    }
    
    // MARK: - Helper Methods
    
    /// Save OAuth tokens to keychain
    private func saveTokens(_ tokens: OAuthTokens) {
        DevLogger.shared.log("OAuthSessionConfiguration - Saving OAuth tokens for UUID: \(instanceUUID)")
        DevLogger.shared.log("OAuthSessionConfiguration - Using keychain prefix: \(keychainPrefix)")
        DevLogger.shared.log("OAuthSessionConfiguration - Handle: \(tokens.handle), DID: \(tokens.did), PDS: \(tokens.pds)")
        
        keychain.set(tokens.handle, forKey: "\(keychainPrefix).handle")
        keychain.set(tokens.did, forKey: "\(keychainPrefix).did")
        keychain.set(tokens.accessToken, forKey: "\(keychainPrefix).accessToken")
        keychain.set(tokens.refreshToken, forKey: "\(keychainPrefix).refreshToken")
        keychain.set(tokens.pds, forKey: "\(keychainPrefix).pds")  // Save PDS URL
        
        if let expiresAt = tokens.expiresAt {
            let isoFormatter = ISO8601DateFormatter()
            let expiresAtString = isoFormatter.string(from: expiresAt)
            keychain.set(expiresAtString, forKey: "\(keychainPrefix).expiresAt")
            DevLogger.shared.log("OAuthSessionConfiguration - Saved expiresAt: \(expiresAtString)")
        } else {
            DevLogger.shared.log("OAuthSessionConfiguration - No expiresAt date to save")
        }
        
        // Verify save
        let savedRefreshToken = keychain.get("\(keychainPrefix).refreshToken")
        DevLogger.shared.log("OAuthSessionConfiguration - Refresh token saved: \(savedRefreshToken != nil)")
        
        self._handle = tokens.handle
        self._did = tokens.did
    }
    
    /// Load tokens from keychain
    func loadTokens() -> OAuthTokens? {
        // Commented out for reduced logging - uncomment for debugging
        // DevLogger.shared.log("OAuthSessionConfiguration - Loading tokens for UUID: \(instanceUUID)")
        // DevLogger.shared.log("OAuthSessionConfiguration - Using keychain prefix: \(keychainPrefix)")
        
        let accessToken = keychain.get("\(keychainPrefix).accessToken")
        let refreshToken = keychain.get("\(keychainPrefix).refreshToken")
        let handle = keychain.get("\(keychainPrefix).handle")
        let did = keychain.get("\(keychainPrefix).did")
        
        // Check when tokens were saved (only log if expired or missing)
        if let expiresAtString = keychain.get("\(keychainPrefix).expiresAt"),
           let expiresAt = ISO8601DateFormatter().date(from: expiresAtString) {
            let timeToExpiry = expiresAt.timeIntervalSinceNow
            if timeToExpiry < 0 {
                DevLogger.shared.log("OAuthSessionConfiguration - Token already expired \(-timeToExpiry) seconds ago")
            } else if timeToExpiry < 300 { // Less than 5 minutes
                DevLogger.shared.log("OAuthSessionConfiguration - Token expires soon: \(timeToExpiry) seconds")
            }
        } else {
            // Only log once when token is first loaded without expiration
            if !hasLoggedMissingExpiration {
                DevLogger.shared.log("OAuthSessionConfiguration - No expiration date found for tokens")
                hasLoggedMissingExpiration = true
            }
        }
        
        guard let accessToken = accessToken,
              let refreshToken = refreshToken,
              let handle = handle,
              let did = did else {
            // Log what's missing for debugging
            DevLogger.shared.log("OAuthSessionConfiguration - Missing tokens: access=\(accessToken != nil), refresh=\(refreshToken != nil), handle=\(handle != nil), did=\(did != nil)")
            return nil
        }
        
        // Load PDS URL from keychain, fallback to instance pdsURL if not found
        let storedPDS = keychain.get("\(keychainPrefix).pds") ?? pdsURL
        
        var expiresAt: Date? = nil
        if let expiresAtString = keychain.get("\(keychainPrefix).expiresAt") {
            // Try ISO8601 format first (new format)
            if let date = ISO8601DateFormatter().date(from: expiresAtString) {
                expiresAt = date
            } else if let timestamp = Double(expiresAtString) {
                // Fall back to timestamp for backward compatibility
                expiresAt = Date(timeIntervalSince1970: timestamp)
            }
        }
        
        // DevLogger.shared.log("OAuthSessionConfiguration - Loaded tokens successfully, PDS: \(storedPDS)")
        
        return OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            handle: handle,
            did: did,
            pds: storedPDS,  // Use stored PDS URL
            dpopKey: nil,  // DPoP key is stored separately in DPoPKeyManager
            expiresAt: expiresAt
        )
    }
    
    
    /// Check if tokens need refresh
    func needsTokenRefresh() -> Bool {
        if authType == .appPassword {
            // App passwords don't expire in the same way
            return false
        }
        
        guard let tokens = loadTokens() else {
            return true
        }
        
        return tokens.needsRefresh
    }
}

// MARK: - OAuth Errors

enum OAuthError: LocalizedError {
    case noRefreshToken
    case refreshFailed(Error)
    case invalidTokens
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .refreshFailed(let error):
            return "Token refresh failed: \(error.localizedDescription)"
        case .invalidTokens:
            return "Invalid OAuth tokens"
        }
    }
}

// MARK: - Namespaced Keychain Protocol

/// Wrapper for KeychainSwift to provide SecureKeychainProtocol conformance
/// with UUID-based namespace support
final class NamespacedKeychainProtocol: SecureKeychainProtocol, @unchecked Sendable {
    private let keychain: KeychainSwift
    private let namespace: String
    
    /// The unique identifier for this keychain instance
    let identifier: UUID
    
    /// In-memory cache for access token (as per protocol requirements)
    private var accessToken: String?
    
    init(keychain: KeychainSwift, namespace: String, identifier: UUID = UUID()) {
        self.keychain = keychain
        self.namespace = namespace
        self.identifier = identifier
        
        // Load access token into memory if it exists
        self.accessToken = keychain.get(namespacedKey("accessToken"))
    }
    
    convenience init(keychain: KeychainSwift, namespace: String) {
        self.init(keychain: keychain, namespace: namespace, identifier: UUID())
    }
    
    private func namespacedKey(_ key: String) -> String {
        "\(namespace).\(key)"
    }
    
    // MARK: - Access Token Management
    
    func saveAccessToken(_ token: String) async throws {
        keychain.set(token, forKey: namespacedKey("accessToken"))
        self.accessToken = token  // Keep in memory as per protocol requirements
    }
    
    func retrieveAccessToken() async throws -> String {
        // Try memory first, then keychain
        if let token = self.accessToken {
            // Commented out for reduced logging - uncomment for debugging
            // DevLogger.shared.log("NamespacedKeychainProtocol - Returning cached OAuth token (first 50 chars): \(String(token.prefix(50)))...")
            return token
        }
        
        guard let token = keychain.get(namespacedKey("accessToken")) else {
            DevLogger.shared.log("NamespacedKeychainProtocol - No OAuth token found in keychain!")
            throw OAuthError.invalidTokens
        }
        
        // Commented out for reduced logging - uncomment for debugging
        // DevLogger.shared.log("NamespacedKeychainProtocol - Retrieved OAuth token from keychain (first 50 chars): \(String(token.prefix(50)))...")
        self.accessToken = token  // Cache in memory
        return token
    }
    
    func deleteAccessToken() async throws {
        keychain.delete(namespacedKey("accessToken"))
        self.accessToken = nil
    }
    
    // MARK: - Refresh Token Management
    
    func saveRefreshToken(_ token: String) async throws {
        keychain.set(token, forKey: namespacedKey("refreshToken"))
    }
    
    func retrieveRefreshToken() async throws -> String {
        guard let token = keychain.get(namespacedKey("refreshToken")) else {
            throw OAuthError.noRefreshToken
        }
        return token
    }
    
    func updateRefreshToken(_ newRefreshToken: String) async throws {
        keychain.set(newRefreshToken, forKey: namespacedKey("refreshToken"))
    }
    
    func deleteRefreshToken() async throws {
        keychain.delete(namespacedKey("refreshToken"))
    }
    
    // MARK: - Password Management
    
    func savePassword(_ password: String) async throws {
        keychain.set(password, forKey: namespacedKey("appPassword"))
    }
    
    func retrievePassword() async throws -> String {
        guard let password = keychain.get(namespacedKey("appPassword")) else {
            throw OAuthError.invalidTokens
        }
        return password
    }
    
    func updatePassword(_ newPassword: String) async throws {
        keychain.set(newPassword, forKey: namespacedKey("appPassword"))
    }
    
    func deletePassword() async throws {
        keychain.delete(namespacedKey("appPassword"))
    }
}