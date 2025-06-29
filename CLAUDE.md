# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Limit** is a modern SwiftUI-based Bluesky client for iOS built with the AT Protocol. The app provides timeline browsing, user interactions, and favorites management for the Bluesky social network.

## Personal instructions
I communicate in chat usually in Czech language
Use English when writing anaything in project files.

## Build Commands

### ⚠️ IMPORTANT: Use XcodeBuildMCP Tools
**ALWAYS use XcodeBuildMCP tools** for all Xcode operations instead of command-line commands.

### Recommended Workflow
1. **Discover projects**: Use `mcp__XcodeBuildMCP__discover_projs`
2. **List schemes**: Use `mcp__XcodeBuildMCP__list_schems_proj`
3. **Build**: Use platform-specific build tools (iOS simulator/device/macOS)
4. **Test**: Run tests using XcodeBuildMCP test tools
5. **Deploy**: Install and launch on simulator/device using XcodeBuildMCP

### XcodeBuildMCP Build Examples
```bash
# Discover Xcode projects in workspace
mcp__XcodeBuildMCP__discover_projs

# Build for iOS Simulator by name (WORKING EXAMPLE for this project)
mcp__XcodeBuildMCP__build_sim_name_ws({
  workspacePath: '/Users/zdenekindra/ios_dev/Limit/Limit.xcodeproj/project.xcworkspace',
  scheme: 'Limit',
  simulatorName: 'Test sim',
  extraArgs: ['-allowProvisioningUpdates']
})

# Run tests on iOS Simulator
mcp__XcodeBuildMCP__test_sim_name_ws({
  workspacePath: '/Users/zdenekindra/ios_dev/Limit/Limit.xcodeproj/project.xcworkspace',
  scheme: 'Limit',
  simulatorName: 'Test sim',
  extraArgs: ['-allowProvisioningUpdates']
})

# Install and launch on simulator
mcp__XcodeBuildMCP__install_app_sim({
  simulatorUuid: 'UUID',
  appPath: '/path/to/app.app'
})
```

### Important Notes for MCP Tools
- **Use workspace**: This project requires `_ws` tools (workspace), not `_proj` tools (project)
- **Correct simulator name**: Use exact simulator name from `list_sims` (e.g., 'Test sim')
- **Provisioning flag**: Always include `extraArgs: ['-allowProvisioningUpdates']` for code signing

### Legacy Command Line (Use XcodeBuildMCP Instead)
```bash
# Open in Xcode
open Limit.xcodeproj

# Build for iOS Simulator (command line)
xcodebuild clean build \
  -project Limit.xcodeproj \
  -scheme Limit \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -configuration Debug

# Build for iOS Device (command line)
xcodebuild clean build \
  -project Limit.xcodeproj \
  -scheme Limit \
  -destination 'generic/platform=iOS' \
  -configuration Release
```

## Architecture Overview

### Core Technology Stack
- **iOS Target**: iOS 18.4+ (always target latest stable iOS version)
- **Swift**: Swift 5.10+ (latest fully supported Swift version)
- **SwiftUI**: Modern declarative UI framework with latest capabilities
- **SwiftData**: Local persistence and caching layer
- **ATProtoKit (v0.29.0)**: Official AT Protocol library for Bluesky integration
- **AppRouter (v1.0.2)**: Typed navigation and routing system
- **KeychainSwift (v24.0.0)**: Secure credential storage
- **SDWebImageSwiftUI (v3.1.3)**: Efficient image loading and caching

### Data Architecture Pattern
The app uses a **dual-layer data architecture**:

1. **Persistence Layer**: SwiftData models (`TimelinePost`, `FavoriteURL`, etc.)
2. **UI Layer**: Observable wrapper classes (`TimelinePostWrapper`, `TimelineFeed`)

This separation allows for:
- Efficient SwiftData persistence with relationships
- Reactive UI updates via `@Observable` wrappers
- Clean separation between data storage and presentation logic

### Key Components

#### App Initialization (`LimitApp.swift`)
- Manages authentication state (`AppState.unauthenticated` / `.authenticated`)
- Initializes core dependencies: `BlueskyClient`, `AppRouter`, `ModelContainer`
- Handles automatic login via Keychain stored credentials

#### Navigation System (`AppRoute.swift`)
Uses `AppRouter` with three navigation layers:
- **AppTab**: Main tabs (Timeline, ComputedTimeline, Favorites, Safari, Settings)
- **Destination**: Navigation targets (posts, threads, profiles)
- **Sheet**: Modal presentations (login, full-screen images)

#### Network Layer (`BlueskyClient.swift`)
Comprehensive AT Protocol client featuring:
- Authentication with handle/app-password and auto-retry
- Timeline operations with cursor-based pagination
- **Hot Posts Algorithm**: Intelligent content discovery via social network analysis
- Smart caching with background refresh capabilities
- Robust error handling including automatic token refresh

#### Data Models
- **`TimelinePost`**: Main SwiftData entity with embeds, relationships, viewer state
- **`TimelinePostWrapper`**: Observable wrapper for UI binding
- **`TimelineFeed`**: Observable collection manager for timeline data
- **Media Models**: `PostImage`, `PostLinkExt`, `PostVideo` for post embeds
- **Favorites**: `FavoriteURL`, `FavoritePost` for saved content

## View Architecture

### Main Views Structure
```
Views/
├── AppRootView.swift              # Root container with tab navigation
├── Timeline/
│   ├── ATTimelineView_experimental.swift  # Primary timeline interface
│   ├── ComputedTimelineView.swift         # Algorithm-based timeline
│   └── ThreadWrappedView.swift            # Conversation threading
├── PostUI/                        # Post display components
├── ActorUI/                       # User profile components
└── TabUI/                         # Tab-specific views (Favorites, Settings)
```

### Component Patterns
- All views use SwiftUI with `@Observable` for state management
- Environment-based dependency injection for services
- Consistent use of `MainActor` annotations for UI thread safety
- Error handling with graceful fallback UI states

## Development Principles & Patterns

### State Management (@Observable Pattern)
- **State Classes**: Define as `@Observable` instead of ViewModels
- **State Flow**: State flows down, actions flow up
- **Environment Injection**: Share services via `@Environment` instead of classic MVVM
- **State Ownership**: Keep state as close as possible to where it's used
- **Composition**: Prefer observable object composition over ViewModels

### SwiftData Usage
- **Primary Persistence**: Use SwiftData for all data persistence (not CoreData/UserDefaults)
- **Model Annotations**: Use `@Model` and `@Relationship` annotations
- **Cache Strategy**: SwiftData preferred for data with lifetime of days (e.g., feed cache)
- **Identifiable Models**: Use `Identifiable` structures with stable IDs (URI, rkey) for collections

### Code Organization
- **Functional Organization**: Organize by functionality, not by type (avoid Views/, Models/, ViewModels/)
- **Co-location**: Keep related views and logic together (even in same file)
- **Extensions**: Use extensions for clarity and modularity
- **Separation**: Keep Views simple, focused on presentation only
- **Business Logic**: All logic should be in services or helper structures (testable)

### AppRouter Navigation Pattern
- **AppTab**: Enum for main tabs (Timeline, ComputedTimeline, Favorites, Safari, Settings)
- **Destination**: Enum for navigation targets (posts, threads, profiles)
- **Sheet**: Enum for modal presentations (login, full-screen images)
- **Navigation**: `router.navigateTo(.postThreadWrapped(postThread: post))`
- **Safari Navigation**: 
  ```swift
  router.popToRoot(for: .safari)
  router.selectedTab = .safari
  router.navigateTo(.safari(url: url), for: .safari)
  ```
- **Sheet Presentation**: `router.presentedSheet = .fullScreenImage(...)`

### DevLogger Usage
- **Centralized Logging**: Use `DevLogger.shared.log("File.swift - Description")`
- **Step Logging**: For complex functions use "- step 1", "- step 2" format
- **Log Viewing**: Use `LogViewer()` component for in-app log display
- **Format**: Include timestamp and descriptive message

### Architecture Guidelines
- **Dependency Injection**: Use `@Environment` for shared services (BlueskyClient, ImageLoader, NavigationRouter)
- **Type Safety**: Create type-safe entries using `EnvironmentKey`
- **Wrapper Pattern**: Use helper types (e.g., `TimelinePostWrapper`) to adapt API data for UI
- **Async/Await**: Prefer async/await over Combine unless specifically needed
- **Error Handling**: Use try/catch for asynchronous calls
- **Task Lifecycle**: Use `.task {}` for loading data tied to view lifecycle

## Development Configuration

### Bundle Configuration
- **Bundle ID**: `P24L.Limit` (production)
- **Deployment Target**: iOS 18.4+
- **Supported Devices**: iPhone + iPad (Universal)
- **Local Development**: Uses `Local.xcconfig` for team settings (not committed)

### Key Files
- **`Local.xcconfig`**: Contains `DEVELOPMENT_TEAM` setting for local builds
- **`buildServer.json`**: Build Server Protocol configuration for IDE integration
- **`.github/workflows/ci.yml.disabled`**: CI/CD workflow (currently disabled)

## Notable Implementation Details

### Hot Posts Algorithm
Sophisticated content discovery system that:
- Analyzes user's social network (followers/following relationships)
- Scores posts based on engagement metrics and social relevance
- Uses weighted random sampling to ensure content diversity
- Implements background caching for optimal performance

### Authentication Flow
- Keychain-based credential persistence for secure storage
- Automatic token refresh on expiration
- Graceful handling of authentication state changes
- Support for Bluesky app passwords (not main account passwords)

### Timeline Management
- Cursor-based pagination for infinite scroll behavior
- Duplicate prevention via URI tracking
- Efficient SwiftData storage with relationship prefetching
- Smart refresh strategies (incremental vs full refresh)

## Development Workflow

### Local Development Setup
1. Clone repository and open `Limit.xcodeproj` in Xcode
2. Configure `Local.xcconfig` with your `DEVELOPMENT_TEAM` ID
3. Update Bundle ID if needed for personal development
4. Build and run on simulator or device

### Code Organization Principles
- Models follow SwiftData patterns with proper relationships
- Views use consistent SwiftUI patterns with environment injection
- Network layer uses modern async/await throughout
- Error handling provides user-friendly fallback states
- All logging uses centralized `DevLogger` system

### Testing Strategy
The app is designed for testing with:
- Comprehensive sample data generation (`SampleData.swift`)
- In-app log viewer for debugging (`LogViewer.swift`)
- Modular architecture enabling unit testing of individual components
- CI/CD setup ready for automated testing (currently disabled)

## Technical Guidelines

### Image Handling
- **SDWebImageSwiftUI**: Use for all async image loading with cache
- **Efficient Loading**: Leverage built-in caching and memory management

### Security
- **Keychain Storage**: Store tokens in Keychain (using KeychainSwift)
- **App Passwords**: Support Bluesky app passwords (not main account passwords)
- **Secure Persistence**: Never store sensitive data in UserDefaults

### Development Best Practices
- **Separation of Concerns**: Separate logic from UI for testability
- **Mock Clients**: Prepare mocked clients and preview data for development
- **Preview Components**: Design components for SwiftUI Preview usage
- **Validation**: Autonomously validate code by building and testing, iterate until everything works

### XcodeBuildMCP Integration
- **Workflow**: discover → list schemes → build → test → install → launch
- **Simulators**: Use list → boot → install → launch → capture logs workflow
- **Physical Devices**: Use list → build → install → launch → monitor workflow
- **Swift Packages**: Use build → test → run executables workflow
- **Debugging**: Capture logs, screenshots, UI automation through XcodeBuildMCP tools