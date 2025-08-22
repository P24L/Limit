//
//  NotificationWrapper.swift
//  Limit
//
//  Created by assistant on 2025-07-15.
//

import Foundation
import ATProtoKit

@Observable
@MainActor
final class NotificationWrapper: Identifiable {
    // Primary source - celý notification record
    let notification: AppBskyLexicon.Notification.Notification
    
    // Computed properties for convenience
    nonisolated var id: String { notification.uri }
    var uri: String { notification.uri }
    var cid: String { notification.cid }
    var author: AppBskyLexicon.Actor.ProfileViewDefinition { notification.author }
    var reason: AppBskyLexicon.Notification.Notification.Reason { notification.reason }
    var record: UnknownType? { notification.record }
    var reasonSubjectURI: String? { notification.reasonSubjectURI }
    var isRead: Bool { 
        get { notification.isRead }
        set { /* Note: můžeme implementovat setter později pokud potřebujeme */ }
    }
    var indexedAt: Date { notification.indexedAt }
    
    private var client: MultiAccountClient?
    
    // Pro navigaci na posty
    var linkedPost: TimelinePostWrapper? = nil
    
    init(from notification: AppBskyLexicon.Notification.Notification, client: MultiAccountClient) {
        self.notification = notification
        self.client = client
        
        // Načíst související post podle typu notifikace
        Task {
            await loadLinkedPostForNotificationType()
        }
    }
    
    private func loadLinkedPostForNotificationType() async {
        guard let client = client else { return }
        
        var postURI: String?
        
        switch notification.reason {
        case .like:
            // Dekódovat LikeRecord a načíst post podle subject.recordURI
            postURI = notification.likeRecord?.subject.recordURI
            
        case .repost:
            // Dekódovat RepostRecord a načíst post podle subject.recordURI
            postURI = notification.repostRecord?.subject.recordURI
            
        case .reply, .mention, .quote:
            // Pro tyto typy načíst post přes reasonSubjectURI (váš původní post)
            postURI = notification.reasonSubjectURI
            
        default:
            // Pro follow a ostatní typy nepotřebujeme načítat post
            return
        }
        
        guard let uri = postURI else { return }
        
        let posts = await client.fetchPostWrappersByID(for: [uri])
        self.linkedPost = posts.first
    }
    
    // MARK: - Computed properties pro snadnější přístup
    
    /// Text z PostRecord pro reply/mention/quote notifikace
    var postText: String? {
        return notification.postRecord?.text
    }
    
    var displayText: String {
        switch reason {
        case .like:
            return "liked your post"
        case .repost:
            return "reposted your post"
        case .follow:
            return "followed you"
        case .reply:
            return "replied to your post"
        case .mention:
            return "mentioned you in a post"
        case .quote:
            return "quoted your post"
        case .starterpackjoined:
            return "joined via your starter pack"
        case .verified:
            return "you are now verified"
        case .unverified:
            return "verification removed"
        default:
            return "interacted with you"
        }
    }
    
    /// Detailní popis akce s kontextem
    var detailText: String? {
        switch reason {
        case .reply, .mention, .quote:
            return postText
        case .like, .repost:
            return linkedPost?.text
        default:
            return nil
        }
    }
    
    var timeAgoText: String {
        indexedAt.relativeFormatted
    }
    
    var actionIcon: String {
        switch reason {
        case .like:
            return "heart.fill"
        case .repost:
            return "arrow.2.squarepath"
        case .follow:
            return "person.fill.badge.plus"
        case .reply:
            return "bubble.left.fill"
        case .mention:
            return "at"
        case .quote:
            return "quote.bubble.fill"
        case .starterpackjoined:
            return "person.3.fill"
        case .verified:
            return "checkmark.seal.fill"
        case .unverified:
            return "xmark.seal.fill"
        default:
            return "bell.fill"
        }
    }
}

// MARK: - Extension pro typované recordy
extension AppBskyLexicon.Notification.Notification {
    func getTypedRecord<T: Decodable & ATRecordProtocol>(_ type: T.Type) -> T? {
        return record.getRecord(ofType: type)
    }
    
    var postRecord: AppBskyLexicon.Feed.PostRecord? {
        switch reason {
        case .reply, .mention, .quote:
            return getTypedRecord(AppBskyLexicon.Feed.PostRecord.self)
        default:
            return nil
        }
    }
    
    var likeRecord: AppBskyLexicon.Feed.LikeRecord? {
        switch reason {
        case .like:
            return getTypedRecord(AppBskyLexicon.Feed.LikeRecord.self)
        default:
            return nil
        }
    }
    
    var repostRecord: AppBskyLexicon.Feed.RepostRecord? {
        switch reason {
        case .repost:
            return getTypedRecord(AppBskyLexicon.Feed.RepostRecord.self)
        default:
            return nil
        }
    }
    
    var followRecord: AppBskyLexicon.Graph.FollowRecord? {
        switch reason {
        case .follow:
            return getTypedRecord(AppBskyLexicon.Graph.FollowRecord.self)
        default:
            return nil
        }
    }
}