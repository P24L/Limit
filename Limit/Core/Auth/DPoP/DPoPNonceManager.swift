//
//  DPoPNonceManager.swift
//  Limit
//
//  Manages DPoP nonces per server
//

import Foundation

/// Manages DPoP nonces for different servers
actor DPoPNonceManager {
    
    // MARK: - Singleton
    
    static let shared = DPoPNonceManager()
    
    // MARK: - Properties
    
    /// Nonce storage: server host -> nonce
    private var nonces: [String: String] = [:]
    
    /// Nonce expiration times
    private var nonceExpirations: [String: Date] = [:]
    
    /// Default nonce lifetime (5 minutes)
    private let nonceLifetime: TimeInterval = 300
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get the current nonce for a server
    func getNonce(for serverHost: String) -> String? {
        // Check if nonce exists and is not expired
        if let expiration = nonceExpirations[serverHost], expiration > Date() {
            return nonces[serverHost]
        }
        
        // Nonce expired or doesn't exist
        nonces.removeValue(forKey: serverHost)
        nonceExpirations.removeValue(forKey: serverHost)
        return nil
    }
    
    /// Update the nonce for a server
    func updateNonce(_ nonce: String, for serverHost: String) {
        nonces[serverHost] = nonce
        nonceExpirations[serverHost] = Date().addingTimeInterval(nonceLifetime)
        
        // DevLogger.shared.log("DPoPNonceManager - Updated nonce for \(serverHost): \(String(nonce.prefix(10)))...")
    }
    
    /// Clear nonce for a server
    func clearNonce(for serverHost: String) {
        nonces.removeValue(forKey: serverHost)
        nonceExpirations.removeValue(forKey: serverHost)
        
        DevLogger.shared.log("DPoPNonceManager - Cleared nonce for \(serverHost)")
    }
    
    /// Clear all nonces
    func clearAllNonces() {
        nonces.removeAll()
        nonceExpirations.removeAll()
        
        DevLogger.shared.log("DPoPNonceManager - Cleared all nonces")
    }
    
    /// Extract nonce from HTTP response
    func extractNonceFromResponse(_ response: URLResponse) async {
        guard let httpResponse = response as? HTTPURLResponse,
              let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
              let url = response.url,
              let host = url.host else {
            return
        }
        
        updateNonce(nonce, for: host)
    }
    
    /// Check if response indicates nonce error
    func isNonceError(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        // Check for use_dpop_nonce error (usually 401 with specific error)
        if httpResponse.statusCode == 401 {
            // Check if there's a new nonce in the response headers
            if httpResponse.value(forHTTPHeaderField: "DPoP-Nonce") != nil {
                return true
            }
        }
        
        return false
    }
}