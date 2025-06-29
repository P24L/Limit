Instrukce pro vyvíjení iOS klienta (Bluesky)

Tyto instrukce slouží jako základ pro udržení konzistence při vývoji SwiftUI aplikace pro iOS. Projekt cílí na nejnovější dostupnou plnou verzi iOS a využívá moderní frameworky a přístupy Apple platformy.

⸻

Verze a technologie
	•	iOS: Cílujeme na poslední stabilní verzi (aktuálně iOS 18+)
	•	Swift: Používáme poslední plně podporovanou verzi jazyka Swift (aktuálně Swift 5.10)
	•	SwiftUI: Využíváme nejnovější možnosti SwiftUI frameworku

⸻

Stavové řízení a data

@Observable
	•	Stavové třídy definuj jako @Observable.
	•	Vlastnosti, které ovlivňují UI, označ jako @Published.
	•	Preferujeme kompozici modelu pomocí pozorovatelných objektů a prostého použití @Environment místo klasického MVVM přístupu s ViewModely. Služby a stav sdílíme pomocí @Environment, čímž zjednodušujeme závislosti a propustnost stavů skrze view hierarchii.

Zásady správy stavu
	•	Stav vlastní view, pokud ho nepotřebuje více komponent
	•	Stav teče dolů, akce tečou nahoru
	•	Sdílej stav jen tam, kde je potřeba (např. přes @Environment)
	•	Udržuj stav co nejblíže místu, kde se používá

SwiftData
	•	Data perzistujeme pomocí SwiftData, nikoli CoreData nebo UserDefaults (ty používejme pouze pro jednoduché věci, kde to dává smysl, např. nastavení uživatele).
	•	Používej anotace jako @Model a @Relationship.
	•	Pro data s časem života v rádu dní (např. cache feedu) je SwiftData preferovaná volba.

Identifikovatelnost modelů
	•	Pro kolekce ve view používej Identifiable struktury (id může být URI, rkey, nebo jiné stabilní ID).
	•	Umožňuje bezproblémové použití s ForEach, diff tracking a optimalizaci UI aktualizací.

⸻

Architektura a vrstvy

Oddělení UI a logiky
	•	Každý View by měl být co nejjednodušší, zaměřený čistě na prezentaci.
	•	Veškerá logika (stahování dat, business logika) by měla být ve službách nebo helper strukturách, ideálně testovatelných.
	•	Pomáhá to přehlednosti i znovupoužitelnosti komponent.

Wrappery a adaptace
	•	Pro práci s výsledky z API používej pomocné typy (např. TimelinePostWrapper), které adaptují raw data na použitelnou formu pro UI.
	•	Umožňuje snadnou manipulaci, caching, a případné rozšíření o metadata, např. stav načtení, lokalní ID, atd.

Organizace kódu
	•	Organizuj podle funkcionality, ne podle typu (vyhýbej se Views/, Models/, ViewModels/)
	•	Související view a logiku udržuj pohromadě (klidně i v jednom souboru)
	•	Používej extensions pro přehlednost a modularitu

⸻

Dependency Injection a prostředí

@Environment
	•	Sdílené služby (např. BlueskyClient, ImageLoader, NavigationRouter) injektuj pomocí @Environment nebo @EnvironmentObject.
	•	Vytvářej typ-safe zápisy pomocí EnvironmentKey.

⸻

Navigace pomocí AppRouter

AppRouter je knihovna pro deklarativní navigaci ve SwiftUI.

Definice typů
	•	AppTab: Enum implementující TabType, definuje jednotlivé taby aplikace.
	•	Destination: Enum implementující DestinationType, definuje navigační cíle.
	•	Sheet: Enum implementující SheetType, definuje modalní prezentace.
	•	typealias AppRouter = Router<AppTab, Destination, Sheet>

Použití
	•	Každý tab má NavigationStack(path: $router[tab])
	•	Navigace v rámci tabů: router.navigateTo(.postThreadWrapped(postThread: post))
	•	Navigace do Safari v samostatném tabu:

router.popToRoot(for: .safari)
router.selectedTab = .safari
router.navigateTo(.safari(url: url), for: .safari)


	•	Sheet prezentace: router.presentedSheet = .fullScreenImage(...)
	•	Přístup přes @Environment(AppRouter.self)

⸻

Logování pomocí DevLogger

Aplikace používá jednoduchý paměťový logger pro ladění.

Použití
	•	Volání pomocí DevLogger.shared.log("<soubor> - <popis>")
	•	Log obsahuje timestamp a text zprávy
	•	Pro složité funkce doporučeno krokování např. - krok 1, - krok 2

Příklad

DevLogger.shared.log("BlueskyClient.swift - fetchTimeline - Načítám timeline")

Logy lze zobrazit v UI pomocí LogViewer().

⸻

Doplňující pravidla a doporučení
	•	Obrázky: Používej SDWebImageSwiftUI pro async image loading s cache.
	•	Bezpečnost: Tokeny ukládej do Keychain (např. pomocí KeychainSwift)
	•	Testing: Odděluj logiku od UI, aby bylo možné testovat modely a služby samostatně.
	•	CI/CD: Dodržuj strukturu kódu a dependency injection pro snadné testování a nasazování.

⸻

Možnosti k rozšíření (nabízet dle potřeby)
	•	Používej APIClient nebo podobnou abstrakci nad URLSession s podporou async/await, centralizovaným logováním a správou chyb.
	•	Implementuj lokální cache (paměťovou nebo diskovou) pro data jako Feed, Post, Profile, zejména pokud nejsou v SwiftData.
	•	Připravuj mockované klienty a preview data pro snadné testování a vývoj.
	•	Konstrukce komponent přizpůsob pro Preview použití (.init(...) s testovacím obsahem).
	•	Používej .task {} pro načítání dat vázané na lifecycle view.
	•	Upřednostňuj async/await před Combine, pokud není výslovně potřeba.
	•	Používej try/catch pro správu chyb při asynchronních voláních.

⸻

Tento dokument lze průběžně rozšiřovat o další pravidla a konvence podle evoluce projektu.