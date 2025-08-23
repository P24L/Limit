//
//  LoginTabView.swift
//  Limit
//
//  Created by Zdenek Indra on 27.05.2025.
//

import KeychainSwift
import SwiftUI
import WebKit

struct LoginTabView: View {
    @Environment(MultiAccountClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @StateObject private var oauthService = OAuthService.shared
    //@Binding var areCredentialsAvailable: Bool
    
    // Prefilled handle for re-auth
    var prefilledHandle: String = ""
    
    @State private var handle: String = ""
    @State private var appPassword: String = ""
    
    @State private var showPassword: Bool = false
    @State private var showLoginError: Bool = false
    
    @State private var isLoading = false
    @State private var isOAuthLoading = false
    @State private var errorMessage: String?
    @State private var showOAuthWebView = false
    @State private var isSwitchingAccount = false
    
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            Text("Limit")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .padding(.top, 20)
        NavigationStack {
            Form {
                // App Password login is now hidden - OAuth only
                /*
                Section(header: Text("Bluesky Login")) {
                    TextField("Handle", text: $handle)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    HStack {
                        Group {
                            if showPassword {
                                TextField("App Password", text: $appPassword)
                            } else {
                                SecureField("App Password", text: $appPassword)
                            }
                        }
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                    }
                }
                */

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    // OAuth Login Button
                    Button {
                        loginWithOAuth()
                    } label: {
                        HStack {
                            Spacer()
                            if isOAuthLoading {
                                ProgressView()
                            } else {
                                VStack(spacing: 4) {
                                    Label("Connect with your Bluesky account", systemImage: "link.circle.fill")
                                        .bold()
                                    if !prefilledHandle.isEmpty {
                                        Text("as @\(prefilledHandle)")
                                            .font(.caption)
                                            .opacity(0.9)
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                    .disabled(isOAuthLoading || isLoading)
                    .foregroundColor(.white)
                    .listRowBackground(Color.blue)
                    
                    // App Password login is now hidden - OAuth only
                    /*
                    Button {
                        login()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Log In with App Password")
                                    .font(.footnote)
                            }
                            Spacer()
                        }
                    }
                    .disabled(handle.isEmpty || appPassword.isEmpty || isLoading || isOAuthLoading)
                    */
                    
                    // Cancel OAuth button
                    if isOAuthLoading {
                        Button {
                            cancelOAuth()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Cancel Authentication")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            
                // Available accounts section
                if !AccountManager.shared.accounts.isEmpty {
                    Section(header: Text("Switch Account")) {
                        // Filter out the account we're currently re-authenticating
                        ForEach(AccountManager.shared.accounts.filter { account in
                            let handleToCheck = !prefilledHandle.isEmpty ? prefilledHandle : handle
                            // Don't show the account we're re-authenticating (it's already shown above)
                            return account.handle.lowercased() != handleToCheck.lowercased()
                        }) { account in
                            Button {
                                Task {
                                    // If this is the current account and it works, just close the sheet
                                    if account.id == AccountManager.shared.currentAccount?.id && !account.needsReauth {
                                        await MainActor.run {
                                            onDismiss()
                                        }
                                    } else {
                                        await switchToAccount(account)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    // Avatar placeholder
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(account.handle.prefix(1).uppercased())
                                                .font(.headline)
                                                .foregroundColor(.gray)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        if !account.displayName.isEmpty {
                                            Text(account.displayName)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                        }
                                        Text("@\(account.handle)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Show indicators
                                    HStack(spacing: 8) {
                                        if account.id == AccountManager.shared.currentAccount?.id {
                                            Text("(Current)")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        if account.needsReauth {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 16))
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Login")
            .onAppear {
                // Pre-fill handle if provided for re-auth
                if !prefilledHandle.isEmpty {
                    handle = prefilledHandle
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
        .onReceive(oauthService.$showWebView) { show in
            showOAuthWebView = show
            if show {
                // DevLogger.shared.log("LoginTabView - OAuthService showWebView changed to: \(show), URL: \(oauthService.authWebViewURL?.absoluteString ?? "nil")")
            }
        }
        .sheet(isPresented: $showOAuthWebView) {
            if let url = oauthService.authWebViewURL {
                NavigationStack {
                    OAuthWebView(
                        url: url,
                        onCallback: { callbackURL in
                            // DevLogger.shared.log("LoginTabView - OAuth callback received")
                            showOAuthWebView = false
                            oauthService.handleOAuthCallback(url: callbackURL)
                        },
                        onCancel: {
                            // DevLogger.shared.log("LoginTabView - OAuth cancelled")
                            showOAuthWebView = false
                            oauthService.cancelOAuth()
                        }
                    )
                    .navigationTitle("Sign in to Bluesky")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showOAuthWebView = false
                                oauthService.cancelOAuth()
                            }
                        }
                    }
                }
                .onAppear {
                    // DevLogger.shared.log("LoginTabView - OAuth sheet appeared with URL: \(url)")
                }
            } else {
                Text("Error: No OAuth URL available")
                    .onAppear {
                        // DevLogger.shared.log("LoginTabView - ERROR: Sheet shown but oauthWebViewURL is nil")
                    }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func cancelOAuth() {
        isOAuthLoading = false
        errorMessage = nil
        oauthService.cancelOAuth()
        // DevLogger.shared.log("LoginTabView - OAuth authentication cancelled by user")
    }
    
    private func switchToAccount(_ account: UserAccount) async {
        if account.needsReauth {
            // Account needs re-auth, start OAuth with this handle
            await MainActor.run {
                // Set prefilled handle for OAuth
                handle = account.handle
                // Start OAuth flow
                loginWithOAuth()
            }
        } else {
            // Switch to the account
            await MainActor.run {
                isSwitchingAccount = true
            }
            
            await client.switchToAccount(account)
            // AccountManager is updated automatically by MultiAccountClient.switchToAccount
            
            // Refresh UI
            await currentUser.refreshProfile(client: client)
            
            await MainActor.run {
                isSwitchingAccount = false
                onDismiss()
            }
        }
    }
    
    private func loginWithOAuth() {
        isOAuthLoading = true
        errorMessage = nil
        
        DevLogger.shared.log("LoginTabView - Starting OAuth login")
        
        Task {
            do {
                // Start OAuth flow - use prefilled handle or handle from text field
                let oauthService = OAuthService.shared
                let handleToUse = !prefilledHandle.isEmpty ? prefilledHandle : handle
                
                // Check if this account already exists and works
                if !handleToUse.isEmpty,
                   let existingAccount = AccountManager.shared.accounts.first(where: { 
                       $0.handle.lowercased() == handleToUse.lowercased() && !$0.needsReauth 
                   }) {
                    // Account already exists and works, just switch to it
                    // DevLogger.shared.log("LoginTabView - Account already exists, switching to it")
                    await switchToAccount(existingAccount)
                    await MainActor.run {
                        isOAuthLoading = false
                    }
                    return
                }
                
                // Handle is optional - if provided, it will pre-fill on Bluesky
                let tokens = try await oauthService.startOAuthFlow(handle: handleToUse)
                
                DevLogger.shared.log("LoginTabView - OAuth successful, got tokens for: \(tokens.handle)")
                
                // Add OAuth account to AccountManager
                AccountManager.shared.addOAuthAccount(
                    did: tokens.did,
                    handle: tokens.handle,
                    tokens: tokens,
                    displayName: tokens.handle,
                    avatarURL: nil
                )
                
                // Switch to the new OAuth account
                if let account = AccountManager.shared.accounts.first(where: { $0.did == tokens.did }) {
                    // Clear the needsReauth flag after successful OAuth
                    AccountManager.shared.clearNeedsReauth(for: account)
                    // Small delay to ensure tokens are properly saved
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    await client.switchToAccount(account)
                    
                    // Refresh profile to get display name and avatar
                    await currentUser.refreshProfile(client: client)
                    
                    // Update account with profile info
                    AccountManager.shared.updateAccountProfile(
                        for: tokens.did,
                        displayName: currentUser.displayName,
                        avatarURL: currentUser.avatarURL
                    )
                }
                
                await MainActor.run {
                    isOAuthLoading = false
                    onDismiss()
                }
                
            } catch {
                DevLogger.shared.log("LoginTabView - OAuth error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "OAuth login failed: \(error.localizedDescription)"
                    isOAuthLoading = false
                }
            }
        }
    }
    
    private func login() {
        isLoading = true
        errorMessage = nil
        
        DevLogger.shared.log("LoginTabView - Starting login for handle: \(handle)")

        Task {
            do {
                // Add account first
                AccountManager.shared.addOrUpdateAccount(
                    did: "temp:\(handle)", // Temporary DID until we get real one
                    handle: handle,
                    appPassword: appPassword,
                    displayName: "",
                    avatarURL: nil
                )
                
                // Initialize client with the new account
                await client.initializeWithCurrentAccount()
                
                if client.isAuthenticated {
                    // Get the real DID from the authenticated session
                    guard let realDID = client.currentDID else {
                        throw NSError(domain: "LoginFailed", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not get user DID"])
                    }
                    
                    // Refresh profile to get display name and avatar
                    await currentUser.refreshProfile(client: client)
                    
                    // Add or update account in AccountManager
                    await MainActor.run {
                        AccountManager.shared.addOrUpdateAccount(
                            did: realDID,
                            handle: handle,
                            appPassword: appPassword,
                            displayName: currentUser.displayName,
                            avatarURL: currentUser.avatarURL
                        )
                        
                        onDismiss()
                    }
                } else {
                    throw NSError(domain: "LoginFailed", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
                }
            } catch {
                DevLogger.shared.log("LoginTabView - Login error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}


/* #Preview {
    LoginTabView()
        .environment(BlueskyClient())
}
*/
