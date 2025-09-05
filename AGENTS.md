# Repository Guidelines

## Project Structure & Module Organization
- App code in `Limit/`:
  - `Views/` (SwiftUI), `Model/`, `Network/`, `Utils/`, `DesignSystem/`.
- Share extension in `ShareExtension/`.
- Swift package in `Packages/WebImageExtractor/` with tests under `Packages/WebImageExtractor/Tests/`.
- Assets/support in `Support/` and `Images/`.
- Open `Limit.xcodeproj` for local development.

## Build, Test, and Development Commands
- Open in Xcode: `open Limit.xcodeproj` (build/run with Cmd+R).
- Clean build: `xcodebuild clean -project Limit.xcodeproj -scheme Limit`.
- Build (simulator): `xcodebuild build -project Limit.xcodeproj -scheme Limit -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Package tests: `cd Packages/WebImageExtractor && swift test`.
- Project tests: `xcodebuild test -project Limit.xcodeproj -scheme Limit`.

## Coding Style & Naming Conventions
- Indentation: 4 spaces; use Xcode auto‑format (Editor → Format).
- Naming: Types `UpperCamelCase`; functions/vars `lowerCamelCase`; SwiftUI views end with `View` (e.g., `TimelineView`).
- Files: One primary type per file; filename matches the type.
- Practices: Prefer `async/await`, avoid force unwraps, add `// MARK:` sections in larger files.
- Follow Swift API Design Guidelines; no enforced linter/formatter.

## Testing Guidelines
- Framework: XCTest (package tests live in `Packages/WebImageExtractor/Tests/...`, ending with `*Tests.swift`).
- Write unit tests for new logic; mock network calls (no live network in tests).
- Naming: `testMethod_underTest_expectedOutcome`.
- Run: `swift test` inside the package, or `xcodebuild test -scheme Limit` for the app project.

## Commit & Pull Request Guidelines
- Commits: Imperative, concise titles; optional scope prefix (e.g., `Bookmarks:`, `OAuth:`). Keep changes focused.
- PRs: Clear description, linked issues, steps to validate, and screenshots for UI changes. Note user‑facing changes in `CHANGELOG.md` when applicable.

## Security & Configuration Tips
- Do not commit secrets or personal tokens; keep local overrides in `Local.xcconfig` (excluded from VCS).
- For Bluesky, use app passwords, not your main account password.
- Verify Associated Domains, analytics configs, entitlements, and bundle IDs before shipping.

## Architecture Overview
- SwiftUI UI with modular layers: UI in `Views/`, data in `Model/`, APIs in `Network/`, helpers in `Utils/`, and reusable code in `Packages/`.
