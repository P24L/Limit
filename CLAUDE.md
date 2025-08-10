# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Limit** is a modern SwiftUI-based Bluesky client for iOS built with the AT Protocol. The app provides timeline browsing, user interactions, bookmarks management, and social features for the Bluesky social network.

## Personal Instructions
- User communicates in Czech language
- Use English when writing anything in project files
- Respond in Czech when discussing code changes

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

#### For iOS Simulator (Default Development Workflow)
```bash
# Standard setup assumes simulator is already running

# 1. Build for iOS Simulator by UUID (preferred method)
mcp__XcodeBuildMCP__build_sim_id_proj({
  projectPath: '/Users/zdenekindra/ios_dev/Limit/Limit.xcodeproj',
  scheme: 'Limit',
  simulatorId: '00B394E4-6FF8-48D5-87A7-F59CC9EF168C',
  extraArgs: ['-allowProvisioningUpdates']
})

# 2. Get app path and bundle ID
mcp__XcodeBuildMCP__get_sim_app_path_id_proj({
  projectPath: '/Users/zdenekindra/ios_dev/Limit/Limit.xcodeproj',
  scheme: 'Limit',
  platform: 'iOS Simulator',
  simulatorId: '00B394E4-6FF8-48D5-87A7-F59CC9EF168C'
})

mcp__XcodeBuildMCP__get_app_bundle_id({
  appPath: '/path/from/previous/step'
})

# 3. Install and launch on simulator
mcp__XcodeBuildMCP__install_app_sim({
  simulatorUuid: '00B394E4-6FF8-48D5-87A7-F59CC9EF168C',
  appPath: '/path/from/get_sim_app_path'
})

mcp__XcodeBuildMCP__launch_app_sim({
  simulatorUuid: '00B394E4-6FF8-48D5-87A7-F59CC9EF168C',
  bundleId: 'P24L.Limit.dev'
})

# If simulator is NOT running, start with:
# mcp__XcodeBuildMCP__list_sims({ enabled: true })
# mcp__XcodeBuildMCP__boot_sim({ simulatorUuid: '00B394E4-6FF8-48D5-87A7-F59CC9EF168C' })
# mcp__XcodeBuildMCP__open_sim({ enabled: true })
```

#### For Physical Device (iPhone "Zdenek")
```bash
# 1. List connected devices
mcp__XcodeBuildMCP__list_devices

# 2. Build for physical device
mcp__XcodeBuildMCP__build_dev_proj({
  projectPath: '/Users/zdenekindra/ios_dev/Limit/Limit.xcodeproj',
  scheme: 'Limit',
  extraArgs: ['-allowProvisioningUpdates']
})

# 3. Install and launch on device
mcp__XcodeBuildMCP__install_app_device({
  deviceId: 'A7EA262F-D0FB-55DA-B7DD-890C49F58606',
  appPath: '/path/from/build'
})

mcp__XcodeBuildMCP__launch_app_device({
  deviceId: 'A7EA262F-D0FB-55DA-B7DD-890C49F58606',
  bundleId: 'P24L.Limit.dev'
})
```

#### Test Execution
```bash
# Run tests on iOS Simulator
mcp__XcodeBuildMCP__test_sim_name_proj({
  projectPath: '/Users/zdenekindra/ios_dev/Limit/Limit.xcodeproj',
  scheme: 'Limit',
  simulatorName: 'iphone16promax',
  extraArgs: ['-allowProvisioningUpdates']
})
```

### Important Notes for MCP Tools
- **Project vs Workspace**: This project uses `_proj` tools (project), not `_ws` tools (workspace)
- **Preferred method**: Use `build_sim_id_proj` with UUID instead of `build_sim_name_proj`
- **Available simulators**: 
  - "iphone16promax" has UUID `00B394E4-6FF8-48D5-87A7-F59CC9EF168C`
- **Physical device**: iPhone "Zdenek" has UDID `A7EA262F-D0FB-55DA-B7DD-890C49F58606`
- **Bundle ID**: Development builds use `P24L.Limit.dev` (not `P24L.Limit`)
- **Provisioning flag**: Always include `extraArgs: ['-allowProvisioningUpdates']` for code signing
- **Default workflow**: Use simulator for development unless specifically targeting physical device
- **Standard setup**: Assumes simulator is already running, use boot/open commands only if needed

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
- **swift-log (v1.6.3)**: Logging infrastructure (ATProto dependency)

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
- **AppTab**: Main tabs (Timeline, ComputedTimeline, Search, Favorites, Settings)
- **Destination**: Navigation targets (posts, threads, profiles)
- **Sheet**: Modal presentations (login, full-screen images)

#### Network Layer (`BlueskyClient.swift`)
Comprehensive AT Protocol client featuring:
- Authentication with handle/app-password and auto-retry
- Timeline operations with cursor-based pagination
- **Hot Posts Algorithm**: Optimized content discovery (6-7s, fresh content only)
- **Batch Processing**: Handles 25-post API limits efficiently
- Smart caching with background refresh capabilities
- Robust error handling including automatic token refresh

#### Data Models
- **`TimelinePost`**: Main SwiftData entity with embeds, relationships, viewer state
- **`TimelinePostWrapper`**: Observable wrapper for UI binding
- **`TimelineFeed`**: Observable collection manager for timeline data
- **Media Models**: `PostImage`, `PostLinkExt`, `PostVideo` for post embeds
- **Favorites**: `FavoriteURL`, `FavoritePost` for saved content (legacy, migrating to bookmarks)
- **Rich Text**: `PostFacet` for link detection and rich text formatting

#### Bookmark System Architecture
Modern bookmark system using AT Protocol (replacing legacy favorites):
- **`BookmarkManager`**: Central manager for bookmark operations with optimistic UI updates
- **`BookmarkSyncEngine`**: Handles AT Protocol sync with per-user cache isolation
- **`BookmarkProcessingQueue`**: Background processing for AI descriptions
- **`BookmarkMigrationManager`**: One-time migration from FavoriteURL to AT Protocol
- **Cache Strategy**: `BookmarkCacheDB_v2` with pagination (50 items/page)
- **Memory Management**: LRU cache with 200 bookmark limit

#### SwiftData Schema Configuration
Multiple schemas for different data domains:

**Main App Schema** (`LimitConfiguration.swift`):
```swift
enum AppSchema {
    static let allModels: [any PersistentModel.Type] = [
        TimelinePost.self,
        PostImage.self, 
        FavoriteURL.self,  // Legacy, kept for migration
        FavoritePost.self
    ]
}
```

**Bookmark Cache Schema** (`BookmarkCacheConfiguration.swift`):
```swift
enum BookmarkCacheSchema {
    static let allModels: [any PersistentModel.Type] = [
        CachedBookmark.self,
        CachedBookmarkList.self,
        BookmarkReminder.self
    ]
}
```

- **Databases**: 
  - `LimitDB_v40` - Main app data
  - `BookmarkCacheDB_v2` - Bookmark cache with per-user isolation
- **Performance**: Maximum 1,000 posts in timeline cache
- **Pagination**: Maximum 10 fetch loops per timeline request

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
- **AppTab**: Enum for main tabs (Timeline, ComputedTimeline, Search, Favorites, Settings)
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
- **Supported Devices**: iPhone only (Portrait + Landscape orientations)
- **Local Development**: Uses `Local.xcconfig` for team settings (not committed)

### Key Files
- **`Local.xcconfig`**: Contains `DEVELOPMENT_TEAM` setting for local builds
- **`buildServer.json`**: Build Server Protocol configuration for IDE integration
- **`PrivacyInfo.xcprivacy`**: Privacy manifest for App Store compliance (UserDefaults, file timestamps, system boot time, disk space access)
- **`.github/workflows/ci.yml.disabled`**: CI/CD workflow (currently disabled)

## Notable Implementation Details

### Hot Posts Algorithm
Optimized content discovery system that:
- Analyzes user's social network (2-hop followers/following exploration)
- **Fresh Content Focus**: Hard 7-day time limit eliminates old posts
- **Exponential Time Decay**: 2-day half-life favors recent content
- **Quality Filtering**: Score threshold (≥3) ensures engagement quality
- **Performance Optimized**: 6-7 second execution time
- **Batch Processing**: Handles API limits with 25-post batches
- Uses weighted random sampling to ensure content diversity
- Implements background caching for optimal performance

### Authentication Flow
- Keychain-based credential persistence for secure storage
- Automatic token refresh on expiration
- Graceful handling of authentication state changes
- Support for Bluesky app passwords (not main account passwords)

### Timeline Management
- **Infinity Scroll**: Smooth batch loading with background preparation
- **ComputedTimeline**: AI-powered hot posts with 6-7s generation time
- Cursor-based pagination for infinite scroll behavior
- Duplicate prevention via URI tracking
- Efficient SwiftData storage with relationship prefetching
- Smart refresh strategies (incremental vs full refresh)
- **Session-level caching**: Preserves timeline state across navigation

### Bookmark System
Modern bookmark implementation using AT Protocol:
- **Optimistic UI**: Instant feedback with `toggleBookmark()` method
- **Local-first**: Updates UI immediately, syncs in background
- **Per-user isolation**: Each user has separate bookmark cache
- **Smart pagination**: Cache-level pagination (50 items per page)
- **LRU eviction**: Automatically manages memory with 200 bookmark limit
- **Background processing**: AI descriptions generated asynchronously
- **Migration support**: One-time migration from legacy FavoriteURL system
- **List management**: Support for bookmark lists with pinning and sorting

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
The app currently has no test target or unit tests. Testing is handled through:
- **Preview Data**: Comprehensive sample data generation (`SampleData.swift`)
- **In-App Debugging**: Log viewer for debugging (`LogViewer.swift`)
- **Manual Testing**: Modular architecture designed for testability
- **CI/CD**: Setup ready for automated testing (currently disabled)

Note: Consider adding unit tests for core business logic, especially BlueskyClient, timeline operations, and data model transformations.

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
- **Simulators**: Use list → boot → **open_sim** → install → launch → capture logs workflow
- **CRITICAL**: Always use `open_sim({ enabled: true })` after booting simulator to make it visible
- **Physical Devices**: Use list → build → install → launch → monitor workflow
- **Swift Packages**: Use build → test → run executables workflow
- **Debugging**: Capture logs, screenshots, UI automation through XcodeBuildMCP tools

#### Complete Simulator Workflow
```bash
# 1. List and boot simulator
mcp__XcodeBuildMCP__list_sims({ enabled: true })
mcp__XcodeBuildMCP__boot_sim({ simulatorUuid: 'UUID' })

# 2. IMPORTANT: Open Simulator app to make it visible
mcp__XcodeBuildMCP__open_sim({ enabled: true })

# 3. Build, install and launch
mcp__XcodeBuildMCP__build_sim_id_proj({ projectPath: '...', scheme: 'Limit', simulatorId: 'UUID' })
mcp__XcodeBuildMCP__install_app_sim({ simulatorUuid: 'UUID', appPath: '...' })
mcp__XcodeBuildMCP__launch_app_sim({ simulatorUuid: 'UUID', bundleId: 'P24L.Limit.dev' })
```

## Common Development Patterns

### Optimistic UI Updates
When implementing user actions that require network calls:
```swift
// Example: toggleBookmark method
1. Update UI state immediately
2. Perform network operation in background
3. Only revert if operation fails
```

### Swift 6 Concurrency
Handle ModelContext operations on MainActor:
```swift
await MainActor.run {
    context.save()
}
```

### API Naming Conventions
Use clear, action-based method names:
- ✅ `toggleBookmark()` - Clear toggle action
- ✅ `fetchAndSyncBookmarks()` - Describes full operation
- ❌ `updateBookmarkStatus()` - Vague, unclear intent

### Performance Optimizations
- Avoid full syncs after single operations
- Use local updates + background sync
- Implement pagination at cache level
- Apply memory limits with LRU eviction