# Universal Links Implementation with Claude Code

## Overview
Implementujeme Universal Links pro `hyper-limit.app` domain přímo v existujícím Limit projektu pomocí GitHub Pages.

## Phase 1: GitHub Pages Setup

### 1.1 Zjistit current setup
- Zkontroluj Settings → Pages v GitHub repo
- Identifikuj source folder (`/docs` nebo `/` root)
- Pokud `/docs` neexistuje, vytvoř ji

### 1.2 Vytvořit strukturu souborů
Ve složce pro GitHub Pages (pravděpodobně `/docs`):
```
/docs/
├── .well-known/
│   └── apple-app-site-association
├── CNAME
├── index.html
├── bookmark/
│   └── index.html
└── [existing files like PRIVACY_POLICY.html]
```

### 1.3 CNAME soubor
Obsahuje pouze: `hyper-limit.app`

### 1.4 AASA soubor (`.well-known/apple-app-site-association`)
- JSON bez přípony `.json`
- Obsahuje oba bundle IDs:
  - `TEAM_ID.P24L.Limit` (production)
  - `TEAM_ID.P24L.Limit.dev` (development)
- Paths: `/bookmark/*` a `/b/*` (zkrácená verze)
- Team ID najdeš v Xcode → Signing & Capabilities

### 1.5 index.html
- Landing page pro hyper-limit.app
- Modern gradient design
- Link na App Store
- Link na Privacy Policy

### 1.6 bookmark/index.html
- Handler pro bookmark deep links
- JavaScript redirect logic:
  1. Parse URL path
  2. Try custom scheme `limit://bookmark/...`
  3. Fallback to App Store after 2s

## Phase 2: Xcode Configuration

### 2.1 Associated Domains Capability
Pro OBA targets (main + dev):
1. Signing & Capabilities → + Capability
2. Add "Associated Domains"
3. Add: `applinks:hyper-limit.app`

### 2.2 Update Destination enum
V `AppRoute.swift`:
```swift
enum Destination: DestinationType {
    // Add new cases:
    case bookmarkDetail(did: String, collection: String, rkey: String)
    case bookmarkEdit(id: String?)
}
```

### 2.3 Handle Universal Links
V `LimitApp.swift`:
- Add `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)`
- Parse URL: `https://hyper-limit.app/bookmark/{did}/{collection}/{rkey}`
- Navigate using router to bookmarkDetail

### 2.4 Handle Custom Scheme (fallback)
- Existing `.onOpenURL` modifier
- Handle `limit://bookmark/{did}/{collection}/{rkey}`
- Same navigation logic

## Phase 3: DNS Configuration

### 3.1 Namecheap setup
User needs to add in Namecheap dashboard:
- 4x A records pointing to GitHub Pages IPs:
  - 185.199.108.153
  - 185.199.109.153
  - 185.199.110.153
  - 185.199.111.153

### 3.2 Wait for propagation
- DNS: 5 minutes - 24 hours
- SSL certificate: 1-24 hours (GitHub automatic)

## Phase 4: Generate Share Links

### 4.1 Create helper function
```swift
func generateShareLink(for bookmark: BookmarkRecord) -> URL {
    // Parse AT URI: at://did:plc:xyz/app.hyper-limit.bookmark/abc123
    // Return: https://hyper-limit.app/bookmark/did:plc:xyz/app.hyper-limit.bookmark/abc123
}
```

### 4.2 Update share functionality
- When sharing bookmark to Bluesky
- Use universal link instead of custom scheme
- Include in post text or external embed

## Phase 5: Testing

### 5.1 Requirements
- Physical iPhone (not simulator!)
- Dev build with Associated Domains
- Wait for SSL certificate

### 5.2 Test flow
1. Build to device
2. Open Safari
3. Navigate to: `https://hyper-limit.app/bookmark/test/test/test`
4. Should prompt to open in app

### 5.3 Debugging
- Check AASA: `https://hyper-limit.app/.well-known/apple-app-site-association`
- Console.app → filter by "swcd"
- If not working: delete app, restart phone, reinstall

## Implementation Order

1. **First**: Create GitHub Pages files
2. **Commit & Push**: Let GitHub Pages deploy
3. **Meanwhile**: User sets up DNS
4. **Then**: Xcode configuration
5. **Finally**: Test on device after SSL is ready

## Notes for Claude Code

- Team ID není secret - je veřejně viditelný
- Use existing navigation patterns (AppRouter)
- Follow project's @Observable pattern (no ViewModels)
- Test on real device, not simulator
- Both dev and prod use same domain
- AASA file supports both bundle IDs

## Success Criteria

✅ GitHub Pages serves AASA file
✅ SSL certificate active
✅ Associated Domains in both targets
✅ Links open app when installed
✅ Links fallback to App Store when not installed
✅ Both dev and prod versions work