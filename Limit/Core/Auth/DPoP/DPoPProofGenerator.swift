//
//  DPoPProofGenerator.swift
//  Limit
//
//  Generates DPoP JWT proofs for OAuth requests
//

import Foundation
import CryptoKit
import JWTKit

/// Generates DPoP proofs for OAuth authentication
final class DPoPProofGenerator: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = DPoPProofGenerator()
    
    // MARK: - Properties
    
    private let nonceManager = DPoPNonceManager.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Generate a DPoP proof for a request
    /// - Parameters:
    ///   - keyContext: The DPoP key context containing the keypair
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - url: The full URL of the request
    ///   - accessToken: The access token (optional, for resource requests)
    /// - Returns: The DPoP proof JWT string
    func generateProof(
        keyContext: DPoPKeyContext,
        method: String,
        url: URL,
        accessToken: String? = nil
    ) async throws -> String {
        
        // Get nonce for this server if available
        let serverHost = url.host ?? "bsky.social"
        let nonce = await nonceManager.getNonce(for: serverHost)
        
        // Create header
        let header = DPoPHeader(jwk: keyContext.publicKeyJWK)
        
        // Create payload
        var payload = DPoPPayload(
            jti: UUID().uuidString,
            htm: method.uppercased(),
            htu: url.absoluteString.components(separatedBy: "?").first ?? url.absoluteString, // Remove query params
            iat: Date()
        )
        
        // Add access token hash if provided (for resource requests)
        if let accessToken = accessToken {
            payload.ath = hashAccessToken(accessToken)
        }
        
        // Add nonce if available
        if let nonce = nonce {
            payload.nonce = nonce
        }
        
        // Create and sign JWT
        let jwt = try createAndSignJWT(header: header, payload: payload, privateKey: keyContext.privateKey)
        
        // Commented out for reduced logging - uncomment for debugging
        // DevLogger.shared.log("DPoPProofGenerator - Generated proof for \(method) \(url.path), nonce: \(nonce != nil)")
        
        return jwt
    }
    
    // MARK: - Private Methods
    
    /// Hash the access token using SHA256
    private func hashAccessToken(_ token: String) -> String {
        guard let tokenData = token.data(using: .utf8) else {
            return ""
        }
        
        let hash = SHA256.hash(data: tokenData)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Create and sign the JWT
    private func createAndSignJWT(header: DPoPHeader, payload: DPoPPayload, privateKey: P256.Signing.PrivateKey) throws -> String {
        // Encode header
        let headerJSON = try JSONEncoder().encode(header)
        let headerBase64 = headerJSON.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // Encode payload
        let payloadJSON = try JSONEncoder().encode(payload)
        let payloadBase64 = payloadJSON.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // Create signature input
        let signatureInput = "\(headerBase64).\(payloadBase64)"
        guard let signatureData = signatureInput.data(using: .utf8) else {
            throw DPoPError.invalidData
        }
        
        // Sign with ES256
        let signature = try privateKey.signature(for: signatureData)
        let signatureBase64 = signature.rawRepresentation.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return "\(signatureInput).\(signatureBase64)"
    }
}

// MARK: - DPoP JWT Structures

/// DPoP JWT Header
struct DPoPHeader: Encodable {
    let typ: String = "dpop+jwt"
    let alg: String = "ES256"
    let jwk: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case typ, alg, jwk
    }
    
    // Custom encoding to handle [String: Any] dictionary
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typ, forKey: .typ)
        try container.encode(alg, forKey: .alg)
        
        // Convert jwk dictionary to JSON data then to a decodable type
        let jwkData = try JSONSerialization.data(withJSONObject: jwk)
        let jwkJSON = try JSONSerialization.jsonObject(with: jwkData) as? [String: Any] ?? [:]
        
        // Encode as a nested container
        var jwkContainer = container.nestedContainer(keyedBy: JSONCodingKey.self, forKey: .jwk)
        for (key, value) in jwkJSON {
            let codingKey = JSONCodingKey(stringValue: key)!
            if let stringValue = value as? String {
                try jwkContainer.encode(stringValue, forKey: codingKey)
            }
        }
    }
}

/// DPoP JWT Payload
struct DPoPPayload: Codable {
    let jti: String
    let htm: String
    let htu: String
    let iat: Int
    var ath: String?
    var nonce: String?
    
    init(jti: String, htm: String, htu: String, iat: Date, ath: String? = nil, nonce: String? = nil) {
        self.jti = jti
        self.htm = htm
        self.htu = htu
        self.iat = Int(iat.timeIntervalSince1970)
        self.ath = ath
        self.nonce = nonce
    }
}

/// Dynamic JSON coding key for JWK encoding
struct JSONCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Errors

enum DPoPError: LocalizedError {
    case invalidData
    case signingFailed
    case invalidJWK
    case invalidJWKData
    case missingPrivateKeyComponent
    case keyImportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data for DPoP proof generation"
        case .signingFailed:
            return "Failed to sign DPoP proof"
        case .invalidJWK:
            return "Invalid JWK structure"
        case .invalidJWKData:
            return "Invalid JWK data encoding"
        case .missingPrivateKeyComponent:
            return "Missing private key component in JWK"
        case .keyImportFailed(let reason):
            return "Key import failed: \(reason)"
        }
    }
}