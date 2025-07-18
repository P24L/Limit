//
//  String+ByteOffset.swift
//  Limit
//
//  Created by Assistant on 17.07.2025.
//

import Foundation

extension String {
    /// Converts a character index to UTF-8 byte offset
    /// - Parameter characterIndex: The character position in the string
    /// - Returns: The corresponding byte offset
    func byteOffset(at characterIndex: Int) -> Int {
        guard characterIndex >= 0 else { return 0 }
        guard characterIndex <= count else { return utf8.count }
        
        let prefix = self.prefix(characterIndex)
        return prefix.utf8.count
    }
    
    /// Converts a UTF-8 byte offset to character index
    /// - Parameter byteOffset: The byte position in UTF-8 encoding
    /// - Returns: The corresponding character index, or nil if invalid
    func characterIndex(at byteOffset: Int) -> Int? {
        guard byteOffset >= 0 else { return nil }
        
        var currentByte = 0
        var currentIndex = 0
        
        for char in self {
            if currentByte >= byteOffset { 
                return currentIndex 
            }
            currentByte += char.utf8.count
            currentIndex += 1
        }
        
        return currentByte == byteOffset ? currentIndex : nil
    }
    
    /// Creates a substring using byte offsets
    /// - Parameters:
    ///   - startByte: Starting byte offset
    ///   - endByte: Ending byte offset
    /// - Returns: The substring, or nil if offsets are invalid
    func substring(fromByte startByte: Int, toByte endByte: Int) -> String? {
        guard let startIndex = characterIndex(at: startByte),
              let endIndex = characterIndex(at: endByte),
              startIndex <= endIndex else {
            return nil
        }
        
        let start = index(self.startIndex, offsetBy: startIndex)
        let end = index(self.startIndex, offsetBy: endIndex)
        
        guard start <= end, end <= self.endIndex else {
            return nil
        }
        
        return String(self[start..<end])
    }
    
    /// Validates if given byte range is valid for this string
    /// - Parameters:
    ///   - startByte: Starting byte offset
    ///   - endByte: Ending byte offset
    /// - Returns: True if the byte range is valid
    func isValidByteRange(start startByte: Int, end endByte: Int) -> Bool {
        return startByte >= 0 && 
               endByte <= utf8.count && 
               startByte <= endByte &&
               characterIndex(at: startByte) != nil &&
               characterIndex(at: endByte) != nil
    }
}

// MARK: - AttributedString Helpers
import SwiftUI

extension AttributedString {
    /// Moves an index by a specified number of characters
    /// - Parameters:
    ///   - base: The starting index
    ///   - offset: Number of characters to move
    /// - Returns: The new index
    func index(_ base: AttributedString.Index, offsetByCharacters offset: Int) -> AttributedString.Index {
        var currentIndex = base
        var currentOffset = 0
        
        if offset > 0 {
            while currentOffset < offset && currentIndex < endIndex {
                currentIndex = self.characters.index(after: currentIndex)
                currentOffset += 1
            }
        } else if offset < 0 {
            let absOffset = abs(offset)
            while currentOffset < absOffset && currentIndex > startIndex {
                currentIndex = self.characters.index(before: currentIndex)
                currentOffset += 1
            }
        }
        
        return currentIndex
    }
    
    /// Safely gets a range from character indices
    /// - Parameters:
    ///   - startOffset: Starting character offset
    ///   - endOffset: Ending character offset
    /// - Returns: The range, or nil if invalid
    func safeRange(from startOffset: Int, to endOffset: Int) -> Range<AttributedString.Index>? {
        guard startOffset >= 0, endOffset >= startOffset else { return nil }
        
        let start = index(startIndex, offsetByCharacters: startOffset)
        let end = index(startIndex, offsetByCharacters: endOffset)
        
        guard start >= startIndex, 
              end <= endIndex, 
              start < end else { 
            return nil 
        }
        
        return start..<end
    }
}