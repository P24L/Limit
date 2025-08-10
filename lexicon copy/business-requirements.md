# Bookmark System for AT Protocol - Business Requirements Document

## Executive Summary

This document defines the business requirements and technical specifications for a decentralized bookmark management system built on the AT Protocol. The system will enable users to save, organize, share, and discover web bookmarks while maintaining data sovereignty and interoperability with other AT Protocol applications.

## Project Overview

### Vision
Create an open, interoperable bookmark management system that gives users full control over their data while enabling rich social features and discovery mechanisms.

### Key Principles
- **Data Sovereignty**: Users own and control their bookmarks
- **Interoperability**: Works with existing AT Protocol ecosystem
- **Privacy-First**: Support for encrypted private bookmarks
- **Social Features**: Enable sharing, collaboration, and discovery
- **Extensibility**: Design for future enhancements

## Core Features

### 1. Bookmark Management

#### Basic Bookmark Structure
Each bookmark contains the following information:

- **URL** (required): The web address being bookmarked (max 2048 characters)
- **Title** (required): Display title for the bookmark (max 300 characters)
- **Description** (optional): Brief description or excerpt (max 1000 characters)
- **Personal Note** (optional): Private notes about the bookmark (max 10000 characters)
- **Preview Image**: Either a URL reference or blob storage reference for thumbnail
- **Tags**: Multiple categorization tags (max 20 tags, 50 characters each)
- **Folders**: Multiple folder assignments for organization (max 10 folders)
- **Pinned Status**: Boolean flag for important bookmarks
- **Archive Status**: Boolean flag for archived bookmarks
- **Reminder**: Optional date/time with note for follow-up
- **Source URI**: Reference if bookmark was saved from another user
- **Timestamps**: Creation and last update times

#### Privacy Features
- **Encryption Flag**: When enabled, sensitive fields contain encrypted strings
- **Client-side Encryption**: All encryption/decryption happens on device
- **Key Management**: Device-based key storage with secure sharing mechanism

### 2. Social Features

#### Interactions
- **Likes**: Using standard AT Protocol like mechanism
- **Comments**: Reply threads on public bookmarks
- **Reposts**: Share bookmarks to follower feeds
- **Quotes**: Create posts with embedded bookmark previews
- **Save from Others**: Copy another user's public bookmark

#### Following & Discovery
- **Follow Users**: Subscribe to a user's public bookmarks
- **Follow Collections**: Subscribe to specific bookmark collections
- **Tag-based Feeds**: Discover bookmarks by topic
- **Trending Bookmarks**: Algorithm-based popular content

### 3. Organization Features

#### Collections
- User-created folders for bookmark organization
- Support for hierarchical structure
- Pin important collections

#### Lists
Curated bookmark collections as separate records with three distinct types:

1. **Private Lists**: Personal collections visible only to owner
2. **Collaborative Lists**: Shared collections with specific user access
3. **Public Lists**: Discoverable collections that anyone can follow

Each list includes:
- Name and description
- Cover image
- Bookmark references (URIs)
- Permission settings
- Follower/subscriber counts

#### Collaborative Features
- **Verified Contributors**: Specific users can add to collaborative lists
- **Ownership Model**: Original creator maintains control over permissions
- **Suggestion System**: Public lists accept bookmark suggestions via replies
- **Access Control**: AppView enforces permissions, server indexer validates

### 4. Import/Export

#### Supported Formats
- Netscape Bookmarks HTML (standard browser format)
- JSON export with full metadata
- AT Protocol backup format

#### Metadata Enrichment
- Automatic title/description extraction
- Open Graph image fetching
- Preview image generation (max 500KB)

## List Management

### List Types

1. **Private Lists**
   - `visibility: "private"`
   - Only owner can view and modify
   - Personal bookmark organization

2. **Collaborative Lists**
   - `visibility: "collaborative"`
   - Specific users can view and contribute
   - Team resource management
   - Owner manages permissions

3. **Public Lists**
   - `visibility: "public"`
   - Anyone can view and follow
   - Only owner can add bookmarks
   - Suggestions accepted via replies

### Permission Model
- AppView enforces permissions during operations
- Server indexer validates contributions when building feeds
- Owner (original record creator) maintains control
- No ownership transfer in AT Protocol (architectural limitation)

### Suggestion System
- Users reply to public lists with bookmark suggestions
- Suggestions include embedded bookmark reference
- List owner reviews and adds approved suggestions

## Technical Architecture

### Lexicon Structure

The system uses the `app.hyper-limit` namespace with the following lexicons:

#### app.hyper-limit.bookmark
The core bookmark record type containing all bookmark data fields, including references to lists.

#### app.hyper-limit.bookmark.list
Unified organizational structure serving as folders, collaborative spaces, and public collections. Bookmarks reference lists via URIs rather than lists maintaining bookmark arrays.

#### app.hyper-limit.bookmark.embed
Custom embed type for rich bookmark previews in posts.

### Data Storage

#### Blob Storage
- Preview images stored as AT Protocol blobs
- Maximum size: 500KB per image
- Automatic compression and optimization

#### Record Storage
- Each bookmark is an independent record
- Updates create new revisions
- No direct access to history

#### Privacy Implementation
- When `encrypted: true`, sensitive fields contain encrypted strings
- Client-side encryption/decryption with device keys
- Non-encrypted fields remain readable for metadata

### Integration Points

#### Bluesky/AT Protocol
- Standard like/reply/repost mechanisms
- Custom embeds for bookmark quotes
- Graph following for users and collections

#### Jetstream Integration
- Real-time indexing of public bookmarks
- Server-side filtering by collection
- Cursor-based resumption

## Implementation Phases

### Phase 1: Core Functionality
- Basic bookmark CRUD operations
- Simple folder organization
- Import/export functionality

### Phase 2: Social Features
- Public/private bookmarks
- Likes and comments
- User following

### Phase 3: Advanced Features
- Encrypted bookmarks
- Collaborative folders
- Curated lists

### Phase 4: Discovery
- Search functionality
- Trending algorithms
- Tag-based feeds

## Success Metrics

- User adoption rate
- Number of bookmarks created
- Social interaction rates
- Import success rate from other platforms
- API response times
- User retention

## Future Considerations

### Potential Enhancements
- Browser extensions
- Mobile applications  
- API for third-party integration
- Advanced search with filters
- AI-powered recommendations
- Archived content preservation

### Scalability Considerations
- Efficient indexing strategies
- CDN integration for images
- Rate limiting policies
- Backup and recovery procedures

## Lexicon JSON Schemas

### app.hyper-limit.bookmark

```json
{
  "lexicon": 1,
  "id": "app.hyper-limit.bookmark",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["url", "title", "createdAt"],
        "properties": {
          "url": { 
            "type": "string", 
            "format": "uri",
            "maxLength": 2048,
            "description": "The web URL being bookmarked"
          },
          "title": { 
            "type": "string",
            "maxLength": 300 
          },
          "description": { 
            "type": "string",
            "maxLength": 1000 
          },
          "note": { 
            "type": "string",
            "maxLength": 10000 
          },
          "imageUrl": { 
            "type": "string",
            "format": "uri" 
          },
          "imageBlob": {
            "type": "blob",
            "accept": ["image/*"],
            "maxSize": 500000
          },
          "tags": { 
            "type": "array",
            "maxLength": 20,
            "items": { 
              "type": "string",
              "maxLength": 50 
            }
          },
          "listUris": { 
            "type": "array",
            "maxLength": 10,
            "items": { 
              "type": "string",
              "format": "at-uri"
            },
            "description": "References to lists this bookmark belongs to"
          },
          "pinned": { 
            "type": "boolean",
            "default": false 
          },
          "archived": { 
            "type": "boolean",
            "default": false 
          },
          "reminder": {
            "type": "object",
            "properties": {
              "date": { "type": "string", "format": "datetime" },
              "note": { "type": "string", "maxLength": 500 }
            }
          },
          "sourceUri": {
            "type": "string",
            "format": "at-uri",
            "description": "Reference if bookmark was saved from another user"
          },
          "encrypted": {
            "type": "boolean",
            "default": false
          },
          "createdAt": { 
            "type": "string",
            "format": "datetime" 
          },
          "updatedAt": { 
            "type": "string",
            "format": "datetime" 
          }
        }
      }
    }
  }
}
```

### app.hyper-limit.bookmark.list

```json
{
  "lexicon": 1,
  "id": "app.hyper-limit.bookmark.list",
  "defs": {
    "main": {
      "type": "record", 
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["name", "visibility", "createdAt"],
        "properties": {
          "name": {
            "type": "string",
            "maxLength": 100
          },
          "description": {
            "type": "string",
            "maxLength": 1000
          },
          "color": {
            "type": "string",
            "pattern": "^#[0-9A-Fa-f]{6}$",
            "description": "Hex color code for visual organization"
          },
          "icon": {
            "type": "string",
            "knownValues": ["folder", "list", "star", "tag"],
            "default": "folder"
          },
          "coverImage": {
            "type": "blob",
            "accept": ["image/*"],
            "maxSize": 1000000
          },
          "parent": {
            "type": "string",
            "format": "at-uri",
            "description": "Reference to parent list for hierarchy"
          },
          "visibility": {
            "type": "string",
            "knownValues": ["private", "collaborative", "public"],
            "description": "private: owner only, collaborative: specific users, public: anyone can view"
          },
          "permissions": {
            "type": "object",
            "properties": {
              "canAdd": {
                "type": "array",
                "items": { "type": "string", "format": "did" },
                "description": "DIDs that can add bookmarks to this list"
              }
            }
          },
          "createdAt": {
            "type": "string",
            "format": "datetime"
          },
          "updatedAt": {
            "type": "string",
            "format": "datetime"
          }
        }
      }
    }
  }
}
```

### app.hyper-limit.bookmark.embed

```json
{
  "lexicon": 1,
  "id": "app.hyper-limit.bookmark.embed",
  "defs": {
    "main": {
      "type": "object",
      "required": ["bookmark"],
      "properties": {
        "bookmark": {
          "type": "ref",
          "ref": "com.atproto.repo.strongRef",
          "description": "Strong reference containing URI and CID of the bookmark"
        }
      }
    }
  }
}
```

The `strongRef` type includes:
- `uri`: The AT Protocol URI of the bookmark (e.g., `at://did:plc:user/app.hyper-limit.bookmark/tid`)
- `cid`: Content identifier ensuring the embed references a specific version of the bookmark

## Conclusion

This bookmark system will provide users with a powerful, decentralized alternative to traditional bookmark managers while leveraging the social and collaborative features of the AT Protocol ecosystem. The phased approach allows for iterative development and user feedback incorporation.