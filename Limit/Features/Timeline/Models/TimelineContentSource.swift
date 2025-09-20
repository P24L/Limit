//
//  TimelineContentSource.swift
//  Limit
//
//  Created by Zdenek Indra on 11.07.2025.
//

import ATProtoKit

enum TimelineContentSource: Hashable {
    case list(AppBskyLexicon.Graph.ListViewDefinition)
    case feed(AppBskyLexicon.Feed.GeneratorViewDefinition)
    case feedUri(String, String)
    case trendingFeed(String, String)
    case trendingPosts

    func hash(into hasher: inout Hasher) {
        switch self {
        case .list(let list):
            hasher.combine("list")
            hasher.combine(list.uri)
        case .feed(let feed):
            hasher.combine("feed")
            hasher.combine(feed.feedURI)
        case .feedUri(let uri, let displayName):
            hasher.combine("feedUri")
            hasher.combine(uri)
            hasher.combine(displayName)
        case .trendingFeed(let link, let displayName):
            hasher.combine("trendingFeed")
            hasher.combine(link)
            hasher.combine(displayName)
        case .trendingPosts:
            hasher.combine("trendingPosts")
        }
    }

    static func == (lhs: TimelineContentSource, rhs: TimelineContentSource) -> Bool {
        switch (lhs, rhs) {
        case (.list(let lhsList), .list(let rhsList)):
            return lhsList.uri == rhsList.uri
        case (.feed(let lhsFeed), .feed(let rhsFeed)):
            return lhsFeed.feedURI == rhsFeed.feedURI
        case (.feedUri(let lhsUri, let lhsName), .feedUri(let rhsUri, let rhsName)):
            return lhsUri == rhsUri && lhsName == rhsName
        case (.trendingFeed(let lhsLink, let lhsName), .trendingFeed(let rhsLink, let rhsName)):
            return lhsLink == rhsLink && lhsName == rhsName
        case (.trendingPosts, .trendingPosts):
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .list(let list): return list.name
        case .feed(let feed): return feed.displayName
        case .feedUri(_, let displayName): return displayName
        case .trendingFeed(_, let displayName): return displayName
        case .trendingPosts: return "trendingPosts"
        }
    }

    var uri: String {
        switch self {
        case .list(let list): return list.uri
        case .feed(let feed): return feed.feedURI
        case .feedUri(let uri, _): return uri
        case .trendingFeed(let link, _): return link
        case .trendingPosts: return ""
        }
    }

    var sourceType: String {
        switch self {
        case .list: return "list"
        case .feed: return "feed"
        case .feedUri: return "feed"
        case .trendingFeed: return "trendingFeed"
        case .trendingPosts: return "trendingPosts"
        }
    }

    var identifier: String {
        "\(sourceType)::\(uri)"
    }
}
