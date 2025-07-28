//
//  MentionAutocompleteManager.swift
//  Limit
//
//  Created by Assistant on 28.07.2025.
//

import Foundation
import SwiftUI
import ATProtoKit
import Observation

@Observable
class MentionAutocompleteManager {
    // MARK: - Properties
    
    // Current mention being typed
    var currentMention: CurrentMention?
    
    // Suggestions from API
    var suggestions: [HandleSuggestion] = []
    
    // Loading state
    var isLoadingSuggestions = false
    
    // Cursor frame for positioning suggestions
    var cursorFrame: CGRect = .zero
    
    // Search task for cancellation
    private var searchTask: Task<Void, Never>?
    
    // Handle validator instance
    private weak var handleValidator: HandleValidator?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Configuration
    
    func configure(with handleValidator: HandleValidator) {
        self.handleValidator = handleValidator
    }
    
    // MARK: - Mention Detection
    
    /// Detects if user is typing a mention at current cursor position
    func detectMention(in text: String, cursorPosition: Int) -> CurrentMention? {
        // Don't detect if cursor is at the very beginning
        guard cursorPosition > 0 else { return nil }
        
        // Look backwards from cursor to find @ symbol
        let textBeforeCursor = String(text.prefix(cursorPosition))
        
        // Find the last @ symbol before cursor
        guard let lastAtIndex = textBeforeCursor.lastIndex(of: "@") else { return nil }
        
        // Get the text after @ up to cursor
        let mentionStartOffset = textBeforeCursor.distance(from: textBeforeCursor.startIndex, to: lastAtIndex)
        let textAfterAt = String(textBeforeCursor[textBeforeCursor.index(after: lastAtIndex)...])
        
        // Check if this looks like a mention in progress
        // Allow alphanumeric, dots, hyphens (valid handle characters)
        let mentionPattern = "^[a-zA-Z0-9.-]*$"
        guard textAfterAt.range(of: mentionPattern, options: .regularExpression) != nil else {
            return nil
        }
        
        // Check if @ is preceded by whitespace, newline, or is at start
        if mentionStartOffset > 0 {
            let charBeforeAt = textBeforeCursor[textBeforeCursor.index(lastAtIndex, offsetBy: -1)]
            guard charBeforeAt.isWhitespace || charBeforeAt.isNewline else {
                return nil
            }
        }
        
        let mention = CurrentMention(
            range: mentionStartOffset..<cursorPosition,
            text: textAfterAt,
            fullText: "@" + textAfterAt
        )
        
        return mention
    }
    
    // MARK: - Suggestions Management
    
    /// Updates current mention and triggers search if needed
    func updateMention(in text: String, cursorPosition: Int, textViewBounds: CGRect) {
        let detectedMention = detectMention(in: text, cursorPosition: cursorPosition)
        
        // Clear suggestions if no mention detected
        guard let mention = detectedMention else {
            clearMention()
            return
        }
        
        // Update current mention
        currentMention = mention
        
        // Only search if we have at least 2 characters after @
        guard mention.text.count >= 2 else {
            suggestions = []
            return
        }
        
        // Cancel previous search
        searchTask?.cancel()
        
        // Start new search with debounce
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            guard !Task.isCancelled else { return }
            await self?.searchForSuggestions(prefix: mention.text)
        }
    }
    
    /// Searches for handle suggestions
    @MainActor
    private func searchForSuggestions(prefix: String) async {
        guard let validator = handleValidator else { return }
        
        isLoadingSuggestions = true
        
        do {
            let results = try await validator.getSuggestedHandles(for: prefix, limit: 5)
            
            // Only update if this is still the current search
            if currentMention?.text == prefix {
                suggestions = results
            }
        } catch {
            suggestions = []
        }
        
        isLoadingSuggestions = false
    }
    
    // MARK: - Selection Handling
    
    /// Builds the replacement text for a selected mention
    func buildReplacementText(for suggestion: HandleSuggestion, originalText: String) -> (text: String, newCursorPosition: Int)? {
        guard let mention = currentMention else { return nil }
        
        // Build the new text with the selected handle
        let beforeMention = String(originalText.prefix(mention.range.lowerBound))
        let afterMention = String(originalText.suffix(from: originalText.index(originalText.startIndex, offsetBy: mention.range.upperBound)))
        
        // Insert @handle with a space after
        let replacementText = "@\(suggestion.handle) "
        let newText = beforeMention + replacementText + afterMention
        
        // Calculate new cursor position (after the space)
        let newCursorPosition = mention.range.lowerBound + replacementText.count
        
        return (text: newText, newCursorPosition: newCursorPosition)
    }
    
    // MARK: - Utilities
    
    /// Clears current mention and suggestions
    func clearMention() {
        currentMention = nil
        suggestions = []
        searchTask?.cancel()
    }
    
    /// Updates cursor frame for positioning suggestions
    func updateCursorFrame(_ frame: CGRect) {
        cursorFrame = frame
    }
}

// MARK: - Supporting Types

struct CurrentMention {
    let range: Range<Int>
    let text: String // Text after @ (e.g., "alic")
    let fullText: String // Full text including @ (e.g., "@alic")
    
    var isValid: Bool {
        return text.count >= 2
    }
}