//
//  LoginTabView.swift
//  Limit
//
//  Created by Zdenek Indra on 27.05.2025.
//

import KeychainSwift
import SwiftUI

struct LoginTabView: View {
    @Environment(BlueskyClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    //@Binding var areCredentialsAvailable: Bool
    
    @State private var handle: String = ""
    @State private var appPassword: String = ""
    
    @State private var showPassword: Bool = false
    @State private var showLoginError: Bool = false
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                    Button {
                        login()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Log In")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(handle.isEmpty || appPassword.isEmpty || isLoading)
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
    
    private func login() {
        isLoading = true
        errorMessage = nil

        client.handle = handle
        client.appPassword = appPassword

        Task {
            do {
                await client.login()
                if client.isAuthenticated {
                    // Persist to keychain
                    let keychain = KeychainSwift()
                    keychain.set(handle, forKey: "cz.P24L.limit.handle")
                    keychain.set(appPassword, forKey: "cz.P24L.limit.appPassword")
                    
                    // Refresh profile
                    await currentUser.refreshProfile(client: client)
                    // Notify app that credentials are good
                    await MainActor.run {
                        //areCredentialsAvailable = true
                        onDismiss()
                    }
                } else {
                    throw NSError(domain: "LoginFailed", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
                }
            } catch {
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
