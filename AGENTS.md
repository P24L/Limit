# Repository Guidelines

## Project Structure & Module Organization
- `Limit/`: App source (SwiftUI views in `Views/`, models in `Model/`, networking in `Network/`, utilities in `Utils/`, and design tokens in `DesignSystem/`).
- `ShareExtension/`: Share extension target code.
- `Packages/WebImageExtractor/`: Swift Package (library + tests).
- `Support/`, `Images/`: Assets and supporting files.
- `Limit.xcodeproj`: Xcode project; open this for local development.

## Build, Test, and Development Commands
- Open project: `open Limit.xcodeproj` (build/run with Cmd+R in Xcode).
- Clean build: `xcodebuild clean -project Limit.xcodeproj -scheme Limit`.
- Build (simulator): `xcodebuild build -project Limit.xcodeproj -scheme Limit -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Package tests: `cd Packages/WebImageExtractor && swift test` or `xcodebuild test -project Limit.xcodeproj -scheme Limit`.

## Coding Style & Naming Conventions
- Indentation: 4 spaces; use Xcode’s auto-format (Editor → Format).
- Naming: Types `UpperCamelCase`, functions/vars `lowerCamelCase`; views end with `View` (e.g., `TimelineView.swift`).
- Files: One primary type per file; filename matches type.
- Practices: Prefer `async/await`, avoid force unwraps, add `// MARK:` sections for large files.
- Lint/format: No enforced tool; follow Swift API Design Guidelines and existing patterns.

## Testing Guidelines
- Framework: XCTest. Existing tests live under `Packages/WebImageExtractor/Tests/...` and end with `*Tests.swift`.
- Add unit tests for new logic; mock network where possible (no live calls in tests).
- Naming: `testMethod_underTest_expectedOutcome`.
- Run: `swift test` in the package, or `xcodebuild test -scheme Limit` for project schemes.

## Commit & Pull Request Guidelines
- Commits: Imperative, concise titles; scope prefix optional (e.g., `Bookmarks:`, `OAuth:`). Keep changes focused.
- PRs: Clear description, linked issues, steps to validate, and screenshots for UI changes. Note user-facing changes in `CHANGELOG.md` when relevant.

## Security & Configuration Tips
- Do not commit secrets or personal tokens. Keep local overrides in `Local.xcconfig` and out of VCS.
- For Bluesky, use app passwords (not the main account password).
- Associated Domains and analytics configs exist—verify entitlements and bundle IDs before shipping.

## Architecture Overview
- SwiftUI + modular layers: UI in `Views/`, data in `Model/`, APIs in `Network/`, shared helpers in `Utils/`, and reusable package code in `Packages/`.
