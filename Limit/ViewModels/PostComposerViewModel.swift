//
//  PostComposerViewModel.swift
//  Limit
//
//  Created by Assistant on 17.07.2025.
//

import Foundation
import SwiftUI
import ATProtoKit
import Observation

@Observable
class PostComposerViewModel {
    // MARK: - Properties
    var currentDraft = PostDraft()
    var isPosting = false
    var error: PostComposerError?
    var showError = false
    
    // For thread creation
    var isThreadMode = false
    var allDrafts: [PostDraft] = []
    
    // Real-time parsing
    private var parseTask: Task<Void, Never>?
    private let parseDebounce: TimeInterval = 0.3
    private var fullParseTask: Task<Void, Never>?
    private let fullParseDebounce: TimeInterval = 2.0  // 2 seconds for full validation
    
    // Cache for mention validation to avoid repeated network calls
    private var mentionCache: [String: Bool] = [:]
    private var lastParsedText: String = ""
    
    // Version tracking to prevent race conditions
    private var parseVersion = 0
    
    // MARK: - Initialization
    init() {
        allDrafts = [currentDraft]
    }
    
    // MARK: - Text Management
    func textDidChange(_ newText: String) {
        currentDraft.text = newText
        
        // Increment version for this text change
        parseVersion += 1
        let currentVersion = parseVersion
        
        // Log only significant text changes
        if newText.count > 0 && (newText.count == 1 || abs(newText.count - lastParsedText.count) > 5) {
            DevLogger.shared.log("PostComposerViewModel.swift - Text changed (v\(currentVersion)): \(newText.count) chars")
        }
        
        // Cancel previous parse tasks
        parseTask?.cancel()
        fullParseTask?.cancel()
        
        // Debounced parsing
        parseTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(parseDebounce * 1_000_000_000))
            } catch {
                return // Task was cancelled
            }
            
            guard !Task.isCancelled else { return }
            guard self.parseVersion == currentVersion else { return }
            
            await self.parseText(newText, version: currentVersion)
        }
    }
    
    @MainActor
    private func parseText(_ text: String, version: Int) async {
        
        // Quick parse for local highlighting (URLs and hashtags only)
        let urls = ATFacetParser.parseURLs(from: text)
        let hashtags = ATFacetParser.parseHashtags(from: text)
        let mentions = ATFacetParser.parseMentions(from: text)
        
        // Create quick facets for immediate highlighting
        var quickFacets: [AppBskyLexicon.RichText.Facet] = []
        
        // Add URL facets
        for url in urls {
            if let start = url["start"] as? Int,
               let end = url["end"] as? Int,
               let urlText = url["link"] as? String,
               let urlObj = URL(string: urlText) {
                let facet = AppBskyLexicon.RichText.Facet(
                    index: AppBskyLexicon.RichText.Facet.ByteSlice(byteStart: start, byteEnd: end),
                    features: [.link(AppBskyLexicon.RichText.Facet.Link(uri: urlObj.absoluteString))]
                )
                quickFacets.append(facet)
            }
        }
        
        // Add hashtag facets
        for hashtag in hashtags {
            if let start = hashtag["start"] as? Int,
               let end = hashtag["end"] as? Int,
               let tag = hashtag["tag"] as? String {
                let cleanTag = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
                let facet = AppBskyLexicon.RichText.Facet(
                    index: AppBskyLexicon.RichText.Facet.ByteSlice(byteStart: start, byteEnd: end),
                    features: [.tag(AppBskyLexicon.RichText.Facet.Tag(tag: cleanTag))]
                )
                quickFacets.append(facet)
            }
        }
        
        // Add mention facets - always show them for immediate feedback
        for mention in mentions {
            if let start = mention["start"] as? Int,
               let end = mention["end"] as? Int,
               let mentionText = mention["mention"] as? String {
                
                // Skip if we know it's invalid from cache
                if mentionCache[mentionText] == false {
                    continue
                }
                
                // Always show mention highlighting for immediate feedback
                let facet = AppBskyLexicon.RichText.Facet(
                    index: AppBskyLexicon.RichText.Facet.ByteSlice(byteStart: start, byteEnd: end),
                    features: [.mention(AppBskyLexicon.RichText.Facet.Mention(did: mentionText))]
                )
                quickFacets.append(facet)
            }
        }
        
        // Truncate URLs for display
        let (displayText, _) = ATFacetParser.truncateAndReplaceLinks(in: text)
        
        // Update UI immediately with quick facets (only if version still matches)
        guard parseVersion == version else {
            DevLogger.shared.log("PostComposerViewModel.swift - MENTIONS: Version mismatch in quick parse (current: \(parseVersion), expected: \(version)) - skipping update")
            return
        }
        
        currentDraft.facets = quickFacets
        currentDraft.displayText = displayText
        
        // Extract first URL for potential embed (only if no media attached)
        if currentDraft.images.isEmpty && currentDraft.video == nil {
            await extractFirstURLForEmbed(from: quickFacets)
        }
        
        // Check if we have any mentions that are ready to validate
        var completeMentions: [String] = []
        
        for mention in mentions {
            if let mentionText = mention["text"] as? String,
               let _ = mention["start"] as? Int,
               let end = mention["end"] as? Int {
                
                // Check if mention is followed by space/newline or is at end of text
                let isFollowedBySpace = end < text.utf8.count && 
                    (text.characterIndex(at: end).map { index in
                        let nextChar = text[text.index(text.startIndex, offsetBy: index)]
                        return nextChar == " " || nextChar == "\n"
                    } ?? false)
                let isAtEndOfText = end >= text.utf8.count
                
                // Mention is complete if it has proper format and is terminated
                let looksComplete = mentionText.contains(".") && 
                    (mentionText.hasSuffix(".social") || 
                     mentionText.hasSuffix(".app") || 
                     mentionText.hasSuffix(".blue") ||
                     mentionText.count > 10)
                
                if looksComplete && (isFollowedBySpace || isAtEndOfText) {
                    completeMentions.append(mentionText)
                }
            }
        }
        
        // First parse is disabled to prevent facets from disappearing
        // We rely on the second parse with timeout below for all validations
        /*
        // Only do full parse with network calls if we have complete mentions to validate
        let shouldValidate = hasCompleteMentions && 
            completeMentions.contains { mentionCache[$0] == nil }
        
        if shouldValidate {
            lastParsedText = text
            // Full parse in background (with network calls for mentions)
            Task.detached { [weak self] in
                let fullFacets = await ATFacetParser.parseFacets(from: text)
                await MainActor.run {
                    // Only update if text hasn't changed since we started
                    if self?.currentDraft.text == text {
                        self?.currentDraft.facets = fullFacets
                        // Cache mention results
                        for facet in fullFacets {
                            for feature in facet.features {
                                if case .mention(_) = feature {
                                    let mentionText = text.substring(
                                        fromByte: facet.index.byteStart,
                                        toByte: facet.index.byteEnd
                                    ) ?? ""
                                    self?.mentionCache[mentionText] = true
                                }
                            }
                        }
                        // Cache invalid mentions
                        for mention in mentions {
                            if let mentionText = mention["text"] as? String {
                                let found = fullFacets.contains { facet in
                                    if let start = text.characterIndex(at: facet.index.byteStart),
                                       let end = text.characterIndex(at: facet.index.byteEnd) {
                                        let facetText = String(text[text.index(text.startIndex, offsetBy: start)..<text.index(text.startIndex, offsetBy: end)])
                                        return facetText == mentionText
                                    }
                                    return false
                                }
                                if !found && mentionText.contains(".") {
                                    self?.mentionCache[mentionText] = false
                                }
                            }
                        }
                    }
                }
            }
        }
        */
        
        // Also schedule a full parse after longer timeout (for mentions that user stopped typing)
        fullParseTask?.cancel()
        if true { // Always run full parse to catch all facets including URLs
            fullParseTask = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: UInt64(fullParseDebounce * 1_000_000_000))
                } catch {
                    return // Task was cancelled
                }
                
                guard !Task.isCancelled else { return }
                
                // Do full parse if we have any mentions
                let textCopy = text
                let versionCopy = version
                let mentionsCopy = mentions
                
                Task.detached { [weak self] in
                    let fullFacets = await ATFacetParser.parseFacets(from: textCopy)
                    
                    await MainActor.run {
                        guard let self = self else { return }
                        // Check both text and version to ensure we're still relevant
                        if self.currentDraft.text == textCopy && self.parseVersion == versionCopy {
                            self.currentDraft.facets = fullFacets
                            // Update cache
                            for mention in mentionsCopy {
                                if let mentionText = mention["mention"] as? String {
                                    let found = fullFacets.contains { facet in
                                        facet.features.contains { feature in
                                            if case .mention(_) = feature {
                                                if let facetText = textCopy.substring(
                                                    fromByte: facet.index.byteStart,
                                                    toByte: facet.index.byteEnd
                                                ) {
                                                    return facetText == mentionText
                                                }
                                            }
                                            return false
                                        }
                                    }
                                    self.mentionCache[mentionText] = found
                                }
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    // Overload for calls without version (e.g., from switchToThreadPost)
    @MainActor
    private func parseText(_ text: String) async {
        parseVersion += 1
        await parseText(text, version: parseVersion)
    }
    
    // MARK: - External Link Handling
    @MainActor
    private func extractFirstURLForEmbed(from facets: [AppBskyLexicon.RichText.Facet]) async {
        // Find first link facet
        for facet in facets {
            for feature in facet.features {
                if case .link(let link) = feature,
                   let url = URL(string: link.uri) {
                    DevLogger.shared.log("PostComposerViewModel.swift - Extracting embed for URL: \(url)")
                    
                    // Create a simple preview for now
                    // In a full implementation, you'd fetch metadata from the URL
                    currentDraft.externalLink = ExternalLinkPreview(
                        url: url,
                        title: url.host() ?? "Link",
                        description: nil,
                        thumbnailURL: nil
                    )
                    return
                }
            }
        }
        
        // No URL found, clear any existing preview
        currentDraft.externalLink = nil
    }
    
    // MARK: - Media Handling
    func addImages(_ images: [UIImage]) async throws {
        guard currentDraft.images.count + images.count <= 4 else {
            throw PostComposerError.tooManyImages(count: currentDraft.images.count + images.count)
        }
        
        // Clear video if adding images
        currentDraft.video = nil
        
        for image in images {
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                throw PostComposerError.invalidImageFormat
            }
            
            let imageQuery = ATProtoTools.ImageQuery(
                imageData: jpegData,
                fileName: "photo_\(UUID().uuidString).jpg",
                altText: nil,
                aspectRatio: nil
            )
            
            currentDraft.images.append(imageQuery)
        }
        
        // Clear external link when media is added
        currentDraft.externalLink = nil
        
        DevLogger.shared.log("PostComposerViewModel.swift - Added \(images.count) images")
    }
    
    func removeImage(at index: Int) {
        guard index < currentDraft.images.count else { return }
        currentDraft.images.remove(at: index)
        
        // Re-parse to potentially extract URL embed if no media left
        if currentDraft.images.isEmpty && currentDraft.video == nil {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.parseText(self.currentDraft.text)
            }
        }
    }
    
    func addVideo(data: Data, altText: String? = nil) throws {
        let attachment = VideoAttachment(
            data: data,
            captions: nil,
            altText: altText,
            aspectRatio: nil // Would be calculated from video
        )
        
        guard attachment.isWithinSizeLimit else {
            throw PostComposerError.videoTooLarge(sizeMB: attachment.sizeInMB)
        }
        
        // Clear images if adding video
        currentDraft.images.removeAll()
        currentDraft.video = attachment
        
        // Clear external link when media is added
        currentDraft.externalLink = nil
        
        DevLogger.shared.log("PostComposerViewModel.swift - Added video (\(String(format: "%.1f", attachment.sizeInMB))MB)")
    }
    
    func removeVideo() {
        currentDraft.video = nil
        
        // Re-parse to potentially extract URL embed
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.parseText(self.currentDraft.text)
        }
    }
    
    // MARK: - Language Management
    func toggleLanguage(_ locale: Locale) {
        if let index = currentDraft.languages.firstIndex(of: locale) {
            currentDraft.languages.remove(at: index)
        } else if currentDraft.languages.count < 3 {
            currentDraft.languages.append(locale)
        }
    }
    
    // MARK: - Thread Management
    func addThreadPost() {
        // Save current draft before any changes
        if let currentIndex = allDrafts.firstIndex(where: { $0.id == currentDraft.id }) {
            allDrafts[currentIndex] = currentDraft
        }
        
        if !isThreadMode {
            isThreadMode = true
            // Create and switch to new draft immediately
            var newDraft = PostDraft()
            newDraft.languages = currentDraft.languages
            allDrafts.append(newDraft)
            currentDraft = newDraft
            return
        }
        
        // Already in thread mode - create new draft
        var newDraft = PostDraft()
        newDraft.languages = currentDraft.languages
        allDrafts.append(newDraft)
        currentDraft = newDraft
    }
    
    func removeThreadPost(at index: Int) {
        guard allDrafts.count > 1, index < allDrafts.count else { return }
        allDrafts.remove(at: index)
        
        if allDrafts.count == 1 {
            isThreadMode = false
        }
        
        // Switch to first draft if current was removed
        if index == 0 || allDrafts.isEmpty {
            currentDraft = allDrafts.first ?? PostDraft()
        }
    }
    
    func switchToThreadPost(at index: Int) {
        guard index < allDrafts.count else { return }
        
        // Save current draft before switching
        if let currentIndex = allDrafts.firstIndex(where: { $0.id == currentDraft.id }) {
            allDrafts[currentIndex] = currentDraft
        }
        
        // Switch to selected draft
        currentDraft = allDrafts[index]
        
        // Re-parse text to update facets and highlighting
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.parseText(self.currentDraft.text)
        }
    }
    
    // MARK: - Validation
    var canPost: Bool {
        if isThreadMode {
            return allDrafts.contains { $0.isValid }
        } else {
            return currentDraft.isValid
        }
    }
    
    var validationError: String? {
        if currentDraft.text.isEmpty {
            return nil // No error for empty text, just disable post button
        }
        
        if currentDraft.characterCount > 300 {
            return "Text is too long (\(currentDraft.characterCount)/300)"
        }
        
        if currentDraft.images.count > 4 {
            return "Too many images (max 4)"
        }
        
        if let video = currentDraft.video, !video.isWithinSizeLimit {
            return "Video is too large (max 100MB)"
        }
        
        return nil
    }
    
    // MARK: - Post Submission
    func submitPost(using client: BlueskyClient) async throws {
        guard canPost else {
            throw PostComposerError.noContent
        }
        
        isPosting = true
        defer { isPosting = false }
        
        // Always save current draft before posting
        if let currentIndex = allDrafts.firstIndex(where: { $0.id == currentDraft.id }) {
            allDrafts[currentIndex] = currentDraft
        }
        
        do {
            if isThreadMode {
                try await postThread(using: client)
            } else {
                _ = try await postSingle(currentDraft, using: client)
            }
        } catch let error as PostComposerError {
            self.error = error
            showError = true
            throw error
        } catch {
            self.error = .networkError(error)
            showError = true
            throw error
        }
    }
    
    private func postSingle(_ draft: PostDraft, using client: BlueskyClient, replyTo: AppBskyLexicon.Feed.PostRecord.ReplyReference? = nil) async throws -> ComAtprotoLexicon.Repository.StrongReference {
        DevLogger.shared.log("PostComposerViewModel.swift - Posting: \(draft.text.prefix(50))...")
        
        // Prepare embed
        let embed = try await prepareEmbed(for: draft, using: client)
        
        // Create post via BlueskyClient
        let result = try await client.createPost(
            text: draft.text,
            facets: draft.facets,
            languages: draft.languages,
            replyTo: replyTo ?? draft.replyTo,
            embed: embed
        )
        
        DevLogger.shared.log("PostComposerViewModel.swift - Post created successfully")
        return result
    }
    
    private func postThread(using client: BlueskyClient) async throws {
        var lastPostRef: ComAtprotoLexicon.Repository.StrongReference?
        
        for (index, draft) in allDrafts.enumerated() where draft.isValid {
            DevLogger.shared.log("PostComposerViewModel.swift - Posting thread item \(index + 1)/\(allDrafts.count)")
            
            // Create reply reference if this is not the first post
            var replyRef: AppBskyLexicon.Feed.PostRecord.ReplyReference?
            if let lastRef = lastPostRef {
                replyRef = try await ATProtoTools().createReplyReference(
                    from: lastRef,
                    session: client.currentSession!
                )
            }
            
            lastPostRef = try await postSingle(draft, using: client, replyTo: replyRef)
        }
    }
    
    private func prepareEmbed(for draft: PostDraft, using client: BlueskyClient) async throws -> ATProtoBluesky.EmbedIdentifier? {
        // Priority: Images > Video > External Link
        if !draft.images.isEmpty {
            DevLogger.shared.log("PostComposerViewModel.swift - Preparing image embed")
            return .images(images: draft.images)
        } else if let video = draft.video {
            DevLogger.shared.log("PostComposerViewModel.swift - Preparing video embed")
            return .video(
                video: video.data,
                captions: video.captions,
                altText: video.altText,
                aspectoRatio: video.aspectRatio
            )
        } else if let link = draft.externalLink {
            DevLogger.shared.log("PostComposerViewModel.swift - Preparing external link embed")
            return .external(
                url: link.url,
                title: link.title,
                description: link.description ?? "",
                thumbnailURL: link.thumbnailURL
            )
        }
        
        return nil
    }
}