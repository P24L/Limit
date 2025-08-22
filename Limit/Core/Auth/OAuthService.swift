//
//  OAuthService.swift
//  Limit
//
//  OAuth authentication service for Bluesky
//

import Foundation
import SwiftUI
import WebKit
import ATProtoKit

/// OAuth configuration for Limit app
struct OAuthConfig {
    static let backendURL = "https://auth.hyperlimit.app"
    static let clientID = "https://auth.hyperlimit.app/client-metadata.json"
    static let urlScheme = "limit"
    static let universalLinkHost = "viewer.hyperlimit.app"
}

/// OAuth authentication service
@MainActor
class OAuthService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticating = false
    @Published var authError: String?
    
    // MARK: - Private Properties
    
    private var authCompletion: ((Result<OAuthTokens, Error>) -> Void)?
    
    // MARK: - Singleton (optional)
    
    static let shared = OAuthService()
    
    // MARK: - Public Methods
    
    /// Start OAuth flow for a given handle
    func startOAuthFlow(handle: String) async throws -> OAuthTokens {
        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }
        
        // Start OAuth flow with backend
        let authURL = try await startOAuthWithBackend(handle: handle)
        
        // Present WebView and wait for callback
        return try await withCheckedThrowingContinuation { continuation in
            self.authCompletion = { result in
                continuation.resume(with: result)
            }
            
            // Present OAuth WebView
            Task { @MainActor in
                presentOAuthWebView(url: authURL)
            }
        }
    }
    
    /// Handle OAuth callback from deep link or universal link
    func handleOAuthCallback(url: URL) {
        DevLogger.shared.log("OAuthService - Handling callback: \(url)")
        
        // Parse callback URL
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Check for error
        if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            let errorDescription = components?.queryItems?.first(where: { $0.name == "error_description" })?.value ?? error
            DevLogger.shared.log("OAuthService - OAuth error: \(error) - \(errorDescription)")
            authError = errorDescription
            isAuthenticating = false  // Stop the spinner
            authCompletion?(.failure(OAuthServiceError.authenticationFailed(errorDescription)))
            authCompletion = nil
            return
        }
        
        // Get authorization code
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            DevLogger.shared.log("OAuthService - No authorization code in callback")
            authError = "No authorization code received"
            authCompletion?(.failure(OAuthServiceError.noAuthorizationCode))
            authCompletion = nil
            return
        }
        
        DevLogger.shared.log("OAuthService - Got authorization code")
        
        // Exchange code for tokens
        Task {
            do {
                let tokens = try await exchangeCodeForTokens(code: code)
                DevLogger.shared.log("OAuthService - Successfully exchanged code for tokens")
                isAuthenticating = false  // Stop the spinner on success
                authCompletion?(.success(tokens))
            } catch {
                DevLogger.shared.log("OAuthService - Failed to exchange code: \(error)")
                authError = error.localizedDescription
                isAuthenticating = false  // Stop the spinner on error
                authCompletion?(.failure(error))
            }
            authCompletion = nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Start OAuth flow with backend
    private func startOAuthWithBackend(handle: String) async throws -> URL {
        let url = URL(string: "\(OAuthConfig.backendURL)/api/auth/start")!
        DevLogger.shared.log("OAuthService - Calling backend: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Handle is optional - if not provided, don't send it at all
        let body: [String: String]
        if handle.isEmpty {
            body = [:]  // Empty body - backend will handle OAuth without pre-filled handle
            DevLogger.shared.log("OAuthService - Request without handle (user will enter on Bluesky)")
        } else {
            body = ["handle": handle]  // Pre-fill handle on Bluesky login
            DevLogger.shared.log("OAuthService - Request with handle: '\(handle)'")
        }
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DevLogger.shared.log("OAuthService - Invalid response type")
                throw OAuthServiceError.backendError("Invalid response from backend")
            }
            
            DevLogger.shared.log("OAuthService - Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                DevLogger.shared.log("OAuthService - Error response: \(responseString)")
                throw OAuthServiceError.backendError("Backend returned \(httpResponse.statusCode): \(responseString)")
            }
            
            // Log successful response
            let responseString = String(data: data, encoding: .utf8) ?? ""
            DevLogger.shared.log("OAuthService - Success response: \(responseString)")
            
            // Parse response
            struct StartResponse: Decodable {
                let authUrl: String
                let handle: String?  // Optional - backend nevrací handle když nebyl zadán při startu
                let sessionId: String?
            }
            
            let startResponse = try JSONDecoder().decode(StartResponse.self, from: data)
            DevLogger.shared.log("OAuthService - Parsed authUrl: \(startResponse.authUrl)")
            
            guard let authURL = URL(string: startResponse.authUrl) else {
                DevLogger.shared.log("OAuthService - Invalid URL: \(startResponse.authUrl)")
                throw OAuthServiceError.invalidURL
            }
            
            return authURL
            
        } catch {
            DevLogger.shared.log("OAuthService - Network error: \(error)")
            throw OAuthServiceError.backendError("Network error: \(error.localizedDescription)")
        }
    }
    
    /// Exchange authorization code for tokens
    private func exchangeCodeForTokens(code: String) async throws -> OAuthTokens {
        let url = URL(string: "\(OAuthConfig.backendURL)/api/auth/tokens")!
        DevLogger.shared.log("OAuthService - Exchanging code at: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["code": code]
        request.httpBody = try JSONEncoder().encode(body)
        DevLogger.shared.log("OAuthService - Exchange request with code: \(code.prefix(10))...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DevLogger.shared.log("OAuthService - Invalid response type for token exchange")
                throw OAuthServiceError.backendError("Invalid response from backend")
            }
            
            DevLogger.shared.log("OAuthService - Token exchange status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                DevLogger.shared.log("OAuthService - Token exchange error: \(responseString)")
                throw OAuthServiceError.backendError("Token exchange failed (\(httpResponse.statusCode)): \(responseString)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            DevLogger.shared.log("OAuthService - Token exchange success: \(responseString.prefix(100))...")
            
            struct TokenResponse: Decodable {
                let accessToken: String
                let refreshToken: String
                let handle: String
                let did: String
                let pds: String
                let dpopKey: DPoPJWK?  // NEW: Private JWK from backend
                let expiresIn: Int?
                
                // Custom decoder to handle optional/null dpopKey
                enum CodingKeys: String, CodingKey {
                    case accessToken, refreshToken, handle, did, pds, dpopKey, expiresIn
                }
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    accessToken = try container.decode(String.self, forKey: .accessToken)
                    refreshToken = try container.decode(String.self, forKey: .refreshToken)
                    handle = try container.decode(String.self, forKey: .handle)
                    did = try container.decode(String.self, forKey: .did)
                    pds = try container.decode(String.self, forKey: .pds)
                    expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn)
                    
                    // Try to decode dpopKey - backend sends it as nested structure
                    // First try direct decoding as DPoPJWK
                    if let directKey = try? container.decodeIfPresent(DPoPJWK.self, forKey: .dpopKey) {
                        dpopKey = directKey
                    } else {
                        // Try decoding as wrapper with nested "jwk"
                        struct DPoPKeyWrapper: Decodable {
                            let jwk: DPoPJWK
                        }
                        if let wrapper = try? container.decodeIfPresent(DPoPKeyWrapper.self, forKey: .dpopKey) {
                            dpopKey = wrapper.jwk
                        } else {
                            dpopKey = nil
                        }
                    }
                }
            }
            
            // First log the raw response to debug dpopKey format
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let dpopKeyRaw = json["dpopKey"] {
                    DevLogger.shared.log("OAuthService - dpopKey raw value: \(dpopKeyRaw)")
                } else {
                    DevLogger.shared.log("OAuthService - No dpopKey in response")
                }
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            DevLogger.shared.log("OAuthService - Parsed tokens for: \(tokenResponse.handle)")
            
            // Debug: Log expiration info
            if let expiresIn = tokenResponse.expiresIn {
                DevLogger.shared.log("OAuthService - Token expires in \(expiresIn) seconds (\(expiresIn/60) minutes)")
            } else {
                DevLogger.shared.log("OAuthService - No expiresIn from backend, using default 1 hour")
            }
            
            // Calculate expiration date
            let expiresAt: Date?
            if let expiresIn = tokenResponse.expiresIn {
                expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
                DevLogger.shared.log("OAuthService - Token will expire at: \(expiresAt!)")
            } else {
                // Default to 1 hour if not specified
                expiresAt = Date().addingTimeInterval(3600)
                DevLogger.shared.log("OAuthService - Token will expire at (default): \(expiresAt!)")
            }
            
            // Extract PDS URL from JWT token's 'aud' field
            var pdsURL = tokenResponse.pds // Use backend-provided PDS as default
            
            // Parse JWT to extract aud field (PDS URL)
            if let tokenData = tokenResponse.accessToken.split(separator: ".").dropFirst().first {
                // Add padding if needed
                let paddedBase64 = String(tokenData).padding(toLength: ((String(tokenData).count + 3) / 4) * 4,
                                                              withPad: "=",
                                                              startingAt: 0)
                
                if let decodedData = Data(base64Encoded: paddedBase64),
                   let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] {
                    DevLogger.shared.log("OAuthService - Token payload: \(json)")
                    
                    // Extract aud field (audience) which contains PDS URL
                    if let aud = json["aud"] as? String {
                        DevLogger.shared.log("OAuthService - Token audience (PDS): \(aud)")
                        
                        // Convert did:web:... to https://...
                        if aud.hasPrefix("did:web:") {
                            let host = aud.replacingOccurrences(of: "did:web:", with: "")
                            pdsURL = "https://\(host)"
                            DevLogger.shared.log("OAuthService - Extracted PDS URL: \(pdsURL)")
                        } else {
                            // Already a URL
                            pdsURL = aud
                        }
                    }
                }
            }
            
            // Log DPoP key if provided
            if let dpopKey = tokenResponse.dpopKey {
                DevLogger.shared.log("OAuthService - Backend provided DPoP key (kty: \(dpopKey.kty), crv: \(dpopKey.crv))")
            } else {
                DevLogger.shared.log("OAuthService - No DPoP key from backend")
            }
            
            return OAuthTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                handle: tokenResponse.handle,
                did: tokenResponse.did,
                pds: pdsURL,
                dpopKey: tokenResponse.dpopKey,  // Pass DPoP key from backend
                expiresAt: expiresAt
            )
            
        } catch {
            DevLogger.shared.log("OAuthService - Token exchange error: \(error)")
            throw error
        }
    }
    
    /// Present OAuth WebView (to be called from UI)
    private func presentOAuthWebView(url: URL) {
        // This will be implemented in the UI layer (OAuthWebView)
        // For now, we'll just open in Safari
        #if os(iOS)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    // Token refresh není potřeba - AT Protocol má vlastní refresh mechanismus
    // který funguje pro OAuth i App Password účty stejně.
    // Refresh se provádí přes com.atproto.server.refreshSession endpoint.
}

// MARK: - OAuth Errors

enum OAuthServiceError: LocalizedError {
    case authenticationFailed(String)
    case noAuthorizationCode
    case invalidURL
    case backendError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .noAuthorizationCode:
            return "No authorization code received"
        case .invalidURL:
            return "Invalid URL"
        case .backendError(let message):
            return "Backend error: \(message)"
        }
    }
}

// MARK: - OAuth WebView

struct OAuthWebView: UIViewRepresentable {
    let url: URL
    let onCallback: (URL) -> Void
    let onCancel: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: OAuthWebView
        
        init(_ parent: OAuthWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Check if this is our OAuth callback
            if url.scheme == OAuthConfig.urlScheme || url.host == OAuthConfig.universalLinkHost {
                DevLogger.shared.log("OAuthWebView - Got callback URL: \(url)")
                parent.onCallback(url)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DevLogger.shared.log("OAuthWebView - Navigation failed: \(error)")
            if (error as NSError).code == NSURLErrorCancelled {
                // This is expected when we intercept the callback
                return
            }
            parent.onCancel()
        }
    }
}

// MARK: - OAuth Login View

struct OAuthLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var oauthService = OAuthService()
    
    let handle: String
    let onSuccess: (OAuthTokens) -> Void
    
    @State private var webViewURL: URL?
    @State private var showWebView = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Starting OAuth...")
                        .padding()
                } else if let webViewURL = webViewURL, showWebView {
                    OAuthWebView(
                        url: webViewURL,
                        onCallback: { url in
                            oauthService.handleOAuthCallback(url: url)
                            showWebView = false
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                } else {
                    VStack(spacing: 20) {
                        Text("Sign in with Bluesky")
                            .font(.title)
                            .bold()
                        
                        Text("You'll be redirected to Bluesky to authorize Limit")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button("Continue with OAuth") {
                            startOAuth()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("OAuth Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showWebView {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onReceive(oauthService.$authError) { error in
            if let error = error {
                errorMessage = error
                isLoading = false
            }
        }
    }
    
    private func startOAuth() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let tokens = try await oauthService.startOAuthFlow(handle: handle)
                onSuccess(tokens)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}