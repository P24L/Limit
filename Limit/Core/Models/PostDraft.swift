//
//  PostDraft.swift
//  Limit
//
//  Created by Assistant on 17.07.2025.
//

import Foundation
import ATProtoKit

/// Model representing a draft post being composed
struct PostDraft: Identifiable, Codable {
    /// Unique identifier for thread management
    var id = UUID()
    
    /// The raw text entered by the user
    var text: String = ""
    
    /// Display text with truncated URLs for UI
    var displayText: String = ""
    
    /// Parsed facets (mentions, hashtags, links) from ATProtoKit
    var facets: [AppBskyLexicon.RichText.Facet] = []
    
    /// Images to attach (max 4, JPEG only)
    var images: [ATProtoTools.ImageQuery] = []
    
    /// Video attachment (max 1, MP4 only, max 100MB)
    var video: VideoAttachment?
    
    /// External link preview (generated from first URL if no media)
    var externalLink: ExternalLinkPreview?
    
    /// Languages for the post (max 3)
    var languages: [Locale] = [Locale(identifier: "cs_CZ")]
    
    /// Reply reference if this is a reply
    var replyTo: AppBskyLexicon.Feed.PostRecord.ReplyReference?
    
    /// Quote post reference if this is a quote post
    var quotedPost: ComAtprotoLexicon.Repository.StrongReference?
    
    /// Additional posts for thread creation
    var threadPosts: [PostDraft] = []
    
    /// Computed character count (grapheme clusters, not bytes)
    var characterCount: Int {
        text.count
    }
    
    /// Remaining characters (max 300)
    var remainingCharacters: Int {
        300 - characterCount
    }
    
    /// Check if post is valid for submission
    var isValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= 300 &&
        images.count <= 4
    }
    
    // MARK: - Initialization
    init() {
        // Default initializer
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, text, displayText, languages, threadPosts
        case externalLink, video
        // Note: facets, images, replyTo, and quotedPost are not persisted
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        displayText = try container.decode(String.self, forKey: .displayText)
        languages = try container.decode([Locale].self, forKey: .languages)
        threadPosts = try container.decode([PostDraft].self, forKey: .threadPosts)
        externalLink = try container.decodeIfPresent(ExternalLinkPreview.self, forKey: .externalLink)
        video = try container.decodeIfPresent(VideoAttachment.self, forKey: .video)
        
        // Initialize non-persisted properties
        facets = []
        images = []
        replyTo = nil
        quotedPost = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(displayText, forKey: .displayText)
        try container.encode(languages, forKey: .languages)
        try container.encode(threadPosts, forKey: .threadPosts)
        try container.encodeIfPresent(externalLink, forKey: .externalLink)
        try container.encodeIfPresent(video, forKey: .video)
        // Note: We don't encode facets, images, or replyTo as they need to be regenerated
    }
}

/// Video attachment details
struct VideoAttachment: Codable {
    let data: Data
    let captions: [ATProtoBluesky.Caption]?
    let altText: String?
    let aspectRatio: AppBskyLexicon.Embed.AspectRatioDefinition?
    
    /// Video file size in MB
    var sizeInMB: Double {
        Double(data.count) / (1024 * 1024)
    }
    
    /// Check if video size is within limits
    var isWithinSizeLimit: Bool {
        sizeInMB <= 100
    }
    
    init(data: Data, captions: [ATProtoBluesky.Caption]?, altText: String?, aspectRatio: AppBskyLexicon.Embed.AspectRatioDefinition?) {
        self.data = data
        self.captions = captions
        self.altText = altText
        self.aspectRatio = aspectRatio
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case data, altText
        // Note: captions and aspectRatio are not persisted
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(Data.self, forKey: .data)
        altText = try container.decodeIfPresent(String.self, forKey: .altText)
        
        // Initialize non-persisted properties
        captions = nil
        aspectRatio = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encodeIfPresent(altText, forKey: .altText)
        // Note: We don't encode captions or aspectRatio
    }
}

/// External link preview data
struct ExternalLinkPreview: Equatable, Codable {
    let url: URL
    let title: String
    let description: String?
    let thumbnailURL: URL?
    
    static func == (lhs: ExternalLinkPreview, rhs: ExternalLinkPreview) -> Bool {
        lhs.url == rhs.url
    }
}

/// Errors related to post composition
enum PostComposerError: LocalizedError {
    case textTooLong(count: Int)
    case tooManyImages(count: Int)
    case videoTooLarge(sizeMB: Double)
    case invalidImageFormat
    case noContent
    case networkError(Error)
    case uploadFailed(reason: String)
    case notAuthenticated
    case imageUploadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .textTooLong(let count):
            return "Text is too long (\(count) characters, max 300)"
        case .tooManyImages(let count):
            return "Too many images (\(count), max 4)"
        case .videoTooLarge(let sizeMB):
            return "Video is too large (\(String(format: "%.1f", sizeMB))MB, max 100MB)"
        case .invalidImageFormat:
            return "Only JPEG images are supported"
        case .noContent:
            return "Post cannot be empty"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .notAuthenticated:
            return "Not authenticated"
        case .imageUploadFailed(let error):
            return "Image upload failed: \(error.localizedDescription)"
        }
    }
}