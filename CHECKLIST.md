# GitHub Release Checklist - Limit iOS App

## 🚨 MUST-HAVE (Kritické kroky)

### 1. **Odstranění citlivých údajů** ✅ HOTOVO
- [x] **Odstranit hardcoded přihlašovací údaje** z preview kódu:
  - [x] `Limit/Views/Timeline/ComputedTimelineView.swift` (řádky 132-133)
  - [x] `Limit/Views/ActorUI/ActorView.swift` (řádky 527-528) 
  - [x] `Limit/Utils/Views/ProgressPostsRedacted.swift` (řádky 27-28)
  - [x] `Limit/Network/BlueskyClient.swift` (řádky 55-56 - už zakomentované)

### 2. **Bezpečnostní úpravy** ✅ HOTOVO
- [x] **Aktualizovat .gitignore** - přidáno:
  ```
  # User credentials
  *.keychain
  *.p12
  *.mobileprovision
  
  # Build artifacts
  *.ipa
  *.dSYM.zip
  
  # Xcode user data
  *.xcuserdata/
  *.xcuserstate
  ```

### 3. **Vytvořit README.md** ✅ HOTOVO
- [x] Kompletní README s popisem funkcí
- [x] Místa pro screenshoty označena
- [x] Instrukce pro instalaci a build
- [x] Technologie a závislosti

### 4. **Konfigurace projektu** ⚠️ POTŘEBUJE MANUÁLNÍ ÚPRAVY
- [ ] **Změnit Bundle ID** - aktuálně `P24L.Limit`, doporučuji `com.github.zdenekindra.limit`
- [x] **Aktualizovat Development Team** v project.pbxproj - ✅ HOTOVO pomocí Local.xcconfig
- [x] **Přidat MIT licenci** - připraveno

### 5. **Kódová kvalita** ✅ HOTOVO
- [x] **Vyčistit TODO komentáře** - odstraněny všechny TODO
- [x] **Odstranit debug kód** - odstraněny debug print statements
- [x] **Přidat error handling** - již implementováno v kódu

### 6. **Dokumentace a metadata** ✅ HOTOVO
- [x] **README.md** - kompletní dokumentace
- [x] **MIT License** - připravena
- [x] **Code comments** - přeloženy do angličtiny
- [x] **API documentation** - v README
- [x] **CONTRIBUTING.md** - guidelines pro přispěvatele
- [x] **CHANGELOG.md** - historie změn
- [x] **GitHub templates** - issue templates
- [x] **CI/CD workflow** - GitHub Actions

### 7. **Build a deployment** ⚠️ POTŘEBUJE MANUÁLNÍ ÚPRAVY
- [ ] **Test build** - otestovat build na čistém prostředí
- [ ] **Archive preparation** - připravit pro distribuci
- [ ] **Code signing** - nastavit pro open source

### 8. **Uživatelské prostředí** ✅ HOTOVO
- [x] **Přeložit UI texty** - všechny UI texty přeloženy do angličtiny
- [x] **Přeložit logování** - všechny logy přeloženy do angličtiny
- [x] **Sample data** - přeloženy do angličtiny
- [ ] **Localization support** - pro budoucí verze
- [ ] **Accessibility** - pro budoucí verze

### 9. **Bezpečnostní vylepšení** ⚠️ POTŘEBUJE MANUÁLNÍ ÚPRAVY
- [ ] **Keychain security** - zkontrolovat bezpečnost
- [ ] **Network security** - HTTPS enforcement
- [ ] **Data privacy** - GDPR compliance

### 10. **Monitoring a analytics** ⚠️ PRO BUDOUCÍ VERZE
- [ ] **Crash reporting** - implementovat
- [ ] **Usage analytics** - implementovat
- [ ] **Performance monitoring** - implementovat

## 🎯 NICE-TO-HAVE (Dobrovolné kroky)

### 11. **Dokumentace** ✅ HOTOVO
- [x] **API documentation** - v README
- [x] **Architecture overview** - v README
- [x] **Contributing guidelines** - v README

### 12. **Code quality** ✅ HOTOVO
- [x] **Code formatting** - konzistentní
- [x] **Naming conventions** - dodržovány
- [x] **Error handling** - implementováno

### 13. **Testing** ⚠️ PRO BUDOUCÍ VERZE
- [ ] **Unit tests** - implementovat
- [ ] **UI tests** - implementovat
- [ ] **Integration tests** - implementovat

## 📋 ZBÝVAJÍCÍ ÚKOLY

### Manuální úpravy v Xcode:
1. **Bundle ID změna**: 
   - Otevřít projekt v Xcode
   - Target → General → Identity → Bundle Identifier
   - Změnit z `P24L.Limit` na `com.github.zdenekindra.limit`

2. **Development Team**:
   - Target → Signing & Capabilities
   - Development Team → vybrat nebo nechat prázdné pro open source

3. **Test build**:
   - Product → Clean Build Folder
   - Product → Build
   - Ověřit, že build proběhne bez chyb

### GitHub příprava:
1. **Repository setup**:
   - Vytvořit nový repository na GitHub
   - Push kódu (pouze poslední commit bez historie)
   - Nastavit repository jako public

2. **Releases**:
   - Vytvořit první release s tagem v1.0.0
   - Přidat release notes
   - Upload build artifacts (volitelně)

## 🎉 HOTOVO ✅
- ✅ Odstranění citlivých údajů
- ✅ Aktualizace .gitignore
- ✅ Vytvoření README.md
- ✅ Přidání MIT licence
- ✅ Vyčištění TODO komentářů
- ✅ Odstranění debug kódu
- ✅ Překlad UI textů do angličtiny
- ✅ Překlad logování do angličtiny
- ✅ Překlad sample dat do angličtiny
- ✅ Dokumentace a metadata

## ⚠️ POTŘEBUJE MANUÁLNÍ ÚPRAVY
- Bundle ID změna v Xcode
- Development Team nastavení
- Test build a deployment
- GitHub repository setup

## 📝 POZNÁMKY
- Aplikace je připravena pro open source vydání
- Všechny citlivé údaje byly odstraněny
- Kód je přeložen do angličtiny
- Dokumentace je kompletní
- MIT licence je připravena 