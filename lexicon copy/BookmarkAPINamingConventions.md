# Bookmark API Naming Conventions

## Overview
This document defines the standardized naming conventions for the Bookmark system API to ensure consistency and clarity.

## Core Principles

1. **Clarity**: Method names should clearly indicate what they do
2. **Consistency**: Similar operations should use similar naming patterns
3. **Predictability**: Developers should be able to guess method names based on patterns

## Naming Patterns

### CRUD Operations

#### Create
- `create[Entity]` - Creates a new entity
  - ✅ `createBookmark()`
  - ✅ `createBookmarkList()`

#### Read/Fetch
- `fetch[Entity]` - Fetches from remote API
- `load[Entity]` - Loads from local cache
- `get[Entity]` - Gets computed or simple values
  - ❌ `syncBookmarks()` → ✅ `fetchAndSyncBookmarks()`
  - ✅ `loadFromCache()`
  - ✅ `getMemoryInfo()`

#### Update
- `update[Entity]` - Updates existing entity
  - ✅ `updateBookmarkList()`
  - ❌ `toggleBookmark()` → ✅ `updateBookmarkStatus()`
  - ❌ `toggleBookmarkListPin()` → ✅ `updateBookmarkListPinStatus()`

#### Delete
- `delete[Entity]` - Deletes entity
  - ✅ `deleteBookmark()`
  - ✅ `deleteBookmarkList()`

### State Management

#### Boolean Toggles
- `update[Entity][Property]Status` - For boolean properties
  - ❌ `toggleBookmark()` → ✅ `updateBookmarkStatus()`
  - ❌ `toggleBookmarkListPin()` → ✅ `updateBookmarkListPinStatus()`

#### Collections
- `add[Entity]To[Collection]` - Adds to collection
- `remove[Entity]From[Collection]` - Removes from collection
  - ✅ `addBookmarkToLists()`
  - 🆕 Need: `removeBookmarkFromLists()`

### Async Operations

#### Background Processing
- `enqueue[Entity]For[Process]` - Adds to processing queue
  - ✅ `enqueueForProcessing()`
  - ❌ `enqueueForDescription()` → ✅ `enqueueBookmarkForDescription()`

#### Sync Operations
- `sync[Entity]` - Two-way sync with remote
- `fetch[Entity]` - One-way fetch from remote
- `push[Entity]` - One-way push to remote
  - ❌ `syncBookmarks()` → ✅ `fetchAndSyncBookmarks()`

### User/Session Management
- `[action]For[Scope]` - Scoped operations
  - ❌ `clearUserBookmarks()` → ✅ `deleteBookmarksForUser()`
  - ❌ `reloadForNewUser()` → ✅ `loadBookmarksForCurrentUser()`

## Recommended Changes

### BookmarkManager

```swift
// Current → Recommended
syncBookmarks() → fetchAndSyncBookmarks()
toggleBookmark() → updateBookmarkStatus()
toggleBookmarkListPin() → updateBookmarkListPinStatus()
clearUserBookmarks() → deleteBookmarksForUser()
reloadForNewUser() → loadBookmarksForCurrentUser()
addToCache() → cacheBookmark()
```

### BookmarkProcessingQueue

```swift
// Current → Recommended
enqueueForDescription() → enqueueBookmarkForDescription()
enqueueForImageGeneration() → enqueueBookmarkForImageGeneration()
```

### BookmarkSyncEngine

```swift
// Current → Recommended
syncBookmarks() → performFullSync()
syncBookmarkLists() → fetchBookmarkLists()
syncAllBookmarks() → fetchAllBookmarks()
clearBookmarksForUser() → deleteAllBookmarksForUser()
```

## Method Prefixes Guide

- `create` - Creates new entity
- `fetch` - Gets data from remote API
- `load` - Gets data from local storage
- `get` - Returns computed values or properties
- `update` - Modifies existing entity
- `delete` - Removes entity
- `add` - Adds to collection
- `remove` - Removes from collection
- `enqueue` - Adds to processing queue
- `process` - Performs processing operation
- `cache` - Stores in cache
- `track` - Records activity/metrics