//
//  BookmarkShareUtils.swift
//  Limit
//
//  Universal link generation for bookmark sharing
//

import Foundation

enum BookmarkShareUtils {
    
    /// Generate a universal link for sharing a bookmark
    /// Format: https://ios.hyper-limit.app/bookmark/{did}/{collection}/{rkey}
    static func generateUniversalLink(for bookmarkURI: String) -> URL? {
        // Parse AT URI: at://did:plc:xyz/app.hyper-limit.bookmark/abc123
        guard bookmarkURI.hasPrefix("at://") else {
            DevLogger.shared.log("BookmarkShareUtils - Invalid AT URI format: \(bookmarkURI)")
            return nil
        }
        
        // Remove at:// prefix
        let uriContent = String(bookmarkURI.dropFirst(5))
        let components = uriContent.split(separator: "/")
        
        guard components.count >= 3 else {
            DevLogger.shared.log("BookmarkShareUtils - Invalid AT URI components: \(bookmarkURI)")
            return nil
        }
        
        let did = String(components[0])
        let collection = String(components[1])
        let rkey = String(components[2])
        
        // Build universal link
        let urlString = "https://ios.hyper-limit.app/bookmark/\(did)/\(collection)/\(rkey)"
        
        DevLogger.shared.log("BookmarkShareUtils - Generated universal link: \(urlString)")
        return URL(string: urlString)
    }
    
    /// Generate a shortened universal link for sharing
    /// Format: https://ios.hyper-limit.app/b/{did}/{collection}/{rkey}
    static func generateShortUniversalLink(for bookmarkURI: String) -> URL? {
        // Parse AT URI: at://did:plc:xyz/app.hyper-limit.bookmark/abc123
        guard bookmarkURI.hasPrefix("at://") else {
            DevLogger.shared.log("BookmarkShareUtils - Invalid AT URI format: \(bookmarkURI)")
            return nil
        }
        
        // Remove at:// prefix
        let uriContent = String(bookmarkURI.dropFirst(5))
        let components = uriContent.split(separator: "/")
        
        guard components.count >= 3 else {
            DevLogger.shared.log("BookmarkShareUtils - Invalid AT URI components: \(bookmarkURI)")
            return nil
        }
        
        let did = String(components[0])
        let collection = String(components[1])
        let rkey = String(components[2])
        
        // Build shortened universal link
        let urlString = "https://ios.hyper-limit.app/b/\(did)/\(collection)/\(rkey)"
        
        DevLogger.shared.log("BookmarkShareUtils - Generated short universal link: \(urlString)")
        return URL(string: urlString)
    }
    
    /// Generate a custom scheme deep link (fallback)
    /// Format: limit://bookmark/{did}/{collection}/{rkey}
    static func generateDeepLink(for bookmarkURI: String) -> URL? {
        // Parse AT URI: at://did:plc:xyz/app.hyper-limit.bookmark/abc123
        guard bookmarkURI.hasPrefix("at://") else {
            DevLogger.shared.log("BookmarkShareUtils - Invalid AT URI format: \(bookmarkURI)")
            return nil
        }
        
        // Remove at:// prefix
        let uriContent = String(bookmarkURI.dropFirst(5))
        let components = uriContent.split(separator: "/")
        
        guard components.count >= 3 else {
            DevLogger.shared.log("BookmarkShareUtils - Invalid AT URI components: \(bookmarkURI)")
            return nil
        }
        
        let did = String(components[0])
        let collection = String(components[1])
        let rkey = String(components[2])
        
        // Build deep link
        let urlString = "limit://bookmark/\(did)/\(collection)/\(rkey)"
        
        DevLogger.shared.log("BookmarkShareUtils - Generated deep link: \(urlString)")
        return URL(string: urlString)
    }
    
    /// Generate share text for a bookmark with universal link
    static func generateShareText(
        title: String,
        description: String?,
        universalLink: URL
    ) -> String {
        var shareText = "Check out this bookmark: \(title)"
        
        if let description = description, !description.isEmpty {
            shareText += "\n\n\(description)"
        }
        
        shareText += "\n\n\(universalLink.absoluteString)"
        
        return shareText
    }
}