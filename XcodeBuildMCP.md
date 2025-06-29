# XcodeBuildMCP - Instrukce pro Claude Code

## Základní pravidlo
**VŽDY používej XcodeBuildMCP nástroje** pro všechny Xcode operace místo command-line příkazů.

## Workflow
1. **Zjisti projekty** - discover Xcode projects/workspaces
2. **Zobraz schemes** - list available schemes  
3. **Build** - použij platform-specific build (iOS simulator/device/macOS)
4. **Test** - spusť testy pomocí XcodeBuildMCP
5. **Deploy** - instaluj a spusť na simulátoru/zařízení

## Nové projekty
```
Scaffolding parametry:
- Název + bundle ID (com.company.app)
- Platform (iOS/macOS) 
- Deployment target
- Device family (iPhone/iPad/Universal)
```

## Klíčové nástroje
- **Simulátory**: list → boot → install → launch → capture logs
- **Fyzická zařízení**: list → build → install → launch → monitor
- **Swift packages**: build → test → run executables
- **Debugging**: capture logs, screenshots, UI automation

## Příklad použití
```
"Vytvoř iOS projekt MyApp s bundle com.example.myapp, 
build pro simulator, spusť testy, pokud OK tak nainstaluj a spusť"
```

Autonomně validuj kód builděním a testováním. Iteruj dokud vše nefunguje.