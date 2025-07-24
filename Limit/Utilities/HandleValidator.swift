//
//  HandleValidator.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import Foundation
import ATProtoKit

// MARK: - Handle Validation and DID Resolution

@MainActor
class HandleValidator: ObservableObject {
    
    // Instance ATProtoKit
    private let atProtoKit: ATProtoKit?
    
    init(atProtoKit: ATProtoKit?) {
        self.atProtoKit = atProtoKit
    }
    
    // MARK: - Main validation and DID conversion
    
    /// Validates handle and converts to DID
    /// - Parameter handle: Handle to validate (e.g. "user.bsky.social")
    /// - Returns: DID if handle is valid and exists
    /// - Throws: Error if handle is invalid or doesn't exist
    func validateHandleAndGetDID(_ handle: String) async throws -> String {
        guard let atProtoKit = atProtoKit else {
            throw HandleValidationError.notAuthenticated
        }
        
        // 1. Check basic handle validity
        guard isValidHandleFormat(handle) else {
            throw HandleValidationError.invalidFormat
        }
        
        // 2. Normalize handle (convert to lowercase, trim whitespace)
        let normalizedHandle = handle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 3. Try to resolve handle to DID using ATProtoKit
        do {
            let resolvedHandle = try await atProtoKit.resolveHandle(from: normalizedHandle)
            return resolvedHandle.did
        } catch {
            // Handle doesn't exist or can't be resolved
            throw HandleValidationError.handleNotFound
        }
    }
    
    // MARK: - Helper functions
    
    /// Check only handle format validity (without existence verification)
    /// - Parameter handle: Handle to validate
    /// - Returns: true if handle has valid format
    func isValidHandleFormat(_ handle: String) -> Bool {
        // Basic handle validation:
        // - Must have at least one dot
        // - No leading/trailing dots
        // - No consecutive dots
        // - Only alphanumeric, hyphen, and dots allowed
        // - Each segment between dots must be non-empty
        
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic checks
        guard !trimmed.isEmpty,
              trimmed.contains("."),
              !trimmed.hasPrefix("."),
              !trimmed.hasSuffix("."),
              !trimmed.contains("..") else {
            return false
        }
        
        // Check allowed characters
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        guard trimmed.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return false
        }
        
        // Check segments
        let segments = trimmed.split(separator: ".")
        return segments.count >= 2 && segments.allSatisfy { !$0.isEmpty }
    }
    
    // MARK: - Typeahead / Autocomplete functions
    
    /// Get handle suggestions based on prefix
    /// - Parameters:
    ///   - prefix: Beginning of handle (e.g. "ali" for "alice.bsky.social")
    ///   - limit: Maximum number of suggestions (default 10, max 100)
    /// - Returns: Array of handle suggestions
    func getSuggestedHandles(for prefix: String, limit: Int = 10) async throws -> [HandleSuggestion] {
        guard let atProtoKit = atProtoKit else {
            throw HandleValidationError.notAuthenticated
        }
        
        // Validate limit
        let validatedLimit = min(max(1, limit), 100)
        
        do {
            // Use searchActorsTypeahead for suggestions
            let searchResult = try await atProtoKit.searchActorsTypeahead(
                matching: prefix,
                limit: validatedLimit
            )
            
            // Convert results to handle suggestions
            return searchResult.actors.map { actor in
                HandleSuggestion(
                    did: actor.actorDID,
                    handle: actor.actorHandle,
                    displayName: actor.displayName,
                    avatarURL: actor.avatarImageURL?.absoluteString
                )
            }
        } catch {
            throw HandleValidationError.searchFailed
        }
    }
    
    /// Get handle suggestions with more details using standard search
    /// - Parameters:
    ///   - query: Search text
    ///   - limit: Maximum number of suggestions (default 25, max 100)
    /// - Returns: Array of detailed handle suggestions
    func searchHandles(matching query: String, limit: Int = 25) async throws -> [DetailedHandleSuggestion] {
        guard let atProtoKit = atProtoKit else {
            throw HandleValidationError.notAuthenticated
        }
        
        // Validate limit
        let validatedLimit = min(max(1, limit), 100)
        
        do {
            // Use searchActors for more detailed search
            let searchResult = try await atProtoKit.searchActors(
                matching: query,
                limit: validatedLimit
            )
            
            // Convert results to detailed suggestions
            return searchResult.actors.map { actor in
                DetailedHandleSuggestion(
                    did: actor.actorDID,
                    handle: actor.actorHandle,
                    displayName: actor.displayName,
                    description: actor.description,
                    avatarURL: actor.avatarImageURL?.absoluteString,
                    followersCount: 0,
                    followsCount: 0
                )
            }
        } catch {
            throw HandleValidationError.searchFailed
        }
    }
    
    /// Validate multiple handles and convert to DIDs
    /// - Parameter handles: Array of handles to validate
    /// - Returns: Array of DIDs for valid handles
    /// - Throws: Error if any handle is invalid
    func validateHandlesAndGetDIDs(_ handles: [String]) async throws -> [String] {
        var dids: [String] = []
        
        for handle in handles {
            let did = try await validateHandleAndGetDID(handle)
            dids.append(did)
        }
        
        return dids
    }
}

// MARK: - Suggestion Models

/// Basic handle suggestion for typeahead
struct HandleSuggestion {
    let did: String
    let handle: String
    let displayName: String?
    let avatarURL: String?
}

/// Detailed handle suggestion with additional info
struct DetailedHandleSuggestion {
    let did: String
    let handle: String
    let displayName: String?
    let description: String?
    let avatarURL: String?
    let followersCount: Int
    let followsCount: Int
}

// MARK: - Custom Errors

enum HandleValidationError: LocalizedError {
    case invalidFormat
    case handleNotFound
    case notAuthenticated
    case networkError
    case searchFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Handle has invalid format"
        case .handleNotFound:
            return "Handle doesn't exist or can't be resolved"
        case .notAuthenticated:
            return "Not authenticated"
        case .networkError:
            return "Network error while verifying handle"
        case .searchFailed:
            return "Error while searching handles"
        }
    }
}