//
//  BookmarkEditState.swift
//  Limit
//
//  Created by Assistant on 06.01.2025.
//

import Foundation
import SwiftUI
import WebImageExtractor
import ATProtoKit

@Observable
@MainActor
class BookmarkEditState {
    // Basic fields
    var url: String = ""
    var title: String = ""
    var description: String = ""
    var note: String = ""
    var summary: String = ""
    
    // Image
    var imageUrl: String?
    var imageData: Data?
    
    // Tags
    var tags: [String] = []
    var tagInput: String = ""
    
    // Lists
    var selectedLists: Set<String> = []
    var availableLists: [BookmarkListView] = []
    
    // Flags
    var pinned: Bool = false
    var archived: Bool = false
    
    // State
    var isLoading = false
    var isSaving = false
    var isGeneratingAISummary = false
    var error: String?
    
    // Edit mode
    var isEditMode = false
    var originalBookmark: BookmarkView?
    
    // Dependencies
    private var bookmarkManager: BookmarkManager?
    private var client: BlueskyClient?
    
    init() {
        // Clipboard check moved to BookmarkEditSheet to only run for new bookmarks
    }
    
    func setup(bookmarkManager: BookmarkManager, client: BlueskyClient) {
        self.bookmarkManager = bookmarkManager
        self.client = client
        self.availableLists = bookmarkManager.bookmarkLists
    }
    
    func loadBookmark(_ bookmark: BookmarkView) {
        isEditMode = true
        originalBookmark = bookmark
        
        url = bookmark.record.url
        title = bookmark.record.title
        description = bookmark.record.description ?? ""
        note = bookmark.record.note ?? ""
        summary = bookmark.record.summary ?? ""
        imageUrl = bookmark.record.imageUrl
        tags = bookmark.record.tags ?? []
        selectedLists = Set(bookmark.record.listUris ?? [])
        pinned = bookmark.record.pinned ?? false
        archived = bookmark.record.archived ?? false
    }
    
    // MARK: - Clipboard Detection
    
    func checkClipboard() {
        #if !targetEnvironment(simulator)
        if UIPasteboard.general.hasURLs,
           let clipboardURL = UIPasteboard.general.url {
            url = clipboardURL.absoluteString
        } else if UIPasteboard.general.hasStrings,
                  let clipboardString = UIPasteboard.general.string,
                  let detectedURL = URL(string: clipboardString),
                  detectedURL.scheme != nil {
            url = clipboardString
        }
        #endif
    }
    
    // MARK: - Metadata Fetching
    
    func fetchMetadata() async {
        guard !url.isEmpty,
              let urlObject = URL(string: url) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Use WebImageExtractor to fetch both metadata and image efficiently
        let imageExtractor = WebImageExtractor()
        let (metadata, imageResult) = await imageExtractor.fetchMetadataAndImage(for: urlObject)
        
        // Only update if fields are empty (don't overwrite user edits)
        if title.isEmpty {
            title = metadata.title ?? urlObject.host ?? "Untitled"
        }
        if description.isEmpty {
            description = metadata.description ?? ""
        }
        
        // Update image - prefer imageURL over imageData
        if let imageURL = imageResult.imageURL {
            imageUrl = imageURL
            imageData = nil  // Clear blob if we have URL
        } else if let data = imageResult.imageData {
            imageData = data
            imageUrl = nil  // Clear URL if we have blob
        } else if let metadataImageUrl = metadata.imageUrl {
            // Fallback to metadata image URL if no image result
            imageUrl = metadataImageUrl
            imageData = nil
        }
    }
    
    // MARK: - AI Summary
    
    func generateAISummary() async {
        guard !url.isEmpty,
              let urlObject = URL(string: url) else { return }
        
        isGeneratingAISummary = true
        defer { isGeneratingAISummary = false }
        
        // Use AIService for actual summary generation
        do {
            let aiService = AIService()
            let result = try await aiService.summarizeURL(urlObject)
            summary = result.summary
            
            // Also update title if it was empty
            if title.isEmpty, let aiTitle = result.title {
                title = aiTitle
            }
            
            DevLogger.shared.log("BookmarkEditState - AI summary generated successfully")
        } catch {
            DevLogger.shared.log("BookmarkEditState - Failed to generate AI summary: \(error)")
            // Don't show error to user - summary is optional
        }
    }
    
    // MARK: - Save
    
    func save() async throws {
        guard let bookmarkManager = bookmarkManager else {
            throw BookmarkEditError.managerNotConfigured
        }
        
        isSaving = true
        defer { isSaving = false }
        
        // Validate required fields
        guard !url.isEmpty, !title.isEmpty else {
            throw BookmarkEditError.requiredFieldsMissing
        }
        
        // Create bookmark record - note: createdAt must be 3rd parameter
        // Prefer imageUrl over imageData
        let imageBlob: ComAtprotoLexicon.Repository.BlobContainer? = nil
        // TODO: If imageUrl == nil && imageData != nil, upload blob to AT Protocol
        // For now, we'll pass nil and handle blob upload in BookmarkManager
        
        let record = BookmarkRecord(
            url: url,
            title: title,
            createdAt: originalBookmark?.record.createdAt ?? Date(),
            description: description.isEmpty ? nil : description,
            summary: summary.isEmpty ? nil : summary,
            note: note.isEmpty ? nil : note,
            imageUrl: imageUrl,
            imageBlob: imageBlob,
            tags: tags.isEmpty ? nil : tags,
            listUris: selectedLists.isEmpty ? nil : Array(selectedLists),
            pinned: pinned ? true : nil,
            archived: archived ? true : nil,
            reminder: nil,
            sourceUri: nil,
            encrypted: nil,
            updatedAt: isEditMode ? Date() : nil
        )
        
        if isEditMode, let original = originalBookmark {
            // Update existing bookmark
            try await bookmarkManager.updateBookmark(uri: original.uri, record: record)
        } else {
            // Create new bookmark
            try await bookmarkManager.createBookmark(record)
        }
    }
    
    // MARK: - Tags Management
    
    func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty,
              !tags.contains(trimmedTag),
              tags.count < 20 else { return }
        
        tags.append(trimmedTag)
        tagInput = ""
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Supporting Types

enum BookmarkEditError: LocalizedError {
    case metadataFetchFailed
    case managerNotConfigured
    case requiredFieldsMissing
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .metadataFetchFailed:
            return "Failed to fetch webpage metadata"
        case .managerNotConfigured:
            return "Bookmark manager not configured"
        case .requiredFieldsMissing:
            return "URL and title are required"
        case .saveFailed(let message):
            return "Failed to save bookmark: \(message)"
        }
    }
}