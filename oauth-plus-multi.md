# Bluesky OAuth iOS Implementation Guide with ATProtoKit

## Critical Implementation Details for Claude Code

### Token Lifecycle
**IMPORTANT: Tokens expire quickly!**
- Access tokens expire in 1-2 hours (NOT days!)
- Refresh tokens are ROTATING (single-use) in Bluesky
- After refresh, you MUST save the new refresh token immediately
- Old refresh token becomes invalid after use
- Background refresh every 30 minutes for inactive accounts
- NEVER refresh same account in parallel (will invalidate tokens)

### Keychain Namespace Strategy
**CRITICAL for multi-account:**
- Default ATProtoKit uses simple keys: `"access_token"`, `"refresh_token"`
- Multi-account MUST use UUID namespaced keys: `"com.app.account.{uuid}.access_token"`
- You MUST implement this in your custom SessionConfiguration
- Each account must have completely isolated keychain storage

### Memory Management Rules
**PERFORMANCE - Don't hold all ATProtoKit instances:**
- Create ATProtoKit instance ONLY for the active account
- When switching accounts, release old instance, create new one
- Background token refresh should use SessionConfiguration directly (no ATProtoKit needed)
- Keep only one active ATProtoKit instance at any time

### OAuth Callback Configuration
**Info.plist URL Scheme explanation:**
- The URL scheme is for WebView → iOS App redirect (NOT for backend URL)
- Example: `"myapp://"` catches OAuth callback from WebView
- Backend redirects to: `"myapp://auth-callback?code=..."`
- iOS app intercepts this URL and closes WebView

### Common Pitfalls to Avoid
1. **DON'T** create ATProtoKit instance for each account (memory waste)
2. **DON'T** forget to save new refresh token after each refresh (will lose access)
3. **DON'T** refresh same account from multiple threads (token invalidation)
4. **DON'T** use default keychain keys for multi-account (token conflicts)
5. **DON'T** assume tokens last for days (they expire in hours)

## Part 1: Multi-Account Support in ATProtoKit

### ATProtoKit Has Built-in Multi-Account Support! 🎉

ATProtoKit is designed with multi-account functionality from the ground up. You don't need to hack around it - it's a first-class feature.

### Key Components for Multi-Account

#### Understanding the Hierarchy
```
UserSessionRegistry (singleton - manages all sessions)
    ↓ holds
UserSession objects (data for individual accounts)
    ↓ uses
SessionConfiguration (how to authenticate)
    ↓ used by
ATProtoKit instance (API client for calls)
```

**IMPORTANT:** UserSessionRegistry is above ATProtoKit in hierarchy. Registry holds all sessions, but only one ATProtoKit instance should be active.

#### UserSessionRegistry - The Account Manager
```swift
// ATProtoKit provides an actor for managing multiple sessions
actor UserSessionRegistry {
    static var shared: UserSessionRegistry  // Singleton
    
    func register(_ id: UUID, session: UserSession)
    func getSession(for: UUID) -> UserSession?
    func containsSession(for: UUID) -> Bool
    func removeSession(for: UUID)
}
```

#### Architecture Overview
```
UserSessionRegistry (singleton)
    ├── Account1 UUID → UserSession (alice.bsky.social)
    ├── Account2 UUID → UserSession (bob.bsky.social)  
    └── Account3 UUID → UserSession (custom.domain.com)

Each account has:
- Own SessionConfiguration instance with unique UUID
- Own Keychain namespace (MUST be UUID-prefixed)
- Own ATProtoKit instance (create only when active, not all at once)
```

### Implementation Strategy

#### 1. Custom OAuth SessionConfiguration with Keychain Namespacing
Create your own class conforming to `SessionConfiguration`:
```swift
class OAuthSessionConfiguration: SessionConfiguration {
    let instanceUUID: UUID  // Unique per account
    let keychainProtocol: SecureKeychainProtocol
    let pdsURL: String
    
    // CRITICAL: Override keychain storage with UUID namespace
    func saveToKeychain(accessToken: String, refreshToken: String) async {
        let prefix = "com.yourapp.account.\(instanceUUID)"
        await keychainProtocol.save(accessToken, forKey: "\(prefix).accessToken")
        await keychainProtocol.save(refreshToken, forKey: "\(prefix).refreshToken")
    }
    
    // OAuth-specific authentication
    func authenticateWithOAuth(tokens: OAuthTokens) async
}
```

#### 2. Adding New Account via OAuth
1. User taps "Add Account"
2. OAuth flow → get tokens
3. Create new `OAuthSessionConfiguration` with new UUID
4. Register session in `UserSessionRegistry`
5. Store tokens in Keychain under UUID namespace

#### 3. Switching Between Accounts (No Re-Auth!)
```swift
// NO logout needed! Just change active UUID
activeAccountUUID = account2UUID

// IMPORTANT: Release old ATProtoKit instance, create new one
oldATProtoKit = nil  // Release memory
let session = UserSessionRegistry.shared.getSession(for: activeAccountUUID)
let config = OAuthSessionConfiguration(uuid: activeAccountUUID)
activeATProtoKit = ATProtoKit(sessionConfiguration: config)
```

#### 4. Background Token Refresh Strategy
```swift
// Refresh tokens for inactive accounts WITHOUT creating ATProtoKit instances
func refreshInactiveAccountTokens() async {
    for (uuid, _) in accounts where uuid != activeAccountUUID {
        // Just create lightweight config, no ATProtoKit
        let config = OAuthSessionConfiguration(uuid: uuid)
        
        // Check if token expires soon (< 30 minutes)
        if let expiry = getTokenExpiry(for: uuid), expiry < Date().addingTimeInterval(1800) {
            do {
                try await config.refreshSession()
                // New refresh token is automatically saved by config
            } catch {
                // Handle refresh failure - may need re-auth
            }
        }
    }
}

// Run every 30 minutes in background
Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
    Task { await refreshInactiveAccountTokens() }
}
```

#### 5. Persist UUID Mapping
```swift
// Store mapping in UserDefaults for persistence
struct AccountMapping: Codable {
    let uuid: UUID
    let handle: String
    let addedDate: Date
}

class AccountManager {
    func saveAccountMapping(_ mapping: AccountMapping) {
        var mappings = loadAllMappings()
        mappings[mapping.uuid.uuidString] = mapping
        UserDefaults.standard.set(try? JSONEncoder().encode(mappings), forKey: "accountMappings")
    }
    
    func loadAllMappings() -> [String: AccountMapping] {
        guard let data = UserDefaults.standard.data(forKey: "accountMappings"),
              let mappings = try? JSONDecoder().decode([String: AccountMapping].self, from: data) else {
            return [:]
        }
        return mappings
    }
    
    // Quick lookup: handle → UUID
    func findUUID(for handle: String) -> UUID? {
        loadAllMappings().values.first { $0.handle == handle }?.uuid
    }
}
```

### Benefits of This Approach

- **Instant switching** - Just change UUID reference, no re-auth
- **Parallel operations** - Can have multiple ATProtoKit instances active
- **Isolated accounts** - Each has own UUID and keychain space
- **Mix auth types** - OAuth and App Password accounts side by side

### Migration Path from App Passwords

1. **Existing App Password accounts** → Use `ATProtocolConfiguration` (default)
2. **New OAuth accounts** → Use your `OAuthSessionConfiguration`
3. **Both types coexist** in `UserSessionRegistry`
4. **Gradual migration** - Offer OAuth upgrade on next login

### Implementation Tips

- **Memory Management: Create ATProtoKit only for active account**
  - Release old instance when switching accounts
  - Never hold all instances in memory simultaneously
  
- **Token Refresh Strategy:**
  - Run background refresh every 30 minutes
  - Refresh tokens for inactive accounts using SessionConfiguration only (no ATProtoKit)
  - Serialize refresh operations per account to avoid race conditions
  - Always save new refresh token immediately after refresh
  
- **UUID Persistence:**
  - Store UUID ↔ handle mapping in UserDefaults
  - This survives app reinstalls if backed up
  - Allows showing user-friendly account list
  
- **Lazy Loading Best Practices:**
  - Create ATProtoKit instance only when switching to account
  - Background operations use SessionConfiguration directly
  - Token refresh doesn't require ATProtoKit instance

---

## Part 2: OAuth Implementation for Bluesky PDS

### Overview
This implementation supports OAuth for Bluesky PDS (bsky.social) including custom domains that use Bluesky's PDS. No external dependencies like Slingshot are required for this basic implementation.

### Backend Implementation (Node.js/Express)

#### Complete OAuth Server for bsky.social PDS Only

```javascript
const express = require('express');
const crypto = require('crypto');
const fetch = require('node-fetch');
const dns = require('dns').promises;

const app = express();
app.use(express.json());

// Configuration
const CLIENT_ID = 'https://your-app.com/client-metadata.json';
const BASE_URL = 'https://your-backend.com';
const BSKY_PDS = 'https://bsky.social';

// Temporary session storage (use Redis in production)
const sessions = new Map();

// Resolve handle to identity (supports custom domains on bsky.social)
async function resolveHandle(handle) {
    console.log(`Resolving handle: ${handle}`);
    
    // 1. Direct bsky.social handles
    if (handle.endsWith('.bsky.social')) {
        return {
            handle,
            pds: BSKY_PDS,
            did: null // Will get from OAuth response
        };
    }
    
    // 2. Try DNS resolution for custom domains
    try {
        const txtRecords = await dns.resolveTxt(`_atproto.${handle}`);
        
        for (const record of txtRecords) {
            const txt = record.join('');
            if (txt.startsWith('did=')) {
                const did = txt.substring(4);
                
                // Verify this DID uses bsky.social PDS
                const plcResponse = await fetch(`https://plc.directory/${did}`);
                if (plcResponse.ok) {
                    const didDoc = await plcResponse.json();
                    
                    const pdsService = didDoc.service?.find(
                        s => s.id === '#atproto_pds' || 
                            s.type === 'AtprotoPersonalDataServer'
                    );
                    
                    if (pdsService?.serviceEndpoint?.includes('bsky.social')) {
                        return {
                            handle,
                            did,
                            pds: BSKY_PDS
                        };
                    } else {
                        throw new Error('Handle does not use bsky.social PDS');
                    }
                }
            }
        }
    } catch (error) {
        console.log(`DNS resolution failed: ${error.message}`);
    }
    
    // 3. Fallback to HTTP resolution via bsky.social
    try {
        const response = await fetch(
            `${BSKY_PDS}/xrpc/com.atproto.identity.resolveHandle?handle=${handle}`
        );
        
        if (response.ok) {
            const data = await response.json();
            return {
                handle,
                did: data.did,
                pds: BSKY_PDS
            };
        }
    } catch (error) {
        console.log(`HTTP resolution failed: ${error.message}`);
    }
    
    throw new Error(`Could not resolve handle: ${handle}`);
}

// Generate PKCE challenge
function generatePKCE() {
    const verifier = crypto.randomBytes(32).toString('base64url');
    const challenge = crypto
        .createHash('sha256')
        .update(verifier)
        .digest('base64url');
    return { verifier, challenge };
}

// Start OAuth flow
app.post('/api/auth/start', async (req, res) => {
    try {
        const { handle } = req.body;
        
        if (!handle) {
            return res.status(400).json({ error: 'Handle is required' });
        }
        
        // Resolve handle (works for both bsky.social and custom domains)
        let identity;
        try {
            identity = await resolveHandle(handle);
        } catch (error) {
            return res.status(400).json({ 
                error: 'Only Bluesky accounts (bsky.social PDS) are supported.' 
            });
        }
        
        // Generate PKCE and session
        const { verifier, challenge } = generatePKCE();
        const sessionId = crypto.randomUUID();
        
        // Store session data
        sessions.set(sessionId, {
            handle: identity.handle,
            did: identity.did,
            verifier,
            timestamp: Date.now()
        });
        
        // Build OAuth URL
        const params = new URLSearchParams({
            response_type: 'code',
            client_id: CLIENT_ID,
            redirect_uri: `${BASE_URL}/callback`,
            scope: 'atproto transition:generic',
            state: sessionId,
            code_challenge: challenge,
            code_challenge_method: 'S256',
            login_hint: identity.handle
        });
        
        const authUrl = `${BSKY_PDS}/oauth/authorize?${params}`;
        
        res.json({ 
            authUrl,
            handle: identity.handle
        });
        
    } catch (error) {
        console.error('Start OAuth error:', error);
        res.status(500).json({ error: error.message });
    }
});

// OAuth callback from bsky.social
app.get('/callback', async (req, res) => {
    try {
        const { code, state: sessionId, error } = req.query;
        
        if (error) {
            return res.redirect(`your-app://auth?error=${error}`);
        }
        
        const session = sessions.get(sessionId);
        if (!session) {
            throw new Error('Invalid or expired session');
        }
        
        // Exchange code for tokens
        const tokenResponse = await fetch(`${BSKY_PDS}/oauth/token`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                grant_type: 'authorization_code',
                code,
                redirect_uri: `${BASE_URL}/callback`,
                client_id: CLIENT_ID,
                code_verifier: session.verifier
            })
        });
        
        if (!tokenResponse.ok) {
            throw new Error('Token exchange failed');
        }
        
        const tokens = await tokenResponse.json();
        
        // Create exchange code for iOS app
        const exchangeCode = crypto.randomUUID();
        sessions.set(exchangeCode, {
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            handle: session.handle,
            did: tokens.sub || session.did,
            timestamp: Date.now()
        });
        
        // Clean up OAuth session
        sessions.delete(sessionId);
        
        // Redirect to iOS app
        res.redirect(`your-app://auth?code=${exchangeCode}`);
        
    } catch (error) {
        console.error('Callback error:', error);
        res.redirect('your-app://auth?error=authentication_failed');
    }
});

// Exchange code for tokens (called by iOS app)
app.post('/api/auth/tokens', async (req, res) => {
    try {
        const { code } = req.body;
        
        const data = sessions.get(code);
        if (!data) {
            return res.status(400).json({ error: 'Invalid or expired code' });
        }
        
        sessions.delete(code);
        
        res.json({
            accessToken: data.access_token,
            refreshToken: data.refresh_token,
            handle: data.handle,
            did: data.did,
            pds: BSKY_PDS
        });
        
    } catch (error) {
        console.error('Token exchange error:', error);
        res.status(500).json({ error: 'Token exchange failed' });
    }
});

// Serve OAuth client metadata
app.get('/client-metadata.json', (req, res) => {
    res.json({
        client_id: CLIENT_ID,
        client_name: 'Your App Name',
        redirect_uris: [`${BASE_URL}/callback`],
        scope: 'atproto transition:generic',
        grant_types: ['authorization_code', 'refresh_token'],
        response_types: ['code'],
        token_endpoint_auth_method: 'none',
        dpop_bound_access_tokens: true
    });
});

// Clean up expired sessions
setInterval(() => {
    const ONE_HOUR = 60 * 60 * 1000;
    const now = Date.now();
    
    for (const [key, value] of sessions.entries()) {
        if (value.timestamp && (now - value.timestamp) > ONE_HOUR) {
            sessions.delete(key);
        }
    }
}, 5 * 60 * 1000);

app.listen(3000, () => {
    console.log('OAuth server running on port 3000');
    console.log('Supported: *.bsky.social and custom domains using bsky.social PDS');
});
```

### iOS Implementation

#### 1. OAuth Service with Multi-Account Support

```swift
import Foundation
import ATProtoKit

// OAuth configuration for Limit app
struct LimitOAuthConfig {
    static let backendURL = "https://auth.hyperlimit.app"
    static let urlScheme = "limit"
    static let appName = "Limit: Social Bookmarks"
}

// Custom SessionConfiguration for OAuth with proper keychain namespacing
class OAuthSessionConfiguration: SessionConfiguration {
    let instanceUUID: UUID
    let pdsURL: String
    let keychainProtocol: SecureKeychainProtocol
    let configuration: URLSessionConfiguration
    
    // OAuth-specific properties
    private var oauthTokens: OAuthTokens?
    
    init(handle: String, tokens: OAuthTokens) {
        self.instanceUUID = UUID()
        self.pdsURL = "https://bsky.social"
        self.keychainProtocol = AppleSecureKeychain()
        self.configuration = .default
        self.oauthTokens = tokens
        
        // Store tokens in keychain with UUID namespace
        Task {
            try? await saveTokensToKeychain(tokens)
        }
    }
    
    // CRITICAL: UUID-namespaced keychain storage
    private func saveTokensToKeychain(_ tokens: OAuthTokens) async throws {
        let prefix = "com.yourapp.account.\(instanceUUID.uuidString)"
        
        try await keychainProtocol.save(
            tokens.accessToken,
            forKey: "\(prefix).accessToken"
        )
        
        try await keychainProtocol.save(
            tokens.refreshToken,
            forKey: "\(prefix).refreshToken"
        )
        
        try await keychainProtocol.save(
            tokens.handle,
            forKey: "\(prefix).handle"
        )
        
        try await keychainProtocol.save(
            tokens.did,
            forKey: "\(prefix).did"
        )
    }
    
    // Override refresh to handle rotating refresh tokens
    func refreshSession() async throws {
        let prefix = "com.yourapp.account.\(instanceUUID.uuidString)"
        
        guard let refreshToken = try? await keychainProtocol.retrieve(key: "\(prefix).refreshToken") else {
            throw OAuthError.noRefreshToken
        }
        
        // Call refresh endpoint
        let newTokens = try await performTokenRefresh(refreshToken)
        
        // CRITICAL: Save NEW refresh token immediately
        try await saveTokensToKeychain(newTokens)
        
        // Update UserSessionRegistry
        // ...
    }
}

// Main OAuth Service managing multiple accounts
@MainActor
class OAuthService: ObservableObject {
    @Published var accounts: [UUID: String] = [:] // UUID -> handle mapping
    @Published var activeAccountId: UUID?
    
    private let backendURL = "https://your-backend.com"
    private let registry = UserSessionRegistry.shared
    private var activeATProtoKit: ATProtoKit?  // Only one instance!
    
    // Timer for background token refresh
    private var refreshTimer: Timer?
    
    init() {
        // Start background refresh timer
        startBackgroundRefresh()
    }
    
    // Add new account via OAuth
    func addAccount(handle: String) async throws {
        // Start OAuth flow
        let authURL = try await startOAuthFlow(handle: handle)
        
        // Present WebView and wait for callback
        // ... WebView handling ...
        
        // After successful OAuth callback
        let tokens = try await exchangeCodeForTokens(code: callbackCode)
        
        // Create OAuth session configuration with new UUID
        let config = OAuthSessionConfiguration(handle: handle, tokens: tokens)
        
        // Create user session
        let userSession = UserSession(
            handle: tokens.handle,
            sessionDID: tokens.did,
            serviceEndpoint: URL(string: "https://bsky.social")!,
            pdsURL: "https://bsky.social"
        )
        
        // Register in UserSessionRegistry
        await registry.register(config.instanceUUID, session: userSession)
        
        // Track account
        accounts[config.instanceUUID] = handle
        saveAccountMappings()
        
        // Set as active if first account
        if activeAccountId == nil {
            await switchToAccount(id: config.instanceUUID)
        }
    }
    
    // Switch between accounts - lazy loading
    func switchToAccount(id: UUID) async {
        guard accounts[id] != nil else { return }
        
        // Release old ATProtoKit instance
        activeATProtoKit = nil
        
        // Update active account
        activeAccountId = id
        
        // Create new ATProtoKit for active account only
        guard let session = await registry.getSession(for: id) else { return }
        
        // Load config for this account
        let config = OAuthSessionConfiguration(uuid: id)  // Load from keychain
        
        // Create new ATProtoKit instance
        activeATProtoKit = await ATProtoKit(sessionConfiguration: config)
    }
    
    // Background refresh for inactive accounts
    private func startBackgroundRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            Task { await self.refreshInactiveAccounts() }
        }
    }
    
    private func refreshInactiveAccounts() async {
        for (uuid, _) in accounts where uuid != activeAccountId {
            // Create config without ATProtoKit
            let config = OAuthSessionConfiguration(uuid: uuid)
            
            // Check token expiry
            if shouldRefreshToken(for: uuid) {
                do {
                    // Refresh using config only, no ATProtoKit needed
                    try await config.refreshSession()
                    print("Refreshed tokens for account: \(uuid)")
                } catch {
                    print("Failed to refresh account \(uuid): \(error)")
                    // May need re-authentication
                }
            }
        }
    }
    
    // Persist UUID mappings
    private func saveAccountMappings() {
        let mappings = accounts.map { AccountMapping(uuid: $0.key, handle: $0.value) }
        UserDefaults.standard.set(try? JSONEncoder().encode(mappings), forKey: "accountMappings")
    }
    
    private func loadAccountMappings() {
        guard let data = UserDefaults.standard.data(forKey: "accountMappings"),
              let mappings = try? JSONDecoder().decode([AccountMapping].self, from: data) else {
            return
        }
        
        accounts = Dictionary(uniqueKeysWithValues: mappings.map { ($0.uuid, $0.handle) })
    }
    
    private func startOAuthFlow(handle: String) async throws -> URL {
        let url = URL(string: "\(backendURL)/api/auth/start")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["handle": handle])
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(StartResponse.self, from: data)
        
        return URL(string: response.authUrl)!
    }
    
    private func exchangeCodeForTokens(code: String) async throws -> OAuthTokens {
        let url = URL(string: "\(backendURL)/api/auth/tokens")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["code": code])
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(OAuthTokens.self, from: data)
    }
}
```

#### 2. SwiftUI Account Switcher

```swift
import SwiftUI

struct AccountSwitcherView: View {
    @StateObject private var oauthService = OAuthService()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Active Account") {
                    if let activeId = oauthService.activeAccountId,
                       let handle = oauthService.accounts[activeId] {
                        Label(handle, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                
                Section("All Accounts") {
                    ForEach(Array(oauthService.accounts), id: \.key) { id, handle in
                        Button(action: {
                            oauthService.switchToAccount(id: id)
                        }) {
                            HStack {
                                Text(handle)
                                Spacer()
                                if id == oauthService.activeAccountId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button("Add Account") {
                        // Show OAuth login flow
                    }
                }
            }
            .navigationTitle("Accounts")
        }
    }
}
```

### Configuration Files

#### Info.plist Configuration for Limit app
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>limit</string>
        </array>
        <key>CFBundleURLName</key>
        <string>app.hyperlimit</string>
    </dict>
</array>
```

#### Package.swift Dependencies
```swift
dependencies: [
    .package(url: "https://github.com/MasterJ93/ATProtoKit.git", from: "0.19.0")
]
```

### Future Considerations

#### Support for Other PDS Servers
Currently this implementation only supports bsky.social PDS. To support other PDS servers in the future:

1. **Use Slingshot Service** - Simplifies handle resolution across all PDS servers
2. **Implement Full Resolution** - DNS → HTTP → DID Document → PDS Discovery
3. **Dynamic OAuth Discovery** - Each PDS has different OAuth endpoints
4. **DPoP Implementation** - Required for full AT Protocol compliance

#### When to Consider Slingshot
- Supporting self-hosted PDS servers
- Handling complex domain resolutions
- Reducing implementation complexity
- Getting production-ready robustness

### Testing Checklist

- [ ] OAuth flow with .bsky.social handles
- [ ] OAuth flow with custom domains (e.g., alice.com)
- [ ] Adding multiple accounts
- [ ] Switching between accounts (instant, no re-auth)
- [ ] Token refresh for inactive accounts
- [ ] App restart with persistent sessions
- [ ] Logout single account
- [ ] Parallel operations on multiple accounts

### Security Notes

- Never store tokens outside Keychain
- Use UUID namespacing for multi-account isolation
- Implement token refresh before expiration
- Clear tokens on account removal
- Use HTTPS for all backend communication

### Production Deployment

1. **Backend**: Deploy with HTTPS, add Redis for sessions
2. **iOS**: Remove debug URLs, implement proper error handling
3. **Monitoring**: Track OAuth success rates, token refresh failures
4. **Testing**: Test with various handle formats and network conditions