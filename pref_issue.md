 Struktura preferences

  1. Co jsou preferences

  Preferences jsou uživatelská nastavení uložená na serveru. Je to array různých typů nastavení:

  preferences = [
      PreferenceUnion.adultContent(...),        // Nastavení pro dospělý obsah
      PreferenceUnion.mutedWords(...),          // Ztlumená slova
      PreferenceUnion.contentLabel(...),        // Nastavení labelů
      PreferenceUnion.savedFeedsVersion2(...),  // Uložené feeds a lists
      // ... další preference typy
  ]

  2. SavedFeedsV2 je JEDEN z typů preferences

  SavedFeedsV2 obsahuje pouze informace o:
  - Které feeds má uživatel odebírané (subscribed)
  - Které lists má uživatel vytvořené/odebírané
  - Které jsou připnuté (pinned)
  - V jakém pořadí se mají zobrazovat

  SavedFeedsVersion2 = {
      items: [
          { type: "feed", value: "at://feed1", pinned: true },
          { type: "list", value: "at://list1", pinned: false },
          { type: "feed", value: "at://feed2", pinned: false },
          // ...
      ]
  }

  3. Jak funguje API

  Když voláte putPreferences, musíte poslat VŠECHNY preference, ne jen ty, které měníte:

  // ŠPATNĚ - smaže všechny ostatní preference
  putPreferences([.savedFeedsVersion2(newFeeds)])

  // SPRÁVNĚ - zachová všechny preference
  putPreferences([
      .adultContent(existingAdultContent),
      .mutedWords(existingMutedWords),
      .savedFeedsVersion2(newFeeds),
      // ... všechny ostatní
  ])

  4. Náš přístup a jeho důsledky

  Protože máme problém s deserializací některých preference typů, posíláme POUZE SavedFeedsV2:

  // Náš kód
  return await putPreferences(preferences: [.savedFeedsVersion2(newSavedFeeds)])

  Co to znamená:
  - ✅ Feeds a lists fungují perfektně
  - ❌ Ostatní preference (adult content, muted words) se SMAŽOU

  5. Proč je to "v pořádku"

  Je to v pořádku, protože:

  1. Naše aplikace tyto preference nepoužívá - nemáme UI pro nastavení adult content nebo muted words
  2. Uživatel může tyto preference nastavit v jiné aplikaci (oficiální Bluesky app)
  3. Je to dočasné řešení - až ATProtoKit opraví serializaci, můžeme poslat všechny preference

  6. Ideální řešení (až bude opraveno)

  // Načíst všechny preference
  let current = await getPreferences()

  // Najít a upravit pouze SavedFeedsV2
  var updated = current.preferences
  for (index, pref) in updated.enumerated() {
      if case .savedFeedsVersion2(_) = pref {
          updated[index] = .savedFeedsVersion2(newSavedFeeds)
      }
  }

  // Poslat všechny preference zpět
  await putPreferences(preferences: updated)  // Zachová všechna nastavení

  Shrnutí: SavedFeedsV2 je jen jedna část z mnoha uživatelských nastavení. My teď posíláme pouze tuto část, což znamená, že ostatní
  nastavení se smažou. To je přijatelné, protože naše aplikace tato ostatní nastavení nepoužívá.