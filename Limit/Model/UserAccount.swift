//
//  UserAccount.swift
//  Limit
//
//  Created by Zdenek Indra on 20.01.2025.
//

import Foundation

struct UserAccount: Codable, Identifiable, Equatable {
    let id: UUID
    let did: String
    let handle: String
    var displayName: String
    var avatarURL: URL?
    let addedDate: Date
    var lastUsedDate: Date
    
    init(did: String, handle: String, displayName: String = "", avatarURL: URL? = nil) {
        self.id = UUID()
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.addedDate = Date()
        self.lastUsedDate = Date()
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