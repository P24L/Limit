# Pending Tasks - Bookmark Implementation

## Critical TODO Before Main Merge

### ⚠️ URL Scheme Registration
**IMPORTANT**: URL scheme pro deep linky není správně registrován v Info.plist.

#### Co je potřeba udělat:
1. Ručně přidat do Info.plist v Xcode:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>P24L.Limit</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>limit</string>
        </array>
    </dict>
</array>
```

2. Nebo alternativně upravit projekt settings v Xcode:
   - Target Settings → Info → URL Types
   - Přidat nový URL Type
   - URL Schemes: `limit`
   - Identifier: `P24L.Limit`

#### Testování deep linků:
- Deep link formát: `limit://bookmark/{did}/{collection}/{rkey}`
- Testovat přes Poznámky app nebo iMessage (ne přímo v Safari)
- Příklad: `limit://bookmark/did:plc:xyz/app.hyper-limit.bookmark/abc123`

---

## Completed Features ✅

### Phase 1 - Core Features (COMPLETED)
- ✅ Tab struktura refactor (Home, Bookmarks, +, Search, Profile)
- ✅ SaveConfirmationOverlay komponenta
- ✅ PostBookmarkOverlay pro "+" button (implementováno jako FAB)
- ✅ BookmarkEditSheet (unified create/edit screen)
- ✅ Clipboard URL detection (automatická detekce při vytvoření)
- ✅ Basic metadata extraction (WebImageExtractor)
- ✅ List assignment UI (multi-select pro přiřazení do listů)
- ✅ AppRouter integration pro nové routes

### Phase 2 - Advanced Features (PARTIALLY COMPLETED)
- ✅ Deep link handling (kód hotový, čeká na Info.plist)
- ✅ Share to Bluesky composer (bookmark → ComposePostView)
- ✅ Advanced metadata extraction (WebImageExtractor s OpenGraph podporou)
- ✅ Bookmark search & filtering
- ✅ ExternalBookmarkView pro cizí bookmarky
- ✅ Privacy-aware bookmark sharing
- ✅ Copy deep link functionality
- ✅ System share sheet integration

### ✅ Bug Fixes
- Opraveno: External link mizí při sdílení bookmarku
- Opraveno: Index out of range při generování deep linků
- Opraveno: Správné parsování AT Protocol URI

---

## Remaining Tasks for Full Implementation

### Phase 2 - Zbývající úkoly
- [ ] **Bookmark Duplicates Detection**
  - Kontrola při vytváření nového bookmarku
  - Upozornění uživatele na existující bookmark
  - Možnost merge nebo skip

- [ ] **App Store Fallback pro Deep Links**
  - Když uživatel nemá aplikaci → redirect na App Store
  - Implementace fallback URL

### Phase 2 - Odložené úkoly (SKIP pro teď)
- ⏭️ **Bulk Operations** - Nízká priorita
- ⏭️ **Import/Export** - Nízká priorita

### Phase 3 - Profile Tab Redesign (MOSTLY COMPLETED)
- [x] ✅ Přesun Saved Posts z You → Profile
- [x] ✅ Přesun Notifications z You → Profile
- [x] ✅ Redesign Profile tabu (modernější UI)
- [x] ✅ Account switcher (základní implementace)

### Phase 3 - Nice-to-have vylepšení (OPTIONAL)
- [ ] Account switcher vylepšení (rychlejší přepínání, avatar preview)
- [ ] User stats dashboard (follower/following grafy, engagement metriky)
- [ ] Activity feed (kdo vás sleduje, lajky, reposty)
- [ ] Settings reorganizace (lepší kategorizace)

### Phase 4 - Future Enhancements
- [ ] Collaborative lists (sdílené s jinými uživateli)
- [ ] Public lists (discoverable)
- [ ] Bookmark recommendations
- [ ] Tags system s autocomplete
- [ ] Advanced search with filters
- [ ] Bookmark reminders s notifikacemi
- [ ] Archive functionality

---

## Next Implementation Priority

### Co zbývá z Phase 2:
1. **Bookmark Duplicates Detection** - Zabránit duplicitním bookmarkům
2. **App Store Fallback** - Pro uživatele bez aplikace

### Phase 3 - Profile Tab Redesign:
Kompletní reorganizace Profile tabu s přesunem funkcí z "You" tabu

### Phase 4 - Future Enhancements:
Pokročilé funkce jako collaborative lists, tags system, reminders atd.

---

*Last Updated: 2025-08-10*
*Status: Phase 1 & 2 partially complete, ready for Phase 1 completion*