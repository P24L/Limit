# Souhrn reorganizace projektu Limit

## Provedené změny

Projekt byl reorganizován podle moderních iOS best practices do následující struktury:

### 1. App/
- **LimitApp.swift** - hlavní vstupní bod aplikace
- **AppRootView.swift** - kořenový view s navigací
- **Configuration/** - konfigurace projektu (Local.xcconfig, buildServer.json, GoogleService-Info.plist)

### 2. Core/
Business logika a základní komponenty:
- **Models/** - datové modely organizované podle domén (Timeline, Bookmarks, User, Favorites)
- **Services/** - služby (Network/BlueskyClient, AI, Bookmarks, atd.)
- **Navigation/** - AppRoute.swift pro navigaci
- **ATProto/** - AT Protocol specifické soubory

### 3. Features/
Funkcionalita organizovaná podle domén:
- **Timeline/** - časová osa (Views, ViewModels, Components)
- **Posts/** - zobrazení příspěvků (Views, Components, Sheets)
- **Compose/** - vytváření příspěvků
- **Profile/** - uživatelské profily
- **Search/** - vyhledávání
- **Bookmarks/** - záložky a oblíbené
- **Lists/** - seznamy
- **Feeds/** - feedů
- **Settings/** - nastavení
- **Notifications/** - notifikace
- **Auth/** - přihlašování
- **Safari/** - Safari tab

### 4. Shared/
Sdílené komponenty napříč aplikací:
- **Components/** - obecné UI komponenty
- **Extensions/** - Swift extensions
- **Utilities/** - pomocné třídy a funkce
- **DesignSystem/** - barvy a gradienty

### 5. Resources/
- **Assets.xcassets** - obrázky a ikony

### 6. Preview Content/
- **SampleData.swift** - testovací data pro SwiftUI previews

### 7. Documentation/
- **CLAUDE.md** - dokumentace pro Claude AI
- **Architecture/** - architektonická dokumentace

## Výhody nové struktury

1. **Lepší přehlednost** - soubory jsou logicky organizované podle funkcionality
2. **Snadnější navigace** - jasná hierarchie adresářů
3. **Škálovatelnost** - snadné přidávání nových features
4. **Separace zájmů** - oddělení business logiky od UI
5. **Dodržování standardů** - odpovídá iOS development best practices

## Další kroky

1. **Aktualizace importů** - je potřeba aktualizovat cesty k souborům ve všech Swift souborech
2. **Xcode projekt** - aktualizovat reference v Xcode projektu
3. **Build a test** - ověřit, že aplikace správně builduje a funguje

## Poznámky

- Všechny soubory byly pouze přesunuty, žádné nebyly smazány
- Struktura respektuje doporučení z CLAUDE.md o organizaci podle funkcionality
- Dokumentace a pomocné soubory byly odděleny od zdrojového kódu