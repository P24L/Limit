# Bookmark System Design Document v2.0

## 1. Executive Summary

Rozšíření stávajícího bookmark systému o pokročilé funkce pro ukládání, organizaci a sdílení bookmarků v rámci Bluesky AT Protocol ekosystému. Implementace bude probíhat ve třech fázích - první fáze pokryje základní funkcionality, druhá fáze přidá pokročilé features, třetí fáze přidá redesign a optimalizace.

## 2. Product Requirements

### 2.1 Core User Flows

#### Quick Save from Timeline
- **Trigger**: Uživatel klikne na bookmark ikonu u postu
- **Action**: Zobrazí se mini overlay nad tab barem s potvrzením "Saved ✓ [Edit icon]"
- **Options**: 
  - Automatické zavření po 3s
  - Kliknutí na Edit ikonu → Bookmark Edit Screen
  - Kliknutí mimo overlay → zavření

#### Direct Bookmark Creation  
- **Entry Point**: Klik na "+" tlačítko v tab baru
- **Dual Action Overlay**:
  - Zobrazí se overlay nad tab barem se dvěma ovály:
    - "Post" → vytvoření nového postu
    - "Bookmark" → vytvoření nového bookmarku
  - Alternativa: Slide-up menu s oběma možnostmi
- **Bookmark Creation Flow**:
  1. Kontrola clipboardu pro URL
  2. Automatické vyplnění URL pokud nalezen
  3. Fetch metadat (title, description, image)
  4. AI summary generování (volitelné)
  5. Uložení

#### Bookmark Sharing
- **Format**: Standardní Bluesky post s:
  - Přímý link z bookmarku
  - Embed s deep linkem do aplikace
  - Default text: "Check out this bookmark I saved: [title]"
- **Deep Link**: Pro budoucí implementaci
  - Aktuálně navigace přes `Destination` enum
  - V budoucnu možná přidat URL scheme handling
- **Fallback**: Pokud uživatel nemá aplikaci → App Store link

### 2.2 Data Model Updates

#### Bookmark Record Enhancement
```typescript
{
  // Existing fields
  url: string
  title: string
  createdAt: datetime
  
  // Updated fields
  updatedAt?: datetime  // NEW - pro tracking editací
  
  // List management
  listUris?: string[]   // Reference na listy
}
```

#### Implementation Note
- AT Proto neumožňuje přímou editaci → delete + create s novým updatedAt
- Zachování createdAt při "editaci"

### 2.3 Navigation Structure

#### New Tab Structure
```
[Home] [Bookmarks] [+] [Search] [Profile]
```

#### Bookmarks Tab Content
- Dva sub-taby: "Saved" | "Lists"
- **Saved**: Seznam všech bookmarků
- **Lists**: Seznam bookmark listů

#### Profile Tab Reorganization
Přesun z "You" tabu:
- Saved Posts
- Notifications
- Účty a nastavení

#### "+" Button Behavior
- Single tap → Overlay se dvěma možnostmi:
  - "Post" oval → nový post
  - "Bookmark" oval → nový bookmark
- Design: Dva kruhy/ovály nad tab barem s ikonami a textem

## 3. Technical Architecture

### 3.1 Component Structure

**Note for Claude Code**: Následující kód je konceptuální. Implementuj podle vzorů v projektu (bez ViewModels, použij @Observable pattern z claude.md).

```swift
// Navigation - využij existující AppRoute.swift strukturu
// Destination enum už obsahuje bookmarkListManagement
// Přidej další případy podle potřeby

// Observable State (ne ViewModel!)
@Observable
class BookmarkEditState {
    var url: String = ""
    var title: String = ""
    var description: String?
    var summary: String?
    var imageUrl: String?
    var selectedLists: [String] = []
    
    func fetchMetadata() async {
        // Použij existující funkce z projektu
    }
    
    func generateAISummary() async {
        // Volej existující AI funkci z projektu
    }
    
    func save() async throws {
        // Použij BookmarkManager z projektu
    }
}

// Services - použij existující z projektu
// BookmarkManager, BookmarkMetadataService, atd.
```

### 3.2 Navigation & Deep Links

#### Current Navigation
```swift
// Použití existující Destination enum
enum Destination: DestinationType {
    // Existing cases...
    case bookmarkDetail(id: String)  // Přidat pro detail bookmarku
    case bookmarkEdit(id: String?)    // Přidat pro editaci
}
```

#### Future Deep Link Implementation
```swift
// Pro budoucí URL scheme handling (Phase 2+)
// Info.plist configuration:
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>limit</string>
        </array>
    </dict>
</array>

// Handling v LimitApp.swift (budoucí implementace):
.onOpenURL { url in
    // Parse limit://bookmark/{id}
    // Navigate using router
}
```

#### Share Post Integration
```swift
// Otevření ComposePostView s předvyplněným bookmarkem
// Uživatel může upravit text před odesláním
router.presentedSheet = .composePost(
    quotedPost: nil, 
    replyTo: nil, 
    bookmark: bookmark
)
```

### 3.3 AT Protocol Integration

#### Create/Update Flow
```swift
// Pseudo-code pro bookmark update
// Claude Code: Použij existující BookmarkManager metody
func updateBookmark(bookmark: BookmarkRecord, changes: BookmarkChanges) async {
    // 1. Delete old record
    await atproto.deleteRecord(uri: bookmark.uri)
    
    // 2. Create new with preserved createdAt
    let updated = bookmark.copy(
        changes: changes,
        updatedAt: Date.now
    )
    await atproto.createRecord(record: updated)
}
```

#### Share Post Creation
```swift
func createSharePost(bookmark: BookmarkRecord) async {
    let defaultText = "Check out this bookmark I saved: \(bookmark.title)"
    
    let embed = AppViewEmbed(
        external: ExternalEmbed(
            uri: bookmark.url,
            title: bookmark.title,
            description: bookmark.description ?? ""
        )
    )
    
    // Deep link jako fallback
    // Claude Code: Implementuj pomocí existující BlueskyClient.createPost
    await blueskyClient.createPost(text: defaultText, embed: embed)
}

### 3.4 UI Components

#### SaveConfirmationOverlay
```swift
struct SaveConfirmationOverlay: View {
    @State private var dismissTimer: Timer?
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
            Text("Saved")
            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}
```

#### PostBookmarkOverlay
```swift
struct PostBookmarkOverlay: View {
    let onPost: () -> Void
    let onBookmark: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: onPost) {
                VStack {
                    Image(systemName: "square.and.pencil")
                    Text("Post")
                }
                .frame(width: 80, height: 80)
                .background(Color.blue)
                .cornerRadius(40)
            }
            
            Button(action: onBookmark) {
                VStack {
                    Image(systemName: "bookmark")
                    Text("Bookmark")
                }
                .frame(width: 80, height: 80)
                .background(Color.orange)
                .cornerRadius(40)
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}
```

#### BookmarkEditSheet
- Unified screen pro create i edit
- Smart clipboard detection
- Metadata auto-fetch s loading states
- List multi-selector
- AI summary toggle (volá existující funkci)

## 4. Implementation Phases

### Phase 1: Core Features (COMPLETED ✅)
- [x] ✅ Tab struktura refactor (Home, Bookmarks, +, Search, Profile)
- [x] ✅ SaveConfirmationOverlay komponenta
- [x] ✅ PostBookmarkOverlay pro "+" button (implementováno jako FAB)
- [x] ✅ BookmarkEditSheet (create/edit unified)
- [x] ✅ Clipboard URL detection
- [x] ✅ Basic metadata extraction (WebImageExtractor)
- [x] ✅ List assignment UI
- [x] ✅ AppRouter integration pro nové routes

### Phase 2: Advanced Features (PARTIALLY COMPLETED)
- [x] ✅ Deep link handling (kód hotový, čeká na Info.plist)
- [x] ✅ Share to Bluesky composer
- [x] ✅ Advanced metadata extraction (WebImageExtractor s OpenGraph)
- [x] ✅ Bookmark search & filtering
- [x] ✅ External bookmark view (pro cizí bookmarky)
- [ ] ⏭️ Bulk operations (select multiple) - SKIP
- [ ] ⏭️ Import/Export bookmarks - SKIP
- [ ] Bookmark duplicates detection
- [ ] App Store fallback pro deep linky

### Phase 3: Profile Tab Redesign (MOSTLY COMPLETED)
- [x] ✅ Přesun Saved Posts z You → Profile
- [x] ✅ Přesun Notifications z You → Profile  
- [x] ✅ Redesign Profile tabu (modernější UI)
- [x] ✅ Account switcher (základní implementace)
- [ ] ⏭️ User stats dashboard (nice-to-have)
- [ ] ⏭️ Activity feed (nice-to-have)
- [ ] ⏭️ Settings reorganizace (nice-to-have)

### Phase 4: Future Enhancements
- [ ] Collaborative lists (sdílené s jinými uživateli)
- [ ] Public lists (discoverable)
- [ ] Bookmark recommendations
- [ ] Tags system
- [ ] Advanced search with filters
- [ ] Bookmark reminders
- [ ] Archive functionality

## 5. Implementation Notes for Claude Code

### Architecture Principles
- **NO ViewModels**: Použij @Observable pattern podle claude.md
- **Existující služby**: Využij BookmarkManager, BlueskyClient, atd.
- **AppRouter**: Všechny navigace přes existující router
- **AI Summary**: Již implementováno, jen zavolej existující funkci
- **Image handling**: Existující funkce automaticky rozhodne URL vs blob

### Enums to Update
```swift
// V AppRoute.swift - Destination enum:
enum Destination: DestinationType {
    // Existing cases...
    case bookmarkDetail(id: String)
    case bookmarkEdit(id: String?)
    // bookmarkListManagement už existuje ✓
}

// V AppRoute.swift - Sheet enum (pokud budeš používat sheets):
enum Sheet: SheetType {
    case none // existující
    // Případně přidat:
    case bookmarkEdit(state: BookmarkEditState)
}

// V AppRoute.swift - AppTab enum:
// Změnit favorites → bookmarks (Phase 1)
enum AppTab: String, TabType, CaseIterable {
    case timeline, bookmarks, post, search, settings  // místo favorites
}
```

### Component Integration Points
- **Tab Bar**: Modifikuj existující TabBarView
- **Bookmarks Tab**: Vytvoř nový BookmarksTabView se sub-taby
- **Profile Tab**: Reorganizuj ProfileView, přesuň items z You
- **"+" Button**: Upravit akci pro zobrazení overlay

### Metadata Extraction Priority
Pro získání description z URL (v tomto pořadí):
1. OpenGraph tags (og:description)
2. Twitter Card tags (twitter:description)  
3. Meta description tag
4. První paragraph textu (fallback)

### Default Share Text Template
```swift
let shareText = "Check out this bookmark I saved: \(bookmark.title)"
// Alternativy:
// "Found this interesting: \(bookmark.title)"
// "\(bookmark.title) - saved to my bookmarks"
```

### Checkpoint System
Po implementaci každé komponenty označit zde:
- ✅ Completed
- 🚧 In Progress
- ❌ Blocked
- ⏭️ Skipped (pro pozdější fáze)

## 6. Key Decisions Summary

### Confirmed Decisions
1. ✅ **Tab Structure**: Home - Bookmarks - + - Search - Profile
2. ✅ **"+" Button**: Overlay se dvěma ovály (Post/Bookmark)
3. ✅ **No ViewModels**: @Observable pattern podle claude.md
4. ✅ **AI Summary**: Existující implementace
5. ✅ **Image Storage**: Existující funkce (auto-rozhoduje)
6. ✅ **Share Text**: "Check out this bookmark I saved: [title]"
7. ✅ **Metadata Priority**: OpenGraph > Twitter > Meta > Text

### Technical Notes
- **updatedAt field**: Již v lexicon struktuře
- **Deep Links**: Nutná registrace v Info.plist + App Store fallback
- **Edit = Delete + Create**: AT Proto omezení
- **Profile Tab**: Bude redesign ve Phase 3

---

*Document Version: 2.2*  
*Last Updated: 2025-08-10*  
*Status: Phase 1 COMPLETED ✅ | Phase 2 MOSTLY COMPLETED | Phase 3 MOSTLY COMPLETED*