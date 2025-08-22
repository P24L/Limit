# Building End-to-End OAuth for Bluesky: From Cloudflare Workers to iOS

## The Big Picture

When I set out to build [Limit: Social Bookmarks](https://ios.hyperlimit.app), an iOS client for Bluesky, I initially implemented App Passwords authentication. It worked, but the user experience wasn't great - users had to navigate to settings, generate an app password, copy it, and paste it into the app. I wanted something better, so I decided to tackle OAuth 2.0. This is the story of building a complete OAuth solution with DPoP (Demonstrating Proof of Possession) support, spanning from Cloudflare Workers backend to a native iOS app.

### System Architecture

```
┌─────────────┐      OAuth Flow       ┌──────────────────┐      AT Protocol     ┌──────────────┐
│   iOS App   │ ◄──────────────────►  │  OAuth Backend   │ ◄─────────────────►  │   Bluesky    │
│   (Limit)   │                       │ (Cloudflare)     │                      │ OAuth Server │
└─────────────┘                       └──────────────────┘                      └──────────────┘
      │                                        │
      │                                        ▼
      ▼                                   KV Storage
  Keychain                            (Sessions & Codes)
 (Tokens & Keys)
```

The flow involves three key players:
1. **iOS App** - Initiates OAuth, manages tokens, signs requests with DPoP
2. **OAuth Backend** - Handles OAuth flow, generates DPoP keys, manages sessions
3. **Bluesky** - Validates OAuth, issues tokens, verifies DPoP proofs

## Part 1: The Backend (Cloudflare Workers)

### The DPoP Nightmare

AT Protocol requires DPoP (Demonstrating Proof of Possession) tokens. This isn't optional - you literally cannot turn it off:

```javascript
dpop_bound_access_tokens: true // MUST be true or Bluesky rejects you
```

#### Problem 1: CryptoKey Serialization

Cloudflare Workers use the Web Crypto API, which creates `CryptoKey` objects that cannot be serialized to KV storage. When you try to store them and retrieve them later, you get:

```
Cannot read properties of undefined (reading 'includes')
```

This cryptic error happens because the CryptoKey becomes undefined after deserialization. We discovered this was a known issue ([GitHub #3292](https://github.com/bluesky-social/atproto/issues/3292)) with the AT Protocol OAuth client in Cloudflare environments.

**Solution:** Use `JoseKey` instead of `WebCryptoKey`:

```javascript
import { JoseKey } from '@atproto/jwk-jose';

// In our runtime implementation
async createKey(algs: string[]): Promise<Key> {
  return JoseKey.generate(algs); // Not WebCryptoKey!
}
```

#### Problem 2: Key Consistency Between Backend and iOS

Initially, I tried having both backend and iOS generate their own DPoP keys. Bad idea. Bluesky binds tokens to specific DPoP keys via the `cnf.jkt` claim. When iOS used a different key than the backend:

```
Invalid DPoP key binding
```

**Solution:** Backend generates the DPoP key and returns it to iOS:

```javascript
// Backend generates key during OAuth
const dpopKey = await JoseKey.generate(['ES256']);

// After successful OAuth, return to iOS
return {
  accessToken,
  refreshToken,
  dpopKey: dpopPrivateKey // iOS imports and uses this
}
```

### State Management in Stateless Environment

OAuth requires maintaining state between the authorization request and callback. With Workers being stateless, we use KV storage:

```javascript
export class KVStateStore implements StateStore {
  async set(key: string, value: InternalStateData): Promise<void> {
    // Store with proper JWK serialization
    if (value.dpopKey) {
      const jwk = value.dpopKey.jwk;
      await this.kv.put(key, JSON.stringify({
        ...value,
        dpopKey: { jwk, __type: 'stored_dpop_key' }
      }));
    }
  }
}
```

## Part 2: The iOS Implementation

### The Challenge: ATProtoKit Doesn't Support OAuth (Yet)

[ATProtoKit](https://github.com/ATProtoKit), the Swift SDK for AT Protocol, was built for App Password authentication. OAuth support is on the roadmap, but I needed it now. Fortunately, ATProtoKit's architecture is extensible enough to add our own OAuth layer.

### Architecture Overview

My iOS OAuth implementation consists of several key components:

```
         ┌─────────────────────────────────────────────┐
         │          OAuthSessionConfiguration          │
         │         (ATProtoKit Extension)              │
         └─────────────────────────────────────────────┘
                               │
                 ┌─────────────┼─────────────┐
                 ▼             ▼             ▼
┌────────────────────┐ ┌───────────────────┐ ┌─────────────────────┐
│ OAuthAuthenticator │ │ OAuthTokenManager │ │ DPoPRequestExecutor │
└────────────────────┘ └───────────────────┘ └─────────────────────┘
                  │             │             │
                  └─────────────┼─────────────┘
                                ▼
                         ┌──────────────┐
                         │  Keychain    │
                         │  Storage     │
                         └──────────────┘
```

### Extending ATProtoKit

ATProtoKit uses a `SessionConfiguration` protocol for authentication. I created `OAuthSessionConfiguration` that implements this protocol:

```swift
public final class OAuthSessionConfiguration: SessionConfiguration {
    // OAuth-specific properties
    private var oauthTokens: OAuthTokens?
    private let keychainPrefix: String
    
    // ATProtoKit protocol requirements
    public func authenticate(with handle: String, password: String) async throws {
        // For OAuth, we don't use password auth
        throw OAuthError.notSupported
    }
    
    // Custom OAuth method
    public func authenticateWithOAuth(tokens: OAuthTokens) async throws {
        self.oauthTokens = tokens
        saveTokens(tokens)
        
        // Create ATProtoKit session
        let session = UserSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            handle: tokens.handle,
            did: tokens.did,
            // ... other properties
        )
        
        await updateSession(session, service: tokens.pds)
    }
}
```

### DPoP Implementation: The Heart of Security

DPoP requires creating a JWT proof for every API request. Each proof must:
1. Include the HTTP method and URL
2. Be signed with the private key
3. Include a nonce (if the server requires it)
4. Have a unique JWT ID (jti)

```swift
final class DPoPProofGenerator {
    func generateProof(
        keyContext: DPoPKeyContext,
        method: String,
        url: URL,
        accessToken: String? = nil
    ) async throws -> String {
        // Get nonce if available
        let nonce = await nonceManager.getNonce(for: url.host ?? "")
        
        // Create JWT header with public key
        let header = DPoPHeader(jwk: keyContext.publicKeyJWK)
        
        // Create JWT payload
        var payload = DPoPPayload(
            jti: UUID().uuidString,
            htm: method.uppercased(),
            htu: url.absoluteString.components(separatedBy: "?").first!,
            iat: Date()
        )
        
        // Add access token hash for resource requests
        if let accessToken = accessToken {
            payload.ath = SHA256.hash(data: accessToken.data(using: .utf8)!)
                .base64URLEncodedString()
        }
        
        // Add nonce if server provided one
        if let nonce = nonce {
            payload.nonce = nonce
        }
        
        // Sign with ES256
        return createAndSignJWT(header: header, payload: payload, 
                              privateKey: keyContext.privateKey)
    }
}
```

### The Nonce Dance

Bluesky's servers require a nonce for DPoP proofs to prevent replay attacks. But here's the catch: you don't know you need a nonce until you try without one. The server responds with 401 and provides a nonce in the `DPoP-Nonce` header.

My solution: Automatic retry with nonce management:

```swift
actor DPoPNonceManager {
    private var nonces: [String: String] = [:]
    private var nonceExpirations: [String: Date] = [:]
    
    func getNonce(for serverHost: String) -> String? {
        if let expiration = nonceExpirations[serverHost], 
           expiration > Date() {
            return nonces[serverHost]
        }
        return nil
    }
    
    func updateNonce(_ nonce: String, for serverHost: String) {
        nonces[serverHost] = nonce
        nonceExpirations[serverHost] = Date().addingTimeInterval(300) // 5 min
    }
}
```

The request executor handles the retry logic:

```swift
class DPoPRequestExecutor: RequestExecutor {
    func execute(request: URLRequest) async throws -> (Data, URLResponse) {
        var modifiedRequest = request
        
        // Generate DPoP proof
        let dpopProof = try await generateDPoPProof(for: request)
        modifiedRequest.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        
        // Try request
        let (data, response) = try await urlSession.data(for: modifiedRequest)
        
        // Check for nonce error
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401,
           let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce") {
            
            // Update nonce and retry
            await nonceManager.updateNonce(nonce, for: request.url!.host!)
            let newProof = try await generateDPoPProof(for: request)
            modifiedRequest.setValue(newProof, forHTTPHeaderField: "DPoP")
            
            return try await urlSession.data(for: modifiedRequest)
        }
        
        return (data, response)
    }
}
```

### Token Refresh: The Silent Hero

Access tokens expire after 1 hour. The app needs to refresh them seamlessly:

```swift
class OAuthRefreshService {
    func refreshTokens(refreshToken: String, accountUUID: UUID) async throws -> OAuthTokens {
        // Check for active refresh to prevent duplicates
        if let existingTask = activeRefreshTasks[accountUUID] {
            return try await existingTask.value
        }
        
        // Create refresh request with DPoP
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        
        // Generate DPoP proof for token endpoint
        let dpopProof = try await DPoPProofGenerator.shared.generateProof(
            keyContext: DPoPKeyContext(accountUUID: accountUUID),
            method: "POST",
            url: tokenEndpoint
        )
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        
        // Add refresh token and client_id
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]
        
        // Execute with retry logic for nonce
        return try await performRefreshWithRetry(request: request)
    }
}
```

### Problems I Hit 

#### Problem 1: DPoP Key Import
> Using the [ATCryptography](https://github.com/ATProtoKit/ATCryptography) library might improve this.

The backend sends the DPoP private key as JWK. iOS needs to import it as a P256 key:

```swift
func importDPoPKey(from jwk: DPoPJWK, for accountUUID: UUID) throws {
    // Decode base64url private key component
    guard let dData = Data(base64URLEncoded: jwk.d) else {
        throw DPoPError.invalidJWKData
    }
    
    // Create P256 private key
    let privateKey = try P256.Signing.PrivateKey(rawRepresentation: dData)
    
    // Verify public key matches
    let publicKey = privateKey.publicKey
    let computedX = publicKey.x963Representation[1...32].base64URLEncodedString()
    let computedY = publicKey.x963Representation[33...64].base64URLEncodedString()
    
    guard computedX == jwk.x && computedY == jwk.y else {
        throw DPoPError.keyMismatch
    }
    
    // Save to keychain
    saveKeypairToKeychain(privateKey, for: accountUUID)
}
```

#### Problem 2: Token Expiration Detection

The backend doesn't always send token expiration. I calculate it:

```swift
func saveTokens(_ tokens: OAuthTokens) {
    // Calculate expiration if not provided
    let expiresAt = tokens.expiresAt ?? Date().addingTimeInterval(3600) // 1 hour
    
    // Save as ISO8601 for consistency
    let expiresAtString = ISO8601DateFormatter().string(from: expiresAt)
    keychain.set(expiresAtString, forKey: "\(keychainPrefix).expiresAt")
}

func needsTokenRefresh() -> Bool {
    guard let expiresAtString = keychain.get("\(keychainPrefix).expiresAt"),
          let expiresAt = ISO8601DateFormatter().date(from: expiresAtString) else {
        return true // Refresh if no expiration found
    }
    
    // Refresh 5 minutes before expiration
    return expiresAt.timeIntervalSinceNow < 300
}
```


## Part 3: Putting It All Together

### The Complete OAuth Flow

1. **User initiates login in iOS app**
   ```swift
   let authenticator = OAuthAuthenticator()
   let authURL = try await authenticator.startOAuth(handle: "user.bsky.social")
   // Open authURL in ASWebAuthenticationSession
   ```

2. **Backend creates OAuth session**
   ```javascript
   // Generate DPoP key for this session
   const dpopKey = await JoseKey.generate(['ES256']);
   const authUrl = await oauthClient.authorize(handle, { dpopKey });
   ```

3. **User authorizes in Bluesky**
   - Bluesky shows consent screen
   - User approves
   - Redirects back with authorization code

4. **Backend exchanges code for tokens**
   ```javascript
   const result = await oauthClient.callback(params);
   const tokens = {
     accessToken: result.session.accessToken,
     refreshToken: result.session.refreshToken,
     dpopKey: dpopKey.toJWK() // Send private key to iOS
   };
   ```

5. **iOS receives and stores tokens**
   ```swift
   let tokens = try await authenticator.exchangeCode(code)
   try await config.authenticateWithOAuth(tokens: tokens)
   
   // Import DPoP key
   try DPoPKeyManager.shared.importDPoPKey(from: tokens.dpopKey, 
                                           for: accountUUID)
   ```

6. **iOS makes authenticated requests**
   ```swift
   // ATProtoKit automatically uses our DPoPRequestExecutor
   let timeline = try await atProtoKit.getTimeline()
   // Each request includes DPoP proof with proper nonce
   ```

### Performance Considerations

The subsequent requests:
- DPoP proof generation: ~10ms
- Nonce retry (when needed): +200ms
- Token refresh: ~1 second

### Security Architecture

```
┌─────────────────────────────────────┐
│         iOS Keychain                │
├─────────────────────────────────────┤
│ oauth.{uuid}.accessToken            │ ← Encrypted at rest
│ oauth.{uuid}.refreshToken           │ ← Never exposed to UI
│ dpop.keypair.{uuid}                 │ ← ES256 private key
│ oauth.{uuid}.handle                 │ ← User identifier
│ oauth.{uuid}.did                    │ ← Decentralized ID
└─────────────────────────────────────┘
```

Each account has isolated storage, preventing cross-contamination.

## Lessons Learned

1. **ATProtoKit's extensibility saved me.** The `SessionConfiguration` protocol and `RequestExecutor` pattern made OAuth integration possible without forking the library.

2. **DPoP is complex.** 

3. **Nonce handling needs retry logic.** You can't predict when a server will require a nonce.

4. **Backend and iOS must coordinate closely.** The DPoP key handoff is critical.

5. **Cloudflare Workers require creativity.** Platform limitations force interesting solutions (like JoseKey vs WebCryptoKey).

## What I'd Do Differently

1. **Start with a Node.js backend** for OAuth, then optimize to Workers if needed
2. **Document the DPoP key flow better** - it's the most confusing part

## The Result

I now have a production OAuth implementation that:
- Supports multiple accounts seamlessly
- Refreshes tokens automatically
- Handles DPoP security properly
- Integrates cleanly with ATProtoKit

Is it more complex than App Passwords? Absolutely. Is it worth it? When users seamlessly switch between accounts without ever seeing a password prompt, the answer is clear.

## Code Repositories

- Backend: Not published yet. TODO. [Contact me](https://bsky.app/profile/p24l.bsky.social ) and I'll share it with you. 
- iOS: [Limit App](https://github.com/P24L/Limit) (The source code with OAuth will be available soon, once I finish polishing it)
---

*Built with frustration, debugged with determination, shipped with pride.*
