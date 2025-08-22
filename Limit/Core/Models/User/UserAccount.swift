//
//  UserAccount.swift
//  Limit
//
//  Created by Zdenek Indra on 20.01.2025.
//

import Foundation

/// Authentication type for the account
enum AuthType: String, Codable {
    case appPassword = "app_password"
    case oauth = "oauth"
}

struct UserAccount: Codable, Identifiable, Equatable {
    let id: UUID
    let did: String
    let handle: String
    var displayName: String
    var avatarURL: URL?
    let addedDate: Date
    var lastUsedDate: Date
    
    // Multi-account OAuth support
    let sessionUUID: UUID  // Unique identifier for keychain namespace
    var authType: AuthType
    var oauthIssuer: String? // OAuth issuer URL if using OAuth
    var tokenExpiresAt: Date? // Token expiration for OAuth
    var pdsURL: String? // URL of user's PDS server (for OAuth accounts)
    var needsReauth: Bool = false // Indicates if account needs re-authentication
    
    init(did: String, handle: String, displayName: String = "", avatarURL: URL? = nil,
         authType: AuthType = .appPassword, sessionUUID: UUID? = nil, pdsURL: String? = nil) {
        self.id = UUID()
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.addedDate = Date()
        self.lastUsedDate = Date()
        self.sessionUUID = sessionUUID ?? UUID() // Generate new UUID if not provided
        self.authType = authType
        self.oauthIssuer = nil
        self.tokenExpiresAt = nil
        self.pdsURL = pdsURL
        self.needsReauth = false
    }
    
    // Legacy init for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.did = try container.decode(String.self, forKey: .did)
        self.handle = try container.decode(String.self, forKey: .handle)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        self.addedDate = try container.decode(Date.self, forKey: .addedDate)
        self.lastUsedDate = try container.decode(Date.self, forKey: .lastUsedDate)
        
        // New fields with defaults for backward compatibility
        self.sessionUUID = try container.decodeIfPresent(UUID.self, forKey: .sessionUUID) ?? UUID()
        self.authType = try container.decodeIfPresent(AuthType.self, forKey: .authType) ?? .appPassword
        self.oauthIssuer = try container.decodeIfPresent(String.self, forKey: .oauthIssuer)
        self.tokenExpiresAt = try container.decodeIfPresent(Date.self, forKey: .tokenExpiresAt)
        self.pdsURL = try container.decodeIfPresent(String.self, forKey: .pdsURL)
        self.needsReauth = try container.decodeIfPresent(Bool.self, forKey: .needsReauth) ?? false
    }
    
    // Update last used date
    mutating func markAsUsed() {
        self.lastUsedDate = Date()
    }
    
    // Update profile info
    mutating func updateProfile(displayName: String, avatarURL: URL?) {
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
    
    // Update OAuth token expiration
    mutating func updateTokenExpiration(_ expiresAt: Date?) {
        self.tokenExpiresAt = expiresAt
    }
    
    // Check if OAuth token needs refresh (30 minutes before expiration)
    var needsTokenRefresh: Bool {
        guard authType == .oauth,
              let expiresAt = tokenExpiresAt else {
            return false
        }
        return expiresAt.timeIntervalSinceNow < 1800 // 30 minutes
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, did, handle, displayName, avatarURL, addedDate, lastUsedDate
        case sessionUUID, authType, oauthIssuer, tokenExpiresAt, pdsURL, needsReauth
    }
}

// For storing in UserDefaults (without password)
struct StoredAccountList: Codable {
    var accounts: [UserAccount]
    var currentAccountDID: String?
    
    init(accounts: [UserAccount] = [], currentAccountDID: String? = nil) {
        self.accounts = accounts
        self.currentAccountDID = currentAccountDID
    }
}