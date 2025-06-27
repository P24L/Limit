//
//  TimelinePost.swift
//  Limit
//
//  Created by Zdenek Indra on 18.05.2025.
//

import ATProtoKit
import Foundation
import SwiftData
import SwiftUI

// MARK: Hlavní model

@Model
final class TimelinePost: Identifiable {
    @Attribute(.unique) var id: String //uri/cid
    var uri: String
    var cid: String
    var createdAt: Date
    var type: TimelinePostType
    var authorID: String
    var authorHandle: String
    var authorDisplayName: String?
    var authorAvatarURL: URL?
    var text: String
    
    @Relationship(deleteRule: .cascade) var embeds: [PostImage] = []
    var likeCount: Int
    var replyCount: Int
    var repostCount: Int
    var quoteCount: Int
    
    @Relationship(deleteRule: .cascade)
    var quotedPost: TimelinePost?
    
    @Relationship(deleteRule: .cascade)
    var parentPost: TimelinePost? = nil

    @Relationship(deleteRule: .cascade)
    var rootPost: TimelinePost? = nil
    
    @Relationship(deleteRule: .cascade) var linkExt: PostLinkExt? = nil
    @Relationship(deleteRule: .cascade) var postVideo: PostVideo? = nil
    
    var fetchedWithCursor: String? = nil
    
    var repostedByID: String? = nil
    var repostedByHandle: String? = nil
    var repostedByDisplayName: String? = nil
    var repostedByAvatarURL: URL? = nil

    // Viewer state - interakce přihlášeného uživatele
    var viewerLikeURI: String? = nil
    var viewerRepostURI: String? = nil
    var viewerIsPinned: Bool = false
    var viewerIsThreadMuted: Bool = false
    var viewerAreRepliesDisabled: Bool = false
    var viewerIsEmbeddingDisabled: Bool = false
    
    init(
        id: String,
        uri: String,
        cid: String,
        createdAt: Date,
        type: TimelinePostType = .post,
        authorID: String,
        authorHandle: String,
        authorDisplayName: String? = nil,
        authorAvatarURL: URL? = nil,
        text: String,
        replyTo: TimelinePost? = nil,
        likeCount: Int = 0,
        replyCount: Int = 0,
        repostCount: Int = 0,
        quoteCount: Int = 0,
        quotedPost: TimelinePost? = nil,
        fetchedWithCursor: String? = nil,
        parentPost: TimelinePost? = nil,
        rootPost: TimelinePost? = nil,
        repostedByID: String? = nil,
        repostedByHandle: String? = nil,
        repostedByDisplayName: String? = nil,
        repostedByAvatarURL: URL? = nil,
        viewerLikeURI: String? = nil,
        viewerRepostURI: String? = nil,
        viewerIsPinned: Bool = false,
        viewerIsThreadMuted: Bool = false,
        viewerAreRepliesDisabled: Bool = false,
        viewerIsEmbeddingDisabled: Bool = false
    ) {
        self.id = id
        self.uri = uri
        self.cid = cid
        self.createdAt = createdAt
        self.type = type
        self.authorID = authorID
        self.authorHandle = authorHandle
        self.authorDisplayName = authorDisplayName
        self.authorAvatarURL = authorAvatarURL
        self.text = text
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.repostCount = repostCount
        self.quoteCount = quoteCount
        self.quotedPost = quotedPost
        self.fetchedWithCursor = fetchedWithCursor
        self.parentPost = parentPost
        self.rootPost = rootPost
        self.repostedByID = repostedByID
        self.repostedByHandle = repostedByHandle
        self.repostedByDisplayName = repostedByDisplayName
        self.repostedByAvatarURL = repostedByAvatarURL
        self.viewerLikeURI = viewerLikeURI
        self.viewerRepostURI = viewerRepostURI
        self.viewerIsPinned = viewerIsPinned
        self.viewerIsThreadMuted = viewerIsThreadMuted
        self.viewerAreRepliesDisabled = viewerAreRepliesDisabled
        self.viewerIsEmbeddingDisabled = viewerIsEmbeddingDisabled
    }
}


enum TimelinePostType: String, Codable {
    case post = "post"
    case quoted = "quoted"      // post, který je jen citovaný jiným postem
    case parent = "parent"
    case root = "root"
    case missingGap = "missingGap" //mezera v timeline
    case ad = "ad"  //reklama
    case temporaryThread = "temporaryThread" //posty v threadu, mohou se pak smazat
    //další typy do budoucna - např. threadStart
}

@Model
final class PostImage {
    @Attribute(.unique) var id = UUID()
    //var id: String //buď URL nebo cid
    var url: URL
    var thumbURL: URL?
    var altText: String
    @Relationship(inverse: \TimelinePost.embeds) var timelinePost: TimelinePost?
    
    init(
        id: String,
        url: URL,
        thumbURL: URL? = nil,
        altText: String
    ) {
        //self.id = id
        self.url = url
        self.thumbURL = thumbURL
        self.altText = altText
    }
}

@Model
final class PostLinkExt {
    @Attribute(.unique)  var id = UUID()
    var desc: String
    var thumbnailImageURL: URL?
    var title: String
    var uri: String
    @Relationship(inverse: \TimelinePost.linkExt) var timelinePost: TimelinePost?
    
    init(
        desc: String,
        thumbnailImageURL: URL? = nil,
        title: String,
        uri: String,)
    {
        self.desc = desc
        self.thumbnailImageURL = thumbnailImageURL
        self.title = title
        self.uri = uri
    }
}

@Model
final class PostVideo {
    @Attribute(.unique) var id: String // cid
    var altText: String?
    var playlistURI: String
    var thumbImageURL: String?
    @Relationship(inverse: \TimelinePost.postVideo) var timelinePost: TimelinePost?
    var height: Int?
    var width: Int?
    
    init(
        id: String,
        altText: String? = nil,
        playlistURI: String,
        thumbImageURL: String? = nil,
        height: Int? = nil,
        width: Int? = nil
    ) {
        self.id = id
        self.altText = altText
        self.playlistURI = playlistURI
        self.thumbImageURL = thumbImageURL
        self.height = height
        self.width = width
    }
}
