# Hyperlimit Links Tracker API Documentation

## Base URL
```
https://hyperlimit-v2-tkobq.ondigitalocean.app
```

## API Endpoints

### 1. Get Trending URLs
Returns the most popular/trending URLs for a specific time period.

**Endpoint:** `GET /api/links/trending/:period`

**Parameters:**
- `period` (path parameter, required): Time period for trending calculation
  - `1h` - Last hour
  - `24h` - Last 24 hours  
  - `3d` - Last 3 days
  - `7d` - Last 7 days
- `limit` (query parameter, optional): Number of results to return
  - Default: 50
  - Min: 1
  - Max: 200

**Response:**
```json
{
  "period": "24h",
  "limit": 50,
  "count": 50,
  "urls": [
    {
      "id": 12345,
      "url": "https://example.com/article",
      "normalized_url": "https://example.com/article",
      "domain": "example.com",
      "post_count": 150,
      "popularity_score": 1250.5,
      "share_count": 150,
      "reply_count": 0,
      "like_count": 230,
      "first_seen": "2025-09-02T10:30:00Z",
      "unique_users": 95,
      "embed_title": "Article Title Here",
      "embed_description": "Description of the article...",
      "embed_thumb_url": "https://example.com/thumb.jpg"
    }
  ]
}
```

**Example Request:**
```
GET /api/links/trending/24h?limit=20
```

### 2. Get URL Details
Returns detailed information about a specific URL.

**Endpoint:** `GET /api/links/url`

**Parameters:**
- `url` (query parameter, required): The URL to look up

**Response:**
```json
{
  "url": {
    "id": 12345,
    "normalized_url": "https://example.com/article",
    "domain": "example.com",
    "first_seen": "2025-09-02T10:30:00Z",
    "last_seen": "2025-09-04T15:45:00Z",
    "total_posts": 150,
    "unique_users": 95,
    "score_1h": 125.5,
    "score_24h": 1250.5,
    "score_3d": 2500.0,
    "score_7d": 3200.0,
    "share_count": 150,
    "reply_count": 0,
    "like_count": 230
  },
  "recent_posts": [
    {
      "post_uri": "at://did:plc:abc123/app.bsky.feed.post/xyz",
      "post_cid": "bafyrei...",
      "created_at": "2025-09-04T15:45:00Z",
      "actor_did": "did:plc:abc123",
      "handle": "user.bsky.social",
      "display_name": "User Name"
    }
  ]
}
```

**Example Request:**
```
GET /api/links/url?url=https://example.com/article
```

### 3. Get Top Domains
Returns domains with the most shared URLs.

**Endpoint:** `GET /api/links/domains/top`

**Parameters:**
- `period` (query parameter, optional): Time period
  - Default: `24h`
  - Options: `1h`, `24h`, `3d`, `7d`
- `limit` (query parameter, optional): Number of results
  - Default: 50

**Response:**
```json
{
  "period": "24h",
  "limit": 50,
  "count": 50,
  "domains": [
    {
      "domain": "example.com",
      "url_count": 25,
      "total_posts": 1500,
      "unique_users": 800,
      "last_seen": "2025-09-04T15:45:00Z"
    }
  ]
}
```

### 4. Get Statistics
Returns overall statistics about the URL tracker.

**Endpoint:** `GET /api/links/stats`

**Response:**
```json
{
  "total_urls": 97000,
  "total_posts": 325000,
  "unique_actors": 45000,
  "urls_24h": 5200,
  "posts_24h": 18500,
  "scorer": {
    "isRunning": true,
    "lastHourlyRun": "2025-09-04T15:00:00Z",
    "lastDailyRun": "2025-09-04T13:56:00Z",
    "nextHourlyRun": "2025-09-04T16:00:00Z",
    "nextDailyRun": "2025-09-05T13:56:00Z",
    "isCalculatingHourly": false,
    "isCalculatingDaily": false
  }
}
```

## Data Model

### URL Object
```typescript
{
  id: number;
  url: string;                    // Same as normalized_url for compatibility
  normalized_url: string;          // Canonical URL format
  domain: string;                  // Domain name
  post_count: number;             // Total number of shares
  popularity_score: number;        // Calculated popularity score
  share_count: number;            // Number of shares (same as post_count)
  reply_count: number;            // Number of replies (always 0 currently)
  like_count: number;             // Total likes across all shares
  first_seen: string;             // ISO 8601 timestamp
  unique_users: number;           // Number of unique users who shared
  embed_title?: string;           // Open Graph title
  embed_description?: string;     // Open Graph description
  embed_thumb_url?: string;       // Open Graph thumbnail URL
}
```

### Scoring Algorithm
Popularity scores are calculated using:
- **Unique users** (weight: 10) - Number of different users sharing the URL
- **Post count** (weight: 2) - Total number of shares
- **Like count** (weight: 0.5) - Total likes on all shares

Formula: `score = (unique_users * 10) + (post_count * 2) + (like_count * 0.5)`

### Time Periods
- **1h**: Real-time trending, updates every hour
- **24h**: Daily trending, good for news cycles
- **3d**: Multi-day trends, captures weekend stories
- **7d**: Weekly overview, long-lasting content

### Rate Limits
- No authentication required
- Reasonable use expected (~10 requests/second)
- Responses are cached for performance

## iOS Implementation Notes

### SwiftUI Example
```swift
struct TrendingURL: Decodable {
    let id: Int
    let url: String
    let domain: String
    let postCount: Int
    let popularityScore: Double
    let embedTitle: String?
    let embedDescription: String?
    let embedThumbUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, url, domain
        case postCount = "post_count"
        case popularityScore = "popularity_score"
        case embedTitle = "embed_title"
        case embedDescription = "embed_description"
        case embedThumbUrl = "embed_thumb_url"
    }
}

func fetchTrending(period: String = "24h") async throws -> [TrendingURL] {
    let url = URL(string: "https://hyperlimit-v2-tkobq.ondigitalocean.app/api/links/trending/\(period)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(TrendingResponse.self, from: data)
    return response.urls
}
```

### Best Practices
1. Cache responses locally for 5-10 minutes
2. Use thumbnails from `embed_thumb_url` for visual appeal
3. Open URLs in SFSafariViewController or default browser
4. Show relative time (e.g., "2 hours ago") using `first_seen`
5. Display `unique_users` as social proof
6. Use different colors/badges for different score ranges

### Error Handling
- 400: Invalid parameters (check period values)
- 404: URL not found (for specific URL lookup)
- 500: Server error (retry with backoff)