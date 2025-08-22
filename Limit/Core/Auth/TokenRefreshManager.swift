//
//  TokenRefreshManager.swift
//  Limit
//
//  Background token refresh manager for multi-account OAuth support
//

import Foundation
import ATProtoKit

/// Manages background token refresh for all accounts
@MainActor
final class TokenRefreshManager {
    
    // MARK: - Singleton
    
    static let shared = TokenRefreshManager()
    
    // MARK: - Properties
    
    /// Timer for periodic refresh checks
    private var refreshTimer: Timer?
    
    /// Queue for serializing refresh operations per account
    private let refreshQueue = DispatchQueue(label: "com.hyperlimit.tokenrefresh", attributes: .concurrent)
    
    /// Track accounts currently being refreshed to avoid duplicates
    private var refreshingAccounts = Set<UUID>()
    
    /// Refresh interval (30 minutes)
    private let refreshInterval: TimeInterval = 1800 // 30 minutes
    
    /// Token expiry buffer (refresh if less than 30 minutes remaining)
    private let expiryBuffer: TimeInterval = 1800 // 30 minutes
    
    // MARK: - Initialization
    
    private init() {
        DevLogger.shared.log("TokenRefreshManager - Initialized")
    }
    
    // MARK: - Public Methods
    
    /// Start periodic token refresh checks
    func startPeriodicRefresh() {
        stopPeriodicRefresh() // Stop any existing timer
        
        // Initial check
        Task {
            await checkAndRefreshTokens()
        }
        
        // Schedule periodic checks
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndRefreshTokens()
            }
        }
        
        DevLogger.shared.log("TokenRefreshManager - Started periodic refresh (every \(Int(refreshInterval/60)) minutes)")
    }
    
    /// Stop periodic token refresh checks
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        DevLogger.shared.log("TokenRefreshManager - Stopped periodic refresh")
    }
    
    /// Manually trigger token refresh check for all accounts
    func checkAndRefreshTokens() async {
        DevLogger.shared.log("TokenRefreshManager - Checking tokens for all accounts")
        
        let accounts = AccountManager.shared.accounts
        
        // Check each account
        for account in accounts {
            await checkAndRefreshToken(for: account)
        }
    }
    
    /// Check and refresh token for a specific account
    func checkAndRefreshToken(for account: UserAccount) async {
        // Skip if account is already being refreshed
        guard !refreshingAccounts.contains(account.sessionUUID) else {
            DevLogger.shared.log("TokenRefreshManager - Already refreshing: \(account.handle)")
            return
        }
        
        // OAuth accounts only
        guard account.authType == .oauth else {
            // App password accounts don't need token refresh
            return
        }
        
        // Check if token needs refresh
        guard account.needsTokenRefresh else {
            DevLogger.shared.log("TokenRefreshManager - Token still valid for: \(account.handle)")
            return
        }
        
        // Mark as refreshing
        refreshingAccounts.insert(account.sessionUUID)
        defer { refreshingAccounts.remove(account.sessionUUID) }
        
        DevLogger.shared.log("TokenRefreshManager - Refreshing token for: \(account.handle)")
        
        // Get session configuration
        let sessionConfig = AccountManager.shared.getSessionConfiguration(for: account)
        
        do {
            // Attempt to refresh
            try await sessionConfig.refreshSession()
            
            // Update token expiration in AccountManager
            if let tokens = sessionConfig.loadTokens() {
                // Update account with new expiration
                if let index = AccountManager.shared.accounts.firstIndex(where: { $0.id == account.id }) {
                    // Create a mutable copy to update
                    var updatedAccount = AccountManager.shared.accounts[index]
                    updatedAccount.updateTokenExpiration(tokens.expiresAt)
                    
                    // Note: AccountManager would need a method to update account
                    // For now, just log the success
                    DevLogger.shared.log("TokenRefreshManager - Successfully refreshed token for: \(account.handle)")
                }
            }
        } catch {
            DevLogger.shared.log("TokenRefreshManager - Failed to refresh token for \(account.handle): \(error)")
            
            // Handle refresh failure
            await handleRefreshFailure(for: account, error: error)
        }
    }
    
    /// Refresh token for currently active account only
    func refreshActiveAccountIfNeeded() async {
        guard let currentAccount = AccountManager.shared.currentAccount else { return }
        await checkAndRefreshToken(for: currentAccount)
    }
    
    // MARK: - Private Methods
    
    /// Handle token refresh failure
    private func handleRefreshFailure(for account: UserAccount, error: Error) async {
        DevLogger.shared.log("TokenRefreshManager - Handling refresh failure for: \(account.handle)")
        
        // Check error type
        if let oauthError = error as? OAuthError {
            switch oauthError {
            case .noRefreshToken:
                // No refresh token available - user needs to re-authenticate
                DevLogger.shared.log("TokenRefreshManager - No refresh token for \(account.handle), marking for re-auth")
                // TODO: Mark account as needs re-authentication
                
            case .refreshFailed:
                // Refresh failed - may be temporary network issue
                DevLogger.shared.log("TokenRefreshManager - Refresh failed for \(account.handle), will retry later")
                
            case .invalidTokens:
                // Invalid tokens - user needs to re-authenticate
                DevLogger.shared.log("TokenRefreshManager - Invalid tokens for \(account.handle), marking for re-auth")
                // TODO: Mark account as needs re-authentication
            }
        } else {
            // Generic error - log and continue
            DevLogger.shared.log("TokenRefreshManager - Unknown error for \(account.handle): \(error)")
        }
    }
    
    /// Check if we should refresh tokens for inactive accounts
    /// (Called when app is active but account is not current)
    func shouldRefreshInactiveAccount(_ account: UserAccount) -> Bool {
        // Don't refresh if it's the current account (handled by MultiAccountClient)
        if account.id == AccountManager.shared.currentAccount?.id {
            return false
        }
        
        // Only refresh OAuth accounts
        guard account.authType == .oauth else {
            return false
        }
        
        // Check if needs refresh
        return account.needsTokenRefresh
    }
}

// MARK: - Extensions

extension TokenRefreshManager {
    
    /// Convenience method to start refresh when app becomes active
    func applicationDidBecomeActive() {
        DevLogger.shared.log("TokenRefreshManager - App became active, checking tokens")
        
        Task {
            // Check all tokens immediately
            await checkAndRefreshTokens()
            
            // Start periodic refresh if not already running
            if refreshTimer == nil {
                startPeriodicRefresh()
            }
        }
    }
    
    /// Convenience method to handle app going to background
    func applicationDidEnterBackground() {
        DevLogger.shared.log("TokenRefreshManager - App entered background")
        
        // Continue refresh timer in background for a while
        // iOS will eventually suspend the app, but we get some time
        
        // Note: For proper background refresh, would need to implement
        // BackgroundTasks framework, but that's beyond current scope
    }
    
    /// Get refresh status for UI display
    func getRefreshStatus() -> (refreshing: Bool, accountsBeingRefreshed: [UUID]) {
        return (!refreshingAccounts.isEmpty, Array(refreshingAccounts))
    }
}