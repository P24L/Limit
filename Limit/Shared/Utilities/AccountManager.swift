//
//  AccountManager.swift
//  Limit
//
//  Created by Zdenek Indra on 20.01.2025.
//

import Foundation
import KeychainSwift
import Observation
import ATProtoKit

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
    
    /// Add a new account with app password (legacy method)
    func addAccount(did: String, handle: String, appPassword: String, displayName: String = "", avatarURL: URL? = nil) {
        // Check if account already exists
        if accounts.contains(where: { $0.did == did }) {
            DevLogger.shared.log("AccountManager - Account already exists for DID: \(did)")
            return
        }
        
        // Create account with new UUID for keychain namespace
        let sessionUUID = UUID()
        let account = UserAccount(
            did: did,
            handle: handle,
            displayName: displayName,
            avatarURL: avatarURL,
            authType: .appPassword,
            sessionUUID: sessionUUID
        )
        
        // Store password in UUID-namespaced keychain
        let passwordKey = passwordKeyForAccount(sessionUUID)
        keychain.set(appPassword, forKey: passwordKey)
        
        // Also store in legacy location for backward compatibility
        let legacyKey = "cz.P24L.limit.appPassword.\(did)"
        keychain.set(appPassword, forKey: legacyKey)
        
        // Add to accounts list
        accounts.append(account)
        
        // If this is the first account, make it current
        if currentAccount == nil {
            currentAccount = account
        }
        
        saveAccounts()
        DevLogger.shared.log("AccountManager - Added account: \(handle) with UUID: \(sessionUUID)")
    }
    
    /// Add a new OAuth account
    func addOAuthAccount(did: String, handle: String, tokens: OAuthTokens, displayName: String = "", avatarURL: URL? = nil) {
        // Check if account already exists
        if let existingIndex = accounts.firstIndex(where: { $0.did == did }) {
            // Update existing account to OAuth
            var account = accounts[existingIndex]
            let oldAuthType = account.authType
            account.authType = .oauth
            account.updateTokenExpiration(tokens.expiresAt)
            account.updateProfile(displayName: displayName, avatarURL: avatarURL)
            account.pdsURL = tokens.pds // Store PDS URL from token
            accounts[existingIndex] = account
            
            // If converting from app password to OAuth, clean up old app password
            if oldAuthType == .appPassword {
                DevLogger.shared.log("AccountManager - Converting app password account to OAuth, cleaning up old credentials")
                // Remove app password from keychain
                let passwordKey = passwordKeyForAccount(account.sessionUUID)
                keychain.delete(passwordKey)
                
                // Also remove from legacy location
                let legacyKey = "cz.P24L.limit.appPassword.\(did)"
                keychain.delete(legacyKey)
                
                // Clean up any stored app password in OAuthSessionConfiguration keychain
                let keychainPrefix = "com.hyperlimit.account.\(account.sessionUUID.uuidString)"
                keychain.delete("\(keychainPrefix).appPassword")
            }
            
            // Store OAuth tokens in UUID-namespaced keychain
            _ = OAuthSessionConfiguration(
                instanceUUID: account.sessionUUID,
                handle: handle,
                tokens: tokens
            )
            
            currentAccount = account
            saveAccounts()
            DevLogger.shared.log("AccountManager - Updated account to OAuth: \(handle) with PDS: \(tokens.pds)")
            return
        }
        
        // Create new OAuth account
        let sessionUUID = UUID()
        var account = UserAccount(
            did: did,
            handle: handle,
            displayName: displayName,
            avatarURL: avatarURL,
            authType: .oauth,
            sessionUUID: sessionUUID,
            pdsURL: tokens.pds // Store PDS URL from token
        )
        account.oauthIssuer = "https://bsky.social"
        account.updateTokenExpiration(tokens.expiresAt)
        
        // Store OAuth tokens using OAuthSessionConfiguration
        _ = OAuthSessionConfiguration(
            instanceUUID: sessionUUID,
            handle: handle,
            tokens: tokens
        )
        
        // Add to accounts list
        accounts.append(account)
        currentAccount = account
        
        saveAccounts()
        DevLogger.shared.log("AccountManager - Added OAuth account: \(handle) with UUID: \(sessionUUID)")
    }
    
    /// Add a new account or update existing one and make it current
    func addOrUpdateAccount(did: String, handle: String, appPassword: String, displayName: String = "", avatarURL: URL? = nil) {
        // Check if account already exists
        if let existingIndex = accounts.firstIndex(where: { $0.did == did }) {
            // Update existing account
            var account = accounts[existingIndex]
            account.updateProfile(displayName: displayName, avatarURL: avatarURL)
            account.markAsUsed()
            accounts[existingIndex] = account
            
            // Update password in UUID-namespaced keychain
            let passwordKey = passwordKeyForAccount(account.sessionUUID)
            keychain.set(appPassword, forKey: passwordKey)
            
            // Also update legacy location
            let legacyKey = "cz.P24L.limit.appPassword.\(did)"
            keychain.set(appPassword, forKey: legacyKey)
            
            // Make it current
            currentAccount = account
            
            saveAccounts()
            DevLogger.shared.log("AccountManager - Updated and switched to existing account: \(handle)")
        } else {
            let sessionUUID = UUID()
            let account = UserAccount(
                did: did,
                handle: handle,
                displayName: displayName,
                avatarURL: avatarURL,
                authType: .appPassword,
                sessionUUID: sessionUUID
            )
            
            // Store password in UUID-namespaced keychain
            let passwordKey = passwordKeyForAccount(sessionUUID)
            keychain.set(appPassword, forKey: passwordKey)
            
            // Also store in legacy location
            let legacyKey = "cz.P24L.limit.appPassword.\(did)"
            keychain.set(appPassword, forKey: legacyKey)
            
            // Add to accounts list
            accounts.append(account)
            
            // Make it current
            currentAccount = account
            
            saveAccounts()
            DevLogger.shared.log("AccountManager - Added new account and made it current: \(handle) with UUID: \(sessionUUID)")
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
        // Remove password from UUID-namespaced keychain
        let passwordKey = passwordKeyForAccount(account.sessionUUID)
        keychain.delete(passwordKey)
        
        // Also remove from legacy location
        let legacyKey = "cz.P24L.limit.appPassword.\(account.did)"
        keychain.delete(legacyKey)
        
        // If OAuth account, clean up OAuth tokens
        if account.authType == .oauth {
            Task { @MainActor in
                let sessionConfig = OAuthSessionConfiguration(
                    instanceUUID: account.sessionUUID,
                    pdsURL: "https://bsky.social"
                )
                try? await sessionConfig.deleteSession()
            }
        }
        
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
    
    /// Mark account as needing re-authentication
    func markAccountNeedsReauth(_ account: UserAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        
        accounts[index].needsReauth = true
        
        // Update current account if it's the same
        if currentAccount?.id == account.id {
            currentAccount = accounts[index]
        }
        
        saveAccounts()
        DevLogger.shared.log("AccountManager - Marked account \(account.handle) as needing re-auth")
    }
    
    /// Clear needs reauth flag for account
    func clearNeedsReauth(for account: UserAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        
        accounts[index].needsReauth = false
        
        // Update current account if it's the same
        if currentAccount?.id == account.id {
            currentAccount = accounts[index]
        }
        
        saveAccounts()
        DevLogger.shared.log("AccountManager - Cleared needs reauth for account \(account.handle)")
    }
    
    /// Get app password for an account
    func getAppPassword(for account: UserAccount) -> String? {
        // Try UUID-namespaced key first
        let uuidKey = passwordKeyForAccount(account.sessionUUID)
        if let password = keychain.get(uuidKey) {
            return password
        }
        
        // Fall back to legacy key for backward compatibility
        let legacyKey = "cz.P24L.limit.appPassword.\(account.did)"
        return keychain.get(legacyKey)
    }
    
    /// Get session configuration for an account
    func getSessionConfiguration(for account: UserAccount) -> OAuthSessionConfiguration {
        if account.authType == .oauth {
            // OAuth account - load from keychain with correct PDS URL
            // Use account's stored PDS URL or fallback to default
            let pdsURL = account.pdsURL ?? "https://bsky.social"
            return OAuthSessionConfiguration(
                instanceUUID: account.sessionUUID,
                pdsURL: pdsURL
            )
        } else {
            // App password account
            if let appPassword = getAppPassword(for: account) {
                return OAuthSessionConfiguration(
                    instanceUUID: account.sessionUUID,
                    handle: account.handle,
                    appPassword: appPassword,
                    pdsURL: "https://bsky.social"
                )
            } else {
                // Fallback - create empty config
                return OAuthSessionConfiguration(
                    instanceUUID: account.sessionUUID,
                    pdsURL: "https://bsky.social"
                )
            }
        }
    }
    
    /// Get app password for current account
    func getCurrentAccountPassword() -> String? {
        guard let currentAccount = currentAccount else { return nil }
        return getAppPassword(for: currentAccount)
    }
    
    // MARK: - Private Methods
    
    private func passwordKeyForAccount(_ sessionUUID: UUID) -> String {
        return "com.hyperlimit.account.\(sessionUUID.uuidString).appPassword"
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
    
    /// Check and refresh OAuth tokens for all accounts that need it
    func refreshTokensIfNeeded() async {
        for account in accounts where account.needsTokenRefresh {
            DevLogger.shared.log("AccountManager - Token refresh needed for: \(account.handle)")
            
            let sessionConfig = getSessionConfiguration(for: account)
            do {
                try await sessionConfig.refreshSession()
                
                // Update token expiration in account
                if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                    if let tokens = sessionConfig.loadTokens() {
                        accounts[index].updateTokenExpiration(tokens.expiresAt)
                        saveAccounts()
                    }
                }
                
                DevLogger.shared.log("AccountManager - Token refreshed for: \(account.handle)")
            } catch {
                DevLogger.shared.log("AccountManager - Token refresh failed for \(account.handle): \(error)")
            }
        }
    }
}