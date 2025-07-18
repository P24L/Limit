//
//  PostDraft.swift
//  Limit
//
//  Created by Assistant on 17.07.2025.
//

import Foundation
import ATProtoKit

/// Model representing a draft post being composed
struct PostDraft: Identifiable {
    /// Unique identifier for thread management
    let id = UUID()
    
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
}

/// Video attachment details
struct VideoAttachment {
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
}

/// External link preview data
struct ExternalLinkPreview: Equatable {
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
        }
    }
}