//
//  LoginTabView.swift
//  Limit
//
//  Created by Zdenek Indra on 27.05.2025.
//

import KeychainSwift
import SwiftUI

struct LoginTabView: View {
    @Environment(MultiAccountClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    //@Binding var areCredentialsAvailable: Bool
    
    @State private var handle: String = ""
    @State private var appPassword: String = ""
    
    @State private var showPassword: Bool = false
    @State private var showLoginError: Bool = false
    
    @State private var isLoading = false
    @State private var isOAuthLoading = false
    @State private var errorMessage: String?
    @State private var showOAuthWebView = false
    
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
                                    Label("Continue with Bluesky", systemImage: "link.circle.fill")
                                        .bold()
                                    if !handle.isEmpty {
                                        Text("as @\(handle)")
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
                    
                    // App Password Login Button
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
                }
            }
            .navigationTitle("Login")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func loginWithOAuth() {
        isOAuthLoading = true
        errorMessage = nil
        
        DevLogger.shared.log("LoginTabView - Starting OAuth login")
        
        Task {
            do {
                // Start OAuth flow - use handle from text field if provided (optional)
                let oauthService = OAuthService.shared
                // Handle is optional - if user typed it, it will pre-fill on Bluesky
                let tokens = try await oauthService.startOAuthFlow(handle: handle)
                
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
