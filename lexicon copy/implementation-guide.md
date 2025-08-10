# Implementation Guide

This guide provides technical details for implementing the AT Protocol bookmark system.

## Lexicon Overview

The bookmark system consists of three main lexicons under the `app.hyper-limit` namespace:

### 1. app.hyper-limit.bookmark

The core bookmark record containing:
- **Required fields**: `url`, `title`, `createdAt`
- **Optional fields**: `description`, `note`, `tags`, `listUris`, `imageUrl`, `imageBlob`, etc.
- **Privacy support**: `encrypted` flag for client-side encryption
- **Social features**: `sourceUri` for tracking bookmark origin

### 2. app.hyper-limit.bookmark.list

Organizational structure supporting three visibility modes:
- **private**: Personal folders/lists
- **collaborative**: Shared with specific users
- **public**: Discoverable and followable

Key features:
- Hierarchical organization via `parent` field
- Visual customization with `color` and `icon`
- Permission management via `permissions.canAdd` array

### 3. app.hyper-limit.bookmark.embed

Enables rich bookmark previews in posts using AT Protocol's embed system.

## Data Model

### Bookmark-List Relationship

Bookmarks reference lists through the `listUris` array, allowing:
- A bookmark to belong to multiple lists
- Lists to be queried independently
- Efficient bookmark organization

```
Bookmark A → [List 1, List 2]
Bookmark B → [List 2, List 3]
```

### Hierarchical Lists

Lists can reference parent lists, creating folder structures:

```
Root List
├── Work
│   ├── Projects
│   └── Documentation
└── Personal
    ├── Reading
    └── Recipes
```

## Privacy Implementation

### Encrypted Bookmarks

When `encrypted: true`:
1. Client encrypts sensitive fields before storage
2. Only encrypted strings are sent to PDS
3. Metadata remains unencrypted for indexing

Recommended encryption approach:
```typescript
// Fields to encrypt
const sensitiveFields = ['description', 'note'];

// Encrypt before creating record
if (bookmark.encrypted) {
  for (const field of sensitiveFields) {
    if (bookmark[field]) {
      bookmark[field] = await encrypt(bookmark[field], userKey);
    }
  }
}
```

### Key Management

- Generate device-specific keys
- Store keys securely in device keychain
- Implement key sharing for multi-device access
- Never store keys in AT Protocol records

## Permission System

### List Visibility

1. **Private Lists**
   - Only owner DID can read/write
   - Not indexed in public feeds
   - Not discoverable via search

2. **Collaborative Lists**
   - Owner controls membership
   - Members listed in `permissions.canAdd`
   - AppView enforces access control

3. **Public Lists**
   - Anyone can read
   - Only owner can write
   - Indexed in public feeds
   - Accept suggestions via replies

### Access Control Flow

```
User Action → AppView → Permission Check → Allow/Deny
                ↓
         Server Indexer → Validate → Update Feed
```

## Social Features Integration

### Embedding in Posts

```typescript
const post = {
  $type: 'app.bsky.feed.post',
  text: 'Check this out!',
  embed: {
    $type: 'app.hyper-limit.bookmark.embed',
    bookmark: {
      uri: bookmarkUri,
      cid: bookmarkCid
    }
  }
};
```

### Interactions

- **Likes**: Standard AT Protocol like records
- **Comments**: Reply threads on bookmark URIs
- **Reposts**: Repost bookmark records
- **Quotes**: Posts with embedded bookmarks

## Feed Generation

### Bookmark Feeds

1. **User's Bookmarks**: Filter by repo DID
2. **List Feed**: Filter by `listUris` containing list URI
3. **Tag Feed**: Filter by `tags` array
4. **Following Feed**: Aggregate from followed users

### Indexing Strategy

```typescript
// Index public bookmarks
if (!bookmark.encrypted && isPublicList(bookmark.listUris)) {
  index.add({
    uri: record.uri,
    cid: record.cid,
    author: record.repo,
    tags: bookmark.tags,
    createdAt: bookmark.createdAt
  });
}
```

## Import/Export

### Browser Bookmark Import

1. Parse Netscape HTML format
2. Extract URL, title, add date
3. Map folders to lists
4. Create records in batches

### Export Format

```json
{
  "version": "1.0",
  "exportDate": "2024-01-01T00:00:00Z",
  "bookmarks": [...],
  "lists": [...],
  "encrypted": false
}
```

## Best Practices

### Performance

- Batch create operations when importing
- Cache list metadata locally
- Use cursor pagination for large collections
- Implement local search before API calls

### Security

- Validate URLs before storage
- Sanitize HTML in descriptions
- Rate limit bulk operations
- Implement CORS properly for web apps

### User Experience

- Provide offline bookmark access
- Sync encrypted bookmarks across devices
- Show progress for bulk operations
- Handle conflicts gracefully

## Error Handling

### Common Errors

1. **Invalid URL Format**
   ```typescript
   if (!isValidUrl(bookmark.url)) {
     throw new Error('Invalid URL format');
   }
   ```

2. **Permission Denied**
   ```typescript
   if (!canAddToList(user.did, list)) {
     throw new Error('Permission denied for this list');
   }
   ```

3. **Rate Limiting**
   ```typescript
   if (isRateLimited(user.did)) {
     throw new Error('Too many requests, please wait');
   }
   ```

## Testing

### Lexicon Validation

```bash
# Validate individual lexicon
atproto-lexicon validate lexicons/app.hyper-limit.bookmark.json

# Validate all lexicons
npm run validate
```

### Test Cases

1. Create bookmark with all fields
2. Create encrypted bookmark
3. Add bookmark to multiple lists
4. Create hierarchical lists
5. Test permission enforcement
6. Verify feed generation
7. Test import/export roundtrip

## Migration Guide

For existing bookmark systems:

1. Map existing data to lexicon fields
2. Create lists for folder structures
3. Preserve timestamps
4. Handle missing required fields
5. Batch import in chunks
6. Verify data integrity

## Future Considerations

- WebSocket support for real-time updates
- Full-text search capabilities
- AI-powered categorization
- Archived content preservation
- Cross-platform browser extensions