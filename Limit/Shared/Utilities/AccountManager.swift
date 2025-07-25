//
//  AccountManager.swift
//  Limit
//
//  Created by Zdenek Indra on 20.01.2025.
//

import Foundation
import KeychainSwift
import Observation

@Observable
@MainActor
class AccountManager {
    static let shared = AccountManager()
    
    private let keychain = KeychainSwift()
    private let userDefaults = UserDefaults.standard
    
    // Keys for storage
    private let accountsKey = "cz.P24L.limit.accounts"
    private let legacyHandleKey = "cz.P24L.limit.handle"
    private let legacyPasswordKey = "cz.P24L.limit.appPassword"
    
    // Observable properties
    private(set) var accounts: [UserAccount] = []
    private(set) var currentAccount: UserAccount?
    
    private init() {
        loadAccounts()
        migrateExistingAccountIfNeeded()
    }
    
    // MARK: - Account Management
    
    /// Add a new account
    func addAccount(did: String, handle: String, appPassword: String, displayName: String = "", avatarURL: URL? = nil) {
        // Check if account already exists
        if accounts.contains(where: { $0.did == did }) {
            DevLogger.shared.log("AccountManager - Account already exists for DID: \(did)")
            return
        }
        
        let account = UserAccount(did: did, handle: handle, displayName: displayName, avatarURL: avatarURL)
        
        // Store password in keychain
        let passwordKey = passwordKeyForAccount(did)
        keychain.set(appPassword, forKey: passwordKey)
        
        // Add to accounts list
        accounts.append(account)
        
        // If this is the first account, make it current
        if currentAccount == nil {
            currentAccount = account
        }
        
        saveAccounts()
        DevLogger.shared.log("AccountManager - Added account: \(handle)")
    }
    
    /// Add a new account or update existing one and make it current
    func addOrUpdateAccount(did: String, handle: String, appPassword: String, displayName: String = "", avatarURL: URL? = nil) {
        // Check if account already exists
        if let existingIndex = accounts.firstIndex(where: { $0.did == did }) {
            // Update existing account
            accounts[existingIndex].updateProfile(displayName: displayName, avatarURL: avatarURL)
            accounts[existingIndex].markAsUsed()
            
            // Update password in keychain
            let passwordKey = passwordKeyForAccount(did)
            keychain.set(appPassword, forKey: passwordKey)
            
            // Make it current
            currentAccount = accounts[existingIndex]
            
            saveAccounts()
            DevLogger.shared.log("AccountManager - Updated and switched to existing account: \(handle)")
        } else {
            let account = UserAccount(did: did, handle: handle, displayName: displayName, avatarURL: avatarURL)
            
            // Store password in keychain
            let passwordKey = passwordKeyForAccount(did)
            keychain.set(appPassword, forKey: passwordKey)
            
            // Add to accounts list
            accounts.append(account)
            
            // Make it current
            currentAccount = account
            
            saveAccounts()
            DevLogger.shared.log("AccountManager - Added new account and made it current: \(handle)")
        }
    }
    
    /// Switch to a different account
    func switchToAccount(_ account: UserAccount) {
        guard accounts.contains(where: { $0.id == account.id }) else {
            DevLogger.shared.log("AccountManager - Cannot switch to unknown account")
            return
        }
        
        // Update last used date
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].markAsUsed()
        }
        
        currentAccount = account
        saveAccounts()
        DevLogger.shared.log("AccountManager - Switched to account: \(account.handle)")
    }
    
    /// Delete an account
    func deleteAccount(_ account: UserAccount, bookmarkManager: BookmarkManager? = nil) {
        // Remove password from keychain
        let passwordKey = passwordKeyForAccount(account.did)
        keychain.delete(passwordKey)
        
        // Remove from accounts list
        accounts.removeAll(where: { $0.id == account.id })
        
        // If this was the current account, switch to another one
        if currentAccount?.id == account.id {
            currentAccount = accounts.first
        }
        
        // Clean up timeline positions for this account
        TimelinePositionManager.shared.clearPositionsForAccount(account.did)
        
        // Clean up bookmarks for this account if bookmarkManager provided
        if let bookmarkManager = bookmarkManager {
            Task {
                await bookmarkManager.deleteBookmarksForUser(did: account.did)
            }
        }
        
        saveAccounts()
        DevLogger.shared.log("AccountManager - Deleted account: \(account.handle)")
    }
    
    /// Update account profile info
    func updateAccountProfile(for did: String, displayName: String, avatarURL: URL?) {
        guard let index = accounts.firstIndex(where: { $0.did == did }) else { return }
        
        accounts[index].updateProfile(displayName: displayName, avatarURL: avatarURL)
        
        // Update current account if it's the same
        if currentAccount?.did == did {
            currentAccount = accounts[index]
        }
        
        saveAccounts()
    }
    
    /// Get app password for an account
    func getAppPassword(for account: UserAccount) -> String? {
        let passwordKey = passwordKeyForAccount(account.did)
        return keychain.get(passwordKey)
    }
    
    /// Get app password for current account
    func getCurrentAccountPassword() -> String? {
        guard let currentAccount = currentAccount else { return nil }
        return getAppPassword(for: currentAccount)
    }
    
    // MARK: - Private Methods
    
    private func passwordKeyForAccount(_ did: String) -> String {
        return "cz.P24L.limit.appPassword.\(did)"
    }
    
    private func loadAccounts() {
        guard let data = userDefaults.data(forKey: accountsKey),
              let storedList = try? JSONDecoder().decode(StoredAccountList.self, from: data) else {
            DevLogger.shared.log("AccountManager - No stored accounts found")
            return
        }
        
        accounts = storedList.accounts
        currentAccount = accounts.first(where: { $0.did == storedList.currentAccountDID })
        
        // If current account not found but accounts exist, use first one
        if currentAccount == nil && !accounts.isEmpty {
            currentAccount = accounts.first
        }
        
        DevLogger.shared.log("AccountManager - Loaded \(accounts.count) accounts")
    }
    
    private func saveAccounts() {
        let storedList = StoredAccountList(
            accounts: accounts,
            currentAccountDID: currentAccount?.did
        )
        
        if let data = try? JSONEncoder().encode(storedList) {
            userDefaults.set(data, forKey: accountsKey)
            DevLogger.shared.log("AccountManager - Saved \(accounts.count) accounts")
        }
    }
    
    private func migrateExistingAccountIfNeeded() {
        // Check if we have legacy credentials but no accounts
        guard accounts.isEmpty,
              let handle = keychain.get(legacyHandleKey),
              let appPassword = keychain.get(legacyPasswordKey) else {
            return
        }
        
        DevLogger.shared.log("AccountManager - Migrating existing account")
        
        // We need to get the DID - for now we'll use handle as a temporary placeholder
        // The actual DID will be updated when the user logs in
        let tempDID = "legacy:\(handle)"
        addAccount(did: tempDID, handle: handle, appPassword: appPassword)
        
        // Clean up legacy keys after migration
        keychain.delete(legacyHandleKey)
        keychain.delete(legacyPasswordKey)
    }
}