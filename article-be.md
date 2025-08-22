# Building an OAuth Backend for Bluesky on Cloudflare Workers

## The Problem

When building the Limit iOS app for Bluesky, we needed OAuth authentication. Sounds simple, right? Well, not when you're dealing with AT Protocol's specific requirements and Cloudflare Workers' runtime limitations. This is the story of how we built a working OAuth backend, the walls we hit, and the creative solutions we found.

## Architecture Overview

Our OAuth service runs on Cloudflare Workers with KV storage for session management. The architecture is deliberately simple:

```
iOS App ←→ OAuth Backend (Workers) ←→ Bluesky OAuth Server
              ↓
         KV Storage
```

### Key Components

1. **`/api/auth/start`** - Initiates OAuth flow
2. **`/callback`** - Handles OAuth callback from Bluesky
3. **`/api/auth/tokens`** - Exchanges temporary code for tokens
4. **KV Namespaces** - `OAUTH_SESSIONS` and `EXCHANGE_CODES`

## The DPoP Nightmare

AT Protocol requires DPoP (Demonstrating Proof of Possession) tokens. This isn't optional - you literally cannot turn it off:

```javascript
dpop_bound_access_tokens: true // MUST be true or Bluesky rejects you
```

### Problem 1: CryptoKey Serialization

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

### Problem 2: Private Keys in Client Metadata

The OAuth client validation has a fun quirk - it checks that your DPoP keys are in the client metadata, but then rejects private keys in metadata:

```
Error: "private key not allowed"
```

This seems like a Catch-22: you need the private key for DPoP signatures, but can't put it in metadata.

**The Revelation:** The `Keyset` class has a `toJSON()` method that automatically exports only public keys. The library expects you to:
1. Keep private keys in the Keyset for signing
2. Let it export only public parts for metadata

But wait, there's more complexity...

### Problem 3: Key Consistency Between Backend and iOS

Initially, we tried having both backend and iOS generate their own DPoP keys. Bad idea. Bluesky binds tokens to specific DPoP keys via the `cnf.jkt` claim. When iOS used a different key than the backend, we got:

```
Invalid DPoP key binding
```

**Final Solution:** Backend generates the DPoP key and returns it to iOS:

```javascript
// Backend generates key during OAuth
const dpopKey = await JoseKey.generate(['ES256']);

// After successful OAuth, extract the key from session
const sessionData = await env.OAUTH_SESSIONS.get(`session:${did}`, 'json');
const dpopPrivateKey = sessionData.dpopKey;

// Return it to iOS with the tokens
return {
  accessToken,
  refreshToken,
  dpopKey: dpopPrivateKey // iOS uses this for all API requests
}
```

## Implementation Details

### OAuth Client Wrapper

We created a wrapper around the AT Protocol OAuth client to handle Workers-specific issues:

```javascript
export class WorkersOAuthClient {
  constructor(env: Env) {
    // Custom handle resolver (DNS not available in Workers)
    const options = {
      handleResolver: {
        resolve: async (handle: string) => {
          const response = await fetch(
            `https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=${handle}`,
            { cf: { cacheEverything: true, cacheTtl: 300 }}
          );
          const data = await response.json();
          return { did: data.did, pds: undefined };
        }
      },
      // ... other options
    };
    
    this.client = new OAuthClient(options);
  }
}
```

### State Management

OAuth requires maintaining state between the authorization request and callback. With Workers being stateless, we use KV storage:

```javascript
// Store state with DPoP key
export class KVStateStore implements StateStore {
  async set(key: string, value: InternalStateData): Promise<void> {
    // Reconstruct JoseKey from JWK after retrieval
    if (value.dpopKey) {
      const jwk = value.dpopKey.jwk;
      await this.kv.put(key, JSON.stringify({
        ...value,
        dpopKey: { jwk, __type: 'stored_dpop_key' }
      }));
    }
  }

  async get(key: string): Promise<InternalStateData | undefined> {
    const data = await this.kv.get(key, 'json');
    if (data?.dpopKey?.jwk) {
      // Reconstruct the JoseKey from stored JWK
      data.dpopKey = await JoseKey.fromJWK(data.dpopKey.jwk);
    }
    return data;
  }
}
```

### Token Extraction

The AT Protocol OAuth client stores tokens in its own session format. We need to extract them:

```javascript
// After OAuth callback
const result = await client.callback(params);
const finalDid = result.session.sub;

// Get actual tokens from session store
const sessionData = await env.OAUTH_SESSIONS.get(`session:${finalDid}`, 'json');
const accessToken = sessionData.tokenSet.access_token;
const refreshToken = sessionData.tokenSet.refresh_token;
const dpopKey = sessionData.dpopKey;
```

## Lessons Learned

1. **Read the source code.** The AT Protocol documentation doesn't cover Cloudflare Workers specifics. We had to dig through the library source to understand how Keyset handles public/private keys.

2. **DPoP is mandatory.** Don't waste time trying to disable it. AT Protocol requires it, period.

3. **Test with real devices early.** The DPoP key binding issue only showed up when testing with the actual iOS app.

4. **Cloudflare Workers != Node.js.** Many assumptions in npm packages break in Workers. Always check for:
   - No `process.env` - use Cloudflare bindings
   - No filesystem - use KV or R2
   - No Buffer globally - needs polyfill
   - CryptoKey serialization issues

5. **OAuth codes are single-use.** This seems obvious, but it's easy to accidentally trigger multiple callbacks during development and get confusing "Invalid code" errors.

## Performance Considerations

The entire OAuth flow takes about 13-15 seconds from start to completion. Most of this is:
- User interaction time on Bluesky's OAuth page
- Network latency to Bluesky servers
- Token exchange and validation

The backend processing itself is fast (< 500ms per request).

## What We'd Do Differently

If starting over, we'd probably:
1. Use a traditional server environment (Node.js) for OAuth to avoid Workers-specific issues
2. Implement a more robust session cleanup mechanism
3. Add better error recovery for expired states

## Conclusion

Building OAuth for AT Protocol on Cloudflare Workers is possible, but requires working around several platform limitations. The key insights are:
- Use JoseKey for proper key serialization
- Let the backend generate DPoP keys and share them with clients
- Accept that DPoP is mandatory
- Understand how the Keyset class separates private and public keys

The resulting system works reliably and handles multiple accounts, token refresh, and proper DPoP signatures. Sometimes the best solution isn't the most elegant - it's the one that actually works.

## Code Repository

The complete implementation is available at: [hyperlimit-platform/apps/hyperlimit-oauth](https://github.com/yourusername/hyperlimit-platform)

---

*Built with frustration, debugged with determination, deployed with relief.*