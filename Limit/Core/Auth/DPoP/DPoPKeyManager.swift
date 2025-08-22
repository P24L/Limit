//
//  DPoPKeyManager.swift
//  Limit
//
//  Manages ES256 (P256) keypairs for DPoP authentication
//

import Foundation
import CryptoKit
import Security
import KeychainSwift

/// Manages DPoP keypairs for OAuth authentication
final class DPoPKeyManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = DPoPKeyManager()
    
    // MARK: - Properties
    
    private let keychain = KeychainSwift()
    private var keypairCache: [UUID: P256.Signing.PrivateKey] = [:]
    private let queue = DispatchQueue(label: "com.hyperlimit.dpop.keymanager", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {
        keychain.synchronizable = false
    }
    
    // MARK: - Public Methods
    
    /// Get or create a keypair for the given account
    func getOrCreateKeypair(for accountUUID: UUID) throws -> P256.Signing.PrivateKey {
        // DevLogger.shared.log("DPoPKeyManager - getOrCreateKeypair called for account: \(accountUUID)")
        
        // Check cache first
        if let cached = getCachedKeypair(for: accountUUID) {
            // DevLogger.shared.log("DPoPKeyManager - Using cached keypair for account: \(accountUUID)")
            // DevLogger.shared.log("DPoPKeyManager - Cached key exists, returning immediately")
            return cached
        }
        
        // DevLogger.shared.log("DPoPKeyManager - No cached key found, checking keychain")
        
        // Try to load from keychain
        if let privateKey = loadKeypairFromKeychain(for: accountUUID) {
            setCachedKeypair(privateKey, for: accountUUID)
            // DevLogger.shared.log("DPoPKeyManager - Loaded keypair from keychain for account: \(accountUUID)")
            // DevLogger.shared.log("DPoPKeyManager - Key successfully loaded and cached")
            return privateKey
        }
        
        DevLogger.shared.log("DPoPKeyManager - No existing keypair found, generating new one")
        
        // Generate new keypair
        let privateKey = P256.Signing.PrivateKey()
        saveKeypairToKeychain(privateKey, for: accountUUID)
        setCachedKeypair(privateKey, for: accountUUID)
        DevLogger.shared.log("DPoPKeyManager - Generated new keypair for account: \(accountUUID)")
        DevLogger.shared.log("DPoPKeyManager - New key saved to keychain and cached")
        
        return privateKey
    }
    
    /// Get the public key as a JWK dictionary
    func getPublicKeyJWK(for privateKey: P256.Signing.PrivateKey) -> [String: Any] {
        let publicKey = privateKey.publicKey
        let rawData = publicKey.rawRepresentation
        
        // Split the raw representation into x and y coordinates (32 bytes each)
        let xData = rawData.prefix(32)
        let yData = rawData.suffix(32)
        
        // Convert to base64url encoding (no padding)
        let x = xData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let y = yData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return [
            "kty": "EC",
            "crv": "P-256",
            "x": x,
            "y": y
        ]
    }
    
    /// Import DPoP key from JWK received from backend
    func importDPoPKey(from jwk: DPoPJWK, for accountUUID: UUID) throws {
        DevLogger.shared.log("DPoPKeyManager - importDPoPKey called for account: \(accountUUID)")
        DevLogger.shared.log("DPoPKeyManager - JWK kty: \(jwk.kty), crv: \(jwk.crv)")
        
        // Validate JWK structure
        guard jwk.kty == "EC" && jwk.crv == "P-256" else {
            DevLogger.shared.log("DPoPKeyManager - Invalid JWK structure: kty=\(jwk.kty), crv=\(jwk.crv)")
            throw DPoPError.invalidJWK
        }
        
        DevLogger.shared.log("DPoPKeyManager - JWK structure valid, decoding base64url components")
        
        // Decode base64url components
        guard let dData = Data(base64URLEncoded: jwk.d) else {
            DevLogger.shared.log("DPoPKeyManager - Failed to decode base64url private key component")
            throw DPoPError.invalidJWKData
        }
        
        DevLogger.shared.log("DPoPKeyManager - Private key data decoded, size: \(dData.count) bytes")
        
        // Create P256 private key from raw representation
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: dData)
        DevLogger.shared.log("DPoPKeyManager - P256 private key created successfully")
        
        // Verify that public key matches
        let publicKey = privateKey.publicKey
        let rawData = publicKey.rawRepresentation
        
        // Split the raw representation into x and y coordinates (32 bytes each)
        let xData = rawData.prefix(32)
        let yData = rawData.suffix(32)
        
        // Convert to base64url encoding for verification
        let xComputed = xData.base64URLEncodedString()
        let yComputed = yData.base64URLEncodedString()
        
        DevLogger.shared.log("DPoPKeyManager - Verifying public key components")
        DevLogger.shared.log("DPoPKeyManager - Expected x: \(jwk.x)")
        DevLogger.shared.log("DPoPKeyManager - Computed x: \(xComputed)")
        DevLogger.shared.log("DPoPKeyManager - Expected y: \(jwk.y)")
        DevLogger.shared.log("DPoPKeyManager - Computed y: \(yComputed)")
        
        // Verify that computed public key matches JWK
        guard xComputed == jwk.x && yComputed == jwk.y else {
            DevLogger.shared.log("DPoPKeyManager - Public key mismatch! x: \(xComputed) vs \(jwk.x), y: \(yComputed) vs \(jwk.y)")
            throw DPoPError.keyImportFailed("Public key does not match private key")
        }
        
        DevLogger.shared.log("DPoPKeyManager - Public key verification successful")
        
        // Save to keychain (overwrites existing if any)
        saveKeypairToKeychain(privateKey, for: accountUUID)
        setCachedKeypair(privateKey, for: accountUUID)
        
        DevLogger.shared.log("DPoPKeyManager - Imported DPoP key from JWK for account: \(accountUUID)")
        DevLogger.shared.log("DPoPKeyManager - Key successfully saved to keychain and cached")
    }
    
    /// Delete keypair for an account
    func deleteKeypair(for accountUUID: UUID) {
        let key = keychainKey(for: accountUUID)
        keychain.delete(key)
        removeCachedKeypair(for: accountUUID)
        DevLogger.shared.log("DPoPKeyManager - Deleted keypair for account: \(accountUUID)")
    }
    
    // MARK: - Private Methods
    
    private func keychainKey(for accountUUID: UUID) -> String {
        "com.hyperlimit.dpop.keypair.\(accountUUID.uuidString)"
    }
    
    private func loadKeypairFromKeychain(for accountUUID: UUID) -> P256.Signing.PrivateKey? {
        let key = keychainKey(for: accountUUID)
        // DevLogger.shared.log("DPoPKeyManager - loadKeypairFromKeychain: Attempting to load key: \(key)")
        
        guard let data = keychain.getData(key) else {
            DevLogger.shared.log("DPoPKeyManager - loadKeypairFromKeychain: No data found in keychain for key: \(key)")
            return nil
        }
        
        // DevLogger.shared.log("DPoPKeyManager - loadKeypairFromKeychain: Found data in keychain, size: \(data.count) bytes")
        
        do {
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: data)
            // DevLogger.shared.log("DPoPKeyManager - loadKeypairFromKeychain: Successfully created P256 key from keychain data")
            return privateKey
        } catch {
            DevLogger.shared.log("DPoPKeyManager - loadKeypairFromKeychain: Failed to create P256 key from keychain data: \(error)")
            return nil
        }
    }
    
    private func saveKeypairToKeychain(_ privateKey: P256.Signing.PrivateKey, for accountUUID: UUID) {
        let key = keychainKey(for: accountUUID)
        let data = privateKey.rawRepresentation
        
        DevLogger.shared.log("DPoPKeyManager - saveKeypairToKeychain: Saving key: \(key)")
        DevLogger.shared.log("DPoPKeyManager - saveKeypairToKeychain: Data size: \(data.count) bytes")
        
        let success = keychain.set(data, forKey: key)
        
        if success {
            DevLogger.shared.log("DPoPKeyManager - saveKeypairToKeychain: Successfully saved key to keychain")
        } else {
            DevLogger.shared.log("DPoPKeyManager - saveKeypairToKeychain: Failed to save key to keychain!")
        }
    }
    
    // MARK: - Cache Management (Thread-Safe)
    
    private func getCachedKeypair(for accountUUID: UUID) -> P256.Signing.PrivateKey? {
        queue.sync {
            keypairCache[accountUUID]
        }
    }
    
    private func setCachedKeypair(_ keypair: P256.Signing.PrivateKey, for accountUUID: UUID) {
        queue.async(flags: .barrier) {
            self.keypairCache[accountUUID] = keypair
        }
    }
    
    private func removeCachedKeypair(for accountUUID: UUID) {
        queue.async(flags: .barrier) {
            self.keypairCache.removeValue(forKey: accountUUID)
        }
    }
}

// MARK: - DPoP Key Context

/// Context containing DPoP keypair and related information
struct DPoPKeyContext {
    let accountUUID: UUID
    let privateKey: P256.Signing.PrivateKey
    let publicKeyJWK: [String: Any]
    
    init(accountUUID: UUID) throws {
        self.accountUUID = accountUUID
        self.privateKey = try DPoPKeyManager.shared.getOrCreateKeypair(for: accountUUID)
        self.publicKeyJWK = DPoPKeyManager.shared.getPublicKeyJWK(for: privateKey)
    }
}

// MARK: - Data Extensions

extension Data {
    /// Initialize Data from base64URL encoded string
    init?(base64URLEncoded: String) {
        var base64 = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        self.init(base64Encoded: base64)
    }
    
    /// Convert Data to base64URL encoded string
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}