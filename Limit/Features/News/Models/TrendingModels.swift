//
//  TrendingModels.swift
//  Limit
//
//  Created by Claude
//

import Foundation

// MARK: - Trending Period
enum TrendingPeriod: String, CaseIterable {
    case oneHour = "1h"
    case twentyFourHours = "24h"
    case threeDays = "3d"
    case sevenDays = "7d"
    
    var displayName: String {
        switch self {
        case .oneHour: return "1H"
        case .twentyFourHours: return "24H"
        case .threeDays: return "3D"
        case .sevenDays: return "7D"
        }
    }
}

// MARK: - Period Navigation
extension TrendingPeriod {
    static var ordered: [TrendingPeriod] { [.oneHour, .twentyFourHours, .threeDays, .sevenDays] }
    
    var next: TrendingPeriod? {
        guard let idx = Self.ordered.firstIndex(of: self), idx + 1 < Self.ordered.count else { return nil }
        return Self.ordered[idx + 1]
    }
    
    var previous: TrendingPeriod? {
        guard let idx = Self.ordered.firstIndex(of: self), idx - 1 >= 0 else { return nil }
        return Self.ordered[idx - 1]
    }
}

// MARK: - Language Models
struct Language: Decodable, Identifiable {
    let lang: String
    let label: String
    
    var id: String { lang }
}

struct LanguagesResponse: Decodable {
    let count: Int
    let languages: [Language]
}

// MARK: - API Response Models
struct TrendingResponse: Decodable {
    let period: String
    let limit: Int
    let count: Int
    let lang: String?  // Optional language filter
    let urls: [TrendingURL]
}

struct TrendingURL: Decodable, Identifiable {
    let url: String
    let normalizedUrl: String
    let domain: String
    let postCount: Int
    let popularityScore: String  // API returns as string
    let shareCount: Int
    let replyCount: Int
    let likeCount: Int
    let firstSeen: String
    let uniqueUsers: String  // Currently string, will be int after API migration
    let embedTitle: String?
    let embedDescription: String?
    let embedThumbUrl: String?
    
    // Computed ID for Identifiable
    var id: String { normalizedUrl }
    
    enum CodingKeys: String, CodingKey {
        case url, domain
        case normalizedUrl = "normalized_url"
        case postCount = "post_count"
        case popularityScore = "popularity_score"
        case shareCount = "share_count"
        case replyCount = "reply_count"
        case likeCount = "like_count"
        case firstSeen = "first_seen"
        case uniqueUsers = "unique_users"
        case embedTitle = "embed_title"
        case embedDescription = "embed_description"
        case embedThumbUrl = "embed_thumb_url"
    }
    
    // Custom decoder to handle both string and int for uniqueUsers
    // TODO: After API fully migrated to int types (target: v1.15+):
    // 1. Change uniqueUsers from String to Int
    // 2. Remove this custom decoder
    // 3. Remove computed property uniqueUsersCount (use uniqueUsers directly)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        url = try container.decode(String.self, forKey: .url)
        normalizedUrl = try container.decode(String.self, forKey: .normalizedUrl)
        domain = try container.decode(String.self, forKey: .domain)
        postCount = try container.decode(Int.self, forKey: .postCount)
        popularityScore = try container.decode(String.self, forKey: .popularityScore)
        shareCount = try container.decode(Int.self, forKey: .shareCount)
        replyCount = try container.decode(Int.self, forKey: .replyCount)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        firstSeen = try container.decode(String.self, forKey: .firstSeen)
        
        // TODO: After API migration to int (v1.15+), simplify to direct Int decoding
        // Flexible decoding for uniqueUsers - handles both string and int
        if let intValue = try? container.decode(Int.self, forKey: .uniqueUsers) {
            uniqueUsers = String(intValue)  // Convert int to string for backward compatibility
        } else {
            uniqueUsers = try container.decode(String.self, forKey: .uniqueUsers)
        }
        
        embedTitle = try container.decodeIfPresent(String.self, forKey: .embedTitle)
        embedDescription = try container.decodeIfPresent(String.self, forKey: .embedDescription)
        embedThumbUrl = try container.decodeIfPresent(String.self, forKey: .embedThumbUrl)
    }
    
    // Computed properties for numeric values
    var uniqueUsersCount: Int {
        Int(uniqueUsers) ?? 0
    }
    
    var popularityScoreValue: Double {
        Double(popularityScore) ?? 0.0
    }
    
    // Computed properties for UI
    var firstSeenDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: firstSeen)
    }
    
    var relativeTime: String {
        guard let date = firstSeenDate else { return "" }
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - URL Detail Response
struct URLDetailResponse: Decodable {
    let url: URLDetail
    let recentPosts: [RecentPost]
    
    enum CodingKeys: String, CodingKey {
        case url
        case recentPosts = "recent_posts"
    }
}

struct URLDetail: Decodable {
    let id: Int
    let normalizedUrl: String
    let domain: String
    let firstSeen: String
    let lastSeen: String
    let totalPosts: Int
    let uniqueUsers: String  // API returns as string
    let score1h: String?     // API returns as string
    let score24h: String?    // API returns as string
    let score3d: String?     // API returns as string
    let score7d: String?     // API returns as string
    let shareCount: Int
    let replyCount: Int
    let likeCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, domain
        case normalizedUrl = "normalized_url"
        case firstSeen = "first_seen"
        case lastSeen = "last_seen"
        case totalPosts = "total_posts"
        case uniqueUsers = "unique_users"
        case score1h = "score_1h"
        case score24h = "score_24h"
        case score3d = "score_3d"
        case score7d = "score_7d"
        case shareCount = "share_count"
        case replyCount = "reply_count"
        case likeCount = "like_count"
    }
    
    // Computed properties for numeric values
    var uniqueUsersCount: Int {
        Int(uniqueUsers) ?? 0
    }
}

struct RecentPost: Decodable, Identifiable {
    let postUri: String
    let postCid: String
    let createdAt: String
    let actorDid: String?    // Can be null in API
    
    var id: String { postUri }
    
    enum CodingKeys: String, CodingKey {
        case postUri = "post_uri"
        case postCid = "post_cid"
        case createdAt = "created_at"
        case actorDid = "actor_did"
    }
}
