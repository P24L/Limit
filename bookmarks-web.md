# Bookmarks Web - Implementační dokument

## 1. Přehled systému

Webová aplikace pro správu Bluesky bookmarks využívající AT Protocol. Uživatelé se přihlásí svým Bluesky účtem a mohou spravovat své bookmarks a bookmark lists. Systém musí zvládnout tisíce bookmarks s výbornou performance.

## 2. Architektura a datové modely

### 2.1 AT Protocol struktura

**BookmarkRecord** (`app.hyper-limit.bookmark`):
- `url` (string, required) - URL záložky
- `title` (string, required) - Název záložky  
- `createdAt` (Date, required) - Datum vytvoření
- `description` (string, optional) - Popis záložky
- `summary` (string, optional) - AI generované shrnutí
- `note` (string, optional) - Osobní poznámka
- `imageUrl` (string, optional) - URL náhledového obrázku
- `tags` (string[], optional) - Seznam tagů
- `listUris` (string[], optional) - URI seznamů obsahujících bookmark
- `pinned` (boolean, optional) - Připnutá záložka
- `archived` (boolean, optional) - Archivovaná záložka
- `reminder` (object, optional) - Připomínka {date, note}
- `sourceUri` (string, optional) - Odkaz na původní Bluesky post
- `updatedAt` (Date, optional) - Poslední aktualizace

**BookmarkListRecord** (`app.hyper-limit.bookmarkList`):
- `name` (string, required) - Název seznamu
- `visibility` (enum, required) - "private" | "public" | "shared"
- `createdAt` (Date, required) - Datum vytvoření
- `description` (string, optional) - Popis seznamu
- `color` (string, optional) - Barva pro UI (#hex)
- `icon` (string, optional) - Ikona seznamu
- `pinned` (boolean, optional) - Připnutý seznam
- `permissions` (object, optional) - Oprávnění pro sdílení
- `updatedAt` (Date, optional) - Poslední aktualizace

### 2.2 URI struktura

Bookmarks mají URI formát: `at://did:plc:xxx/app.hyper-limit.bookmark/rkey`
- `did:plc:xxx` - DID uživatele
- `rkey` - Unikátní klíč záznamu

## 3. Strategie správy dat

### 3.1 Možné přístupy

**A) Online-only (přímé AT Protocol volání)**
- ✅ Vždy aktuální data
- ✅ Žádná lokální synchronizace
- ❌ Pomalé při velkém počtu bookmarks
- ❌ Závislé na síťové rychlosti
- ❌ Nemožnost offline práce

**B) Browser Storage (IndexedDB/LocalStorage)**
- ✅ Rychlá odezva
- ✅ Offline podpora
- ✅ Optimistické UI
- ❌ Omezená kapacita (50-100MB)
- ❌ Složitá synchronizace
- ❌ Per-device isolation

**C) Backend databáze**
- ✅ Neomezená kapacita
- ✅ Pokročilé dotazování
- ✅ Sdílení mezi zařízeními
- ❌ Dodatečná infrastruktura
- ❌ Duplicita dat z PDS
- ❌ Synchronizační složitost

### 3.2 Doporučená hybridní strategie

Kombinace **IndexedDB cache + AT Protocol sync**:

1. **První načtení**: Stáhnout všechny bookmarks z AT Protocol
2. **Cache v IndexedDB**: Uložit lokálně s per-user isolation
3. **Optimistické UI**: Okamžité lokální změny
4. **Background sync**: Synchronizace s AT Protocol
5. **Pagination**: Načítat po 50 položkách
6. **LRU eviction**: Max 500 bookmarks v paměti

## 4. Hlavní funkcionality

### 4.1 Autentizace
- OAuth flow s Bluesky účtem
- Ukládání session tokenu do sessionStorage
- Auto-refresh tokenů před expirací
- Podpora více účtů (switch mezi účty)

### 4.2 Bookmarks - CRUD operace

**Vytvoření bookmarku**:
1. Uživatel vloží URL (nebo použije bookmarklet)
2. Automatické načtení metadata (title, description, image)
3. Možnost přidat tagy, poznámku, přiřadit do listů
4. Optimistické UI - okamžité zobrazení
5. Background sync s AT Protocol
6. Volitelné AI zpracování pro summary

**Editace bookmarku**:
- Inline editace všech polí
- Bulk editace (přidat/odebrat tagy, přesun do listů)
- Drag & drop mezi listy
- Quick actions (archive, pin, set reminder)

**Mazání bookmarku**:
- Soft delete (archive) vs hard delete
- Bulk delete s potvrzením
- Undo funkce (30 sekund)

### 4.3 Bookmark Lists

**Správa seznamů**:
- Vytvoření/editace/mazání listů
- Nastavení visibility (private/public/shared)
- Přiřazení barvy a ikony
- Pinning důležitých listů
- Řazení (alphabetical, by date, manual)

**Operace se seznamy**:
- Přidání/odebrání bookmarks
- Bulk operations
- Export/import seznamu
- Sdílení seznamu (generování shareable linku)
- Collaborative lists (s permissions)

### 4.4 Vyhledávání a filtrování

**Full-text search**:
- Prohledávání: title, description, URL, note, tags
- Search operators (AND, OR, NOT, "exact phrase")
- Search history a saved searches

**Filtrování**:
- Multi-select tag chips (vizuální filtry)
- Časové filtry (today, week, month, year)
- Status filtry (archived, pinned, has-reminder)
- List membership filtry
- Kombinace filtrů

**Řazení**:
- By date (created/updated)
- Alphabetical
- By domain
- By frequency of access
- Custom order (drag & drop)

### 4.5 Tagy

**Tag management**:
- Auto-complete při psaní
- Tag cloud vizualizace
- Rename/merge tagů
- Tag hierarchy (nested tags)
- Suggested tags based on content

## 5. Performance optimalizace

### 5.1 Virtuální scrolling
- Renderovat pouze viditelné položky
- Buffer zóna pro smooth scrolling
- Preserve scroll position při navigaci
- Intersection Observer API

### 5.2 Pagination strategie
- Initial load: 50 položek
- Infinite scroll s lazy loading
- "Load more" button jako fallback
- Cursor-based pagination (ne offset)

### 5.3 Caching layers
```
Memory (JS objects) → IndexedDB → AT Protocol
     ↓                    ↓            ↓
   <200 items      <5000 items    All items
   Instant          <50ms         Network
```

### 5.4 Optimalizace síťových volání
- Batch operace (až 25 položek najednou)
- Request deduplication
- Exponential backoff při chybách
- Background sync queue

### 5.5 Service Worker
- Offline podpora základních operací
- Background sync při obnovení připojení
- Cache static assets
- Push notifications pro reminders

## 6. Vizuální styl a Design System

### 6.1 Barevná paleta

**Primární barvy**:
- **Mint Accent** (`#2EAE7A` / rgb(46, 174, 122)) - Hlavní akční barva, používaná pro CTA, odkazy, aktivní stavy
- **Mint Inactive** (`#A6D1B7` / rgb(166, 209, 183)) - Světlejší varianta pro neaktivní/disabled stavy

**Pozadí (light/dark mode)**:
- **Warm Background**: 
  - Light: `#F5F5F5` (rgb(245, 245, 245)) - Teplé šedé pozadí
  - Dark: `#1A1A1A` (rgb(26, 26, 26)) - Tmavé teplé pozadí
- **Card Background**:
  - Light: `#FFFFFF` (pure white) - Čisté bílé karty
  - Dark: `#262626` (rgb(38, 38, 38)) - Tmavě šedé karty
- **Subtle Gray** (borders):
  - Light: `#F0F0F0` (rgb(240, 240, 240))
  - Dark: `#404040` (rgb(64, 64, 64))

**Text barvy**:
- **Primary**: System default (černá/bílá podle mode)
- **Secondary**: `#737373` light / `#BFBFBF` dark
- **Tertiary**: `#A6A6A6` (stejná v obou modes)

**Akcent barvy**:
- **Blue** (AI features): `#007AFF` s opacity 0.05 pro pozadí
- **Green** (success): `#34C759`
- **Red** (destructive): `#FF3B30`

### 6.2 Typografie

**Font hierarchy**:
- **Headline**: 17px, semibold (600) - Názvy bookmarks
- **Body**: 15px, regular (400) - Běžný text
- **Caption**: 13px, regular - Meta informace (host, čas)
- **Caption2**: 12px, regular - Tagy, drobné popisky
- **Footnote**: 14px, regular - Popisky, sekundární text

**Line heights**:
- Titles: 1.3
- Body text: 1.5
- Descriptions: 1.4

### 6.3 Komponenty - Bookmark Card

**Struktura karty**:
```
┌──────────────────────────────────────┐
│ ┌────┐  Title (headline, semibold)   │
│ │IMG │  host.com • 2 hours ago       │
│ │88px│  Description text...           │
│ └────┘                                │
│                                       │
│ ┌─────────────────────────────────┐  │
│ │ ✨ AI Summary (blue bg 0.05)    │  │
│ └─────────────────────────────────┘  │
│                                       │
│ [#tag1] [#tag2] [#tag3]              │
│                                       │
│ [🌐 Open] [↗️ Share] [📦] [✏️]        │
└──────────────────────────────────────┘
```

**Card styling**:
- **Corner radius**: 14px pro karty, 12px pro thumbnails, 10px pro chips
- **Padding**: 12px horizontal, 10px vertical
- **Thumbnail**: 88x88px, aspect ratio 1:1, cover fit
- **Shadow**: `box-shadow: 0 0.5px 1.5px rgba(0,0,0,0.08)`
- **Border**: Volitelný subtle border 0.5px v dark mode

**Interactive elements**:
- **Buttons**: Capsule shape (border-radius: 999px)
  - Padding: 12px horizontal, 8px vertical
  - Background: `rgba(gray, 0.1)`
  - Hover: Scale 1.02, background opacity 0.15
- **Tag chips**: 
  - Padding: 10px horizontal, 5px vertical
  - Background: `rgba(gray, 0.12)`
  - Border: 0.5px `rgba(gray, 0.16)`
- **AI Summary chip**:
  - Blue tint background (`rgba(blue, 0.05)`)
  - Sparkles icon vlevo
  - Chevron vpravo pro expandování

### 6.4 Layout a spacing

**Grid system**:
- Mobile: 1 sloupec, full width cards
- Tablet: 2 sloupce, gap 16px
- Desktop: 3 sloupce, max-width 1280px, gap 20px

**Spacing scale**:
- 4px, 6px, 8px, 10px, 12px, 16px, 20px, 24px, 32px

**Container padding**:
- Mobile: 16px
- Tablet: 20px
- Desktop: 24px

### 6.5 Animace a transitions

**Timing functions**:
- Default: `ease-in-out 0.2s`
- Quick feedback: `ease-out 0.12s`
- Smooth: `ease-in-out 0.3s`

**Hover efekty**:
- Cards: Subtle scale (0.99) + shadow elevation
- Buttons: Opacity change (0.8) nebo scale (1.02)
- Links: Mint color s underline

**Loading states**:
- Skeleton screens pro karty
- Pulsing animation pro placeholders
- Progress indikátor pro AI summary

### 6.6 Feedback komponenty

**Save Confirmation Overlay**:
- Pill shape (border-radius: 25px)
- Slide up from bottom animation
- Auto-dismiss po 3 sekundách
- Shadow: `0 8px 15px rgba(0,0,0,0.2)`
- Obsahuje: checkmark, text "Saved", edit button

**Toast notifications**:
- Position: Bottom center, 50px nad spodní hranou
- Max-width: 400px
- Same styling jako Save Confirmation

### 6.7 Dark mode specifika

- Invertované barvy pozadí
- Zvýšený kontrast pro text (světlejší secondary/tertiary)
- Subtle borders pro lepší separaci karet
- Tlumenější shadows
- Zachování mint accent barvy

### 6.8 Accessibility

- Minimum kontrast 4.5:1 pro běžný text
- Minimum kontrast 3:1 pro velký text
- Focus indicators: 2px mint outline s offset 2px
- Touch targets: minimum 44x44px
- Podpor pro prefers-reduced-motion

## 7. UI/UX komponenty

### 7.1 Hlavní views

**Dashboard**:
- Quick stats (total, recent, archived)
- Recent bookmarks
- Pinned lists
- Quick add widget

**Bookmarks List View**:
- Card layout vs compact list (toggle)
- Thumbnail previews
- Tag chips
- Quick actions on hover
- Bulk selection mode

**Bookmark Detail View**:
- Full preview
- Edit in place
- Related bookmarks
- Activity history
- Share options

**Lists Management**:
- Grid/list view toggle
- Drag & drop reordering
- Visual indicators (color, icon, count)
- Quick filters

### 6.2 Interakční vzory

**Optimistické UI**:
- Okamžitá vizuální odezva
- Loading states pro sync
- Error recovery s retry
- Undo/redo support

**Keyboard shortcuts**:
- `n` - New bookmark
- `/` - Focus search
- `j/k` - Navigate list
- `e` - Edit selected
- `del` - Delete selected

**Drag & Drop**:
- Bookmarks mezi listy
- Reordering v rámci listu
- Multi-select drag
- Visual drop zones

### 6.3 Responsive design
- Mobile-first approach
- Breakpoints: 640px, 768px, 1024px, 1280px
- Touch gestures (swipe to delete/archive)
- Adaptive layouts (cards → list na mobile)

## 7. Technické implementační detaily

### 7.1 AT Protocol API volání

**Autentizace**:
```
POST /xrpc/com.atproto.server.createSession
```

**Načtení bookmarks**:
```
GET /xrpc/com.atproto.repo.listRecords
  ?repo={did}
  &collection=app.hyper-limit.bookmark
  &limit=50
  &cursor={cursor}
```

**Vytvoření bookmarku**:
```
POST /xrpc/com.atproto.repo.createRecord
  collection: app.hyper-limit.bookmark
  record: {BookmarkRecord}
```

**Update bookmarku**:
```
POST /xrpc/com.atproto.repo.putRecord
  repo: {did}
  collection: app.hyper-limit.bookmark
  rkey: {rkey}
  record: {BookmarkRecord}
```

### 7.2 State management

**Doporučené řešení**: Zustand nebo Valtio
- Jednoduchý API
- TypeScript support
- Optimistické updates
- Middleware pro persistence

**State struktura**:
```
{
  auth: { session, did, handle },
  bookmarks: { 
    items: Map<uri, Bookmark>,
    loading: boolean,
    cursor: string,
    hasMore: boolean
  },
  lists: {
    items: Map<uri, List>,
    loading: boolean
  },
  ui: {
    selectedBookmarks: Set<uri>,
    activeFilters: FilterState,
    searchQuery: string,
    view: 'cards' | 'list'
  },
  sync: {
    queue: SyncOperation[],
    status: 'idle' | 'syncing' | 'error'
  }
}
```

### 7.3 Error handling

**Síťové chyby**:
- Automatický retry s exponential backoff
- Offline queue pro operace
- User notification s možností manual retry

**Validační chyby**:
- Client-side validace před odesláním
- Inline error messages
- Graceful degradation

**Rate limiting**:
- Request throttling
- Queue management
- User feedback o limitech

### 7.4 Bezpečnost

- Žádné ukládání hesel (pouze app passwords)
- HTTPS only
- CSP headers
- XSS prevence (sanitizace vstupů)
- CORS správně nastavené

## 8. Rozšíření a integrace

### 8.1 Browser extension
- Bookmarklet pro rychlé přidání
- Context menu integrace
- Keyboard shortcut
- Auto-import z browser bookmarks

### 8.2 Import/Export
- JSON export celé databáze
- CSV export pro spreadsheets
- Pocket/Instapaper import
- Browser bookmarks import

### 8.3 AI Summary Service (Firebase Functions)

Webová verze může využívat stejné Firebase Functions jako iOS aplikace pro generování AI summary. Tyto funkce jsou již nasazené a připravené k použití.

**Dostupné Firebase Functions**:
1. **summarizeUrl** - Generuje summary pro danou URL
   - Input: `{ url: string }`
   - Output: `{ url, title, summary, excerpt, wordCount, truncated }`
   - Automaticky extrahuje obsah stránky
   - Generuje shrnutí pomocí OpenAI
   - Detekuje paywally a nedostupný obsah

2. **generateText** - Obecná funkce pro generování textu (pro budoucí rozšíření)

**Implementační detaily**:

**Firebase SDK inicializace**:
- Použít Firebase JS SDK
- Region: `us-central1`
- Projekt: stejný jako iOS app
- Autentizace: Firebase Auth nebo anonymous auth

**Volání funkce summarizeUrl**:
```
POST https://{region}-{projectId}.cloudfunctions.net/summarizeUrl
Body: { url: "https://example.com/article" }
```

**Error handling**:
- **Retryable errors**: Network issues, OpenAI timeouts
  - Implementovat exponential backoff
  - Max 3 pokusy
- **Permanent errors**: Paywall, invalid URL, content extraction failed
  - Nezkoušet znovu
  - Uložit bookmark bez summary
  - Možnost manuálního přidání poznámky

**UI flow pro AI summary**:
1. Uživatel přidá URL
2. Bookmark se uloží okamžitě (optimistické UI)
3. Na pozadí se zavolá `summarizeUrl`
4. Po dokončení se bookmark aktualizuje se summary
5. Loading indikátor během zpracování
6. Fallback na manuální popis při chybě

**Optimalizace**:
- Cache summary v IndexedDB
- Debounce při editaci URL
- Queue pro batch processing
- Rate limiting: max 100 summary/den/user

**Výhody sdílené infrastruktury**:
- Jednotné AI zpracování pro iOS i web
- Sdílené náklady na OpenAI API
- Konzistentní kvalita summary
- Centralizovaná správa a monitoring

## 9. Metriky a monitoring

Sledovat:
- Počet bookmarks per user
- Sync latency
- Error rates
- Search performance
- User engagement (add/edit/delete rates)

## 10. Deployment considerations

- CDN pro static assets
- Edge functions pro API calls
- IndexedDB size monitoring
- Backup strategie pro uživatelská data
- Progressive Web App manifest

## Závěr

Tato implementace poskytuje robustní základ pro webovou verzi bookmark systému s důrazem na performance, UX a spolehlivost. Klíčové je správné vybalancování mezi lokální rychlostí a synchronizací s AT Protocol, spolu s promyšlenou strategií pro správu velkého množství dat.