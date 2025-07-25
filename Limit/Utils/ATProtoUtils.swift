//
//  ATProtoUtils.swift
//  Limit
//
//  Created by Assistant on 25.07.2025.
//

import Foundation

/// Utility functions for AT Protocol operations
enum ATProtoUtils {
    
    /// Components of an AT Protocol URI
    struct URIComponents {
        let repo: String      // Usually a DID
        let collection: String
        let rkey: String      // Record key
        
        /// Full URI reconstruction
        var uri: String {
            "at://\(repo)/\(collection)/\(rkey)"
        }
    }
    
    /// Parse an AT Protocol URI into its components
    /// - Parameter uri: The AT Protocol URI (e.g., "at://did:plc:xyz/app.bsky.feed.post/3k7...")
    /// - Returns: URIComponents if parsing succeeds, nil otherwise
    static func parseURI(_ uri: String) -> URIComponents? {
        // URI format: at://repo/collection/rkey
        let components = uri.split(separator: "/")
        
        guard components.count >= 4,
              components[0] == "at:" else {
            return nil
        }
        
        let repo = String(components[1])
        let collection = String(components[2])
        let rkey = String(components[3])
        
        return URIComponents(repo: repo, collection: collection, rkey: rkey)
    }
    
    /// Extract just repo and rkey from URI (common use case)
    /// - Parameter uri: The AT Protocol URI
    /// - Returns: Tuple of (repo, rkey) if parsing succeeds
    static func extractRepoAndRkey(from uri: String) -> (repo: String, rkey: String)? {
        guard let components = parseURI(uri) else { return nil }
        return (components.repo, components.rkey)
    }
    
    /// Build an AT Protocol URI from components
    /// - Parameters:
    ///   - repo: Repository (usually DID)
    ///   - collection: Collection name (e.g., "app.bsky.feed.post")
    ///   - rkey: Record key
    /// - Returns: Formatted AT Protocol URI
    static func buildURI(repo: String, collection: String, rkey: String) -> String {
        "at://\(repo)/\(collection)/\(rkey)"
    }
    
    /// Validate if a string is a valid AT Protocol URI
    /// - Parameter uri: String to validate
    /// - Returns: true if valid AT Protocol URI format
    static func isValidURI(_ uri: String) -> Bool {
        parseURI(uri) != nil
    }
    
    /// Extract DID from various AT Protocol identifiers
    /// - Parameter identifier: Could be a DID, handle, or AT URI
    /// - Returns: DID if found
    static func extractDID(from identifier: String) -> String? {
        // If it's already a DID
        if identifier.hasPrefix("did:") {
            return identifier
        }
        
        // If it's an AT URI, extract the repo which should be a DID
        if let components = parseURI(identifier) {
            return components.repo.hasPrefix("did:") ? components.repo : nil
        }
        
        // Otherwise, it might be a handle - return nil
        return nil
    }
}

// MARK: - Error Types

enum ATProtoError: LocalizedError {
    case invalidURI(String)
    case networkError(Error)
    case authenticationRequired
    case recordNotFound
    case permissionDenied
    case rateLimitExceeded
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURI(let uri):
            return "Invalid AT Protocol URI: \(uri)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationRequired:
            return "Authentication required"
        case .recordNotFound:
            return "Record not found"
        case .permissionDenied:
            return "Permission denied"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimitExceeded, .serverError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Network Retry Wrapper

extension ATProtoUtils {
    
    /// Execute an async operation with retry logic
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - delay: Initial delay between retries in seconds (default: 1.0)
    ///   - backoffMultiplier: Multiplier for exponential backoff (default: 2.0)
    ///   - operation: The async throwing operation to execute
    /// - Returns: Result of the operation
    static func withRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var currentDelay = delay
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if error is retryable
                let isRetryable: Bool
                if let atError = error as? ATProtoError {
                    isRetryable = atError.isRetryable
                } else {
                    // Default to retry for network-like errors
                    isRetryable = true
                }
                
                if !isRetryable || attempt == maxAttempts {
                    throw error
                }
                
                // Log retry attempt
                DevLogger.shared.log("ATProtoUtils - Retry attempt \(attempt) after error: \(error)")
                
                // Wait before retry with exponential backoff
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                currentDelay *= backoffMultiplier
            }
        }
        
        throw lastError ?? ATProtoError.serverError("Unknown error after \(maxAttempts) attempts")
    }
}