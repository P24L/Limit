# OAuth + DPoP Implementation Specification for ATProtoKit

## 1. Executive Summary

### Cíl projektu
Implementovat OAuth 2.0 s DPoP (Demonstrating Proof of Possession) autentizaci pro iOS aplikaci používající ATProtoKit knihovnu pro komunikaci s Bluesky/AT Protocol. Řešení musí podporovat multi-account funkcionalitu s existujícím AccountManager systémem.

### Proč to děláme
- **Bezpečnost**: OAuth s DPoP je bezpečnější než app passwords (tokeny jsou vázané na konkrétní klíč)
- **User Experience**: Uživatelé se přihlašují přes oficiální Bluesky rozhraní
- **Budoucnost**: AT Protocol směřuje k OAuth jako primární autentizační metodě
- **Compliance**: Oficiální AT Protocol OAuth specifikace vyžaduje DPoP pro všechny typy klientů

## 2. Technické požadavky

### Povinné komponenty (dle AT Protocol spec)
- ✅ **PKCE** (Proof Key for Code Exchange) - RFC 7636
- ✅ **PAR** (Pushed Authorization Requests) - RFC 9126  
- ✅ **DPoP** (Demonstrating Proof of Possession) - RFC 9449
- ✅ **Client Metadata** - hostované na veřejném webu

### OAuth flow pro mobilní aplikace
- OAuth 2 Client Type: **"Public"** (bez client_secret)
- Grant Types: `authorization_code`, `refresh_token`
- DPoP: **POVINNÉ** pro všechny requesty
- Cryptographic algorithm: **ES256** (NIST P-256)

## 3. Architektura řešení

### 3.1 High-level komponenty

```
┌─────────────────────────────────────┐
│         AccountManager              │
│  - Spravuje všechny účty            │
│  - Mapuje DID ↔ OAuth sessions      │
│  - Mapuje DID ↔ ATProtoKit instance │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│    OAuthSessionManager              │
│  - OAuth flow (login/refresh)       │
│  - DPoP keypair management          │
│  - Token storage (Keychain)         │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│    OAuthSessionConfiguration        │
│  - Implementuje SessionConfiguration│
│  - Nahrazuje password auth          │
│  - Poskytuje OAuth tokeny           │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│      DPoPRequestExecutor            │
│  - Implementuje ATRequestExecutor   │
│  - Přidává DPoP proof ke každému    │
│    requestu                         │
│  - Spravuje DPoP nonce per server   │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│   ATProtoKit (instance per účet)    │
│  - Používá custom executor          │
│  - Standardní API volání            │
│  - Neví o OAuth/DPoP implementaci   │
└─────────────────────────────────────┘
```

### 3.2 Datový model

```swift
// OAuth Session pro každý účet
struct OAuthSession {
    let did: String
    let handle: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scope: String
    let dpopKeyId: String  // Reference na DPoP keypair v Keychain
}

// DPoP context pro každý účet
struct DPoPContext {
    let keypair: SecKey  // ES256 keypair
    let publicJWK: JWK   // Public key jako JWK
    var nonces: [String: String]  // Server URL -> nonce
}
```

### 3.3 Multi-account strategie
- **Separátní ATProtoKit instance** pro každý účet
- **Sdílený DPoPRequestExecutor** který určuje účet podle ATProtoKit instance
- **AccountManager** jako centrální bod pro management

## 4. Implementační kroky

### Phase 1: OAuth základy
1. **Client Metadata hosting**
   - Vytvořit a hostovat `client-metadata.json`
   - URL bude `client_id`
   
2. **OAuth flow implementation**
   - Authorization request s PKCE
   - PAR (Pushed Authorization Request)
   - Token exchange
   - Refresh token flow

3. **Token management**
   - Keychain storage
   - Automatic refresh při expiraci
   - Concurrent refresh prevention

### Phase 2: DPoP implementace
1. **DPoP keypair management**
   - Generování ES256 keypair pro každou OAuth session
   - Secure storage v Keychain (non-exportable)
   
2. **DPoP proof generation**
   - JWT vytvoření pro každý HTTP request
   - Správné header a payload fields
   - Podpis privátním klíčem

3. **DPoP nonce handling**
   - Storage per server (PDS vs AppView)
   - Retry logic při `use_dpop_nonce` error

### Phase 3: ATProtoKit integrace
1. **OAuthSessionConfiguration**
   - Implementovat `SessionConfiguration` protocol
   - Override `authenticate()` pro OAuth
   - Override `refreshSession()` pro OAuth refresh
   
2. **DPoPRequestExecutor**
   - Implementovat `ATRequestExecutor` protocol
   - Interceptovat všechny requesty
   - Přidávat DPoP hlavičky

3. **AccountManager integrace**
   - Mapování účtů na OAuth sessions
   - Koordinace mezi komponenty

### Phase 4: Multi-account podpora
1. **Instance management**
   - ATProtoKit instance per účet
   - Lifecycle management
   
2. **Request routing**
   - Určení účtu z request kontextu
   - Správné OAuth session použití

## 5. Technické detaily

### 5.1 DPoP Proof struktura
```
DPoP JWT Header:
{
  "typ": "dpop+jwt",
  "alg": "ES256",
  "jwk": { /* public key */ }
}

DPoP JWT Payload:
{
  "jti": "unique-id",
  "htm": "POST",
  "htu": "https://bsky.social/xrpc/...",
  "iat": 1234567890,
  "ath": "hash-of-access-token", // jen pro resource requests
  "nonce": "server-provided-nonce"
}
```

### 5.2 Request flow
1. ATProtoKit volá API metodu
2. APIClientService vytvoří URLRequest
3. DPoPRequestExecutor zachytí request
4. Executor určí účet (z instance kontextu)
5. Získá OAuth session z AccountManager
6. Vygeneruje DPoP proof
7. Přidá hlavičky:
   - `Authorization: DPoP <access_token>`
   - `DPoP: <dpop_proof_jwt>`
8. Odešle request
9. Zpracuje response (uloží nonce, handle 401, atd.)

### 5.3 Určení účtu z requestu
- **Primární**: ATProtoKit instance ID → Account mapping
- **Fallback**: Aktivní účet v AccountManager
- **URL parsing**: Extract DID z repo parametru (kde je to možné)

## 6. Závislosti

### Požadované knihovny
- **JWT knihovna**: JWTKit - ✅ UŽ PŘIDÁNO, použít tuto
- **Crypto**: CryptoKit - vestavěný Apple framework
  - Import: `import CryptoKit` (nebo možná `import Crypto` - Claude Code ať vyzkouší oba)
  - Dostupný od iOS 13+
  - Pro ES256 použít `P256.Signing`
- **Keychain**: KeychainSwift - ✅ UŽ MÁME
- **ATProtoKit**: Stávající verze

### Client metadata hosting
- GitHub Pages / Netlify / Vercel
- Nebo vlastní web server
- HTTPS povinné, CORS headers

## 7. Bezpečnostní požadavky

1. **DPoP keypairs**
   - Nikdy neexportovat
   - Generovat per session
   - Ukládat v Secure Enclave kde možné

2. **OAuth tokens**
   - Keychain storage only
   - Nikdy v UserDefaults
   - Encrypt at rest

3. **Refresh handling**
   - Mutex/lock pro concurrent refresh
   - Immediate revoke při chybě

## 8. Testování

### Unit testy
- DPoP proof generation
- Token refresh logic
- Multi-account routing

### Integration testy
- OAuth flow end-to-end
- DPoP nonce handling
- Error recovery

### Manual testy
- Multi-account switching
- Token expiration
- Network error handling

## 9. Známé výzvy

### SessionConfiguration vs OAuth
- `authenticate(with: handle, password:)` → OAuth flow
- `refreshSession()` → OAuth refresh, ne AT Protocol refresh
- `getSession()` → musí vrátit OAuth-based session

### Řešení
- Vytvořit `OAuthSessionConfiguration` která přepíše tyto metody
- Použít OAuth tokeny místo AT Protocol session tokenů
- Mapovat OAuth response na `UserSession` strukturu

## 10. Migrace

### Pro existující uživatele
1. Zachovat password-based auth jako fallback
2. Postupná migrace na OAuth
3. Možnost volby auth metody

### Data migration
- Stávající sessions zůstávají
- Nové sessions používají OAuth
- AccountManager rozlišuje typy sessions

## 11. Success Criteria

- ✅ OAuth login funguje pro single account
- ✅ DPoP je přidáváno ke všem authenticated requestům  
- ✅ Token refresh funguje automaticky
- ✅ Multi-account switching zachovává sessions
- ✅ Žádné breaking changes pro existující funkcionalitu
- ✅ Performance není významně degradován

## 12. Další kroky

1. Implementovat Phase 1 (OAuth základy)
2. Otestovat s Bluesky sandbox
3. Přidat DPoP podporu
4. Integrovat s ATProtoKit
5. Rozšířit na multi-account
6. Production deployment