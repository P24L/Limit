//
//  BookmarkProcessingQueue.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import Foundation
import SwiftData

@MainActor
class BookmarkProcessingQueue {
    private let client: BlueskyClient
    private let context: ModelContext
    private var processingTask: Task<Void, Never>?
    private var isProcessing = false
    
    init(client: BlueskyClient, context: ModelContext) {
        self.client = client
        self.context = context
    }
    
    // MARK: - Queue Management
    
    func enqueueBookmarkForDescription(_ bookmark: CachedBookmark) async {
        bookmark.processingStatus = .pending
        try? context.save()
        
        if !isProcessing {
            startProcessing()
        }
    }
    
    func enqueueBookmarkForImageGeneration(_ bookmark: CachedBookmark) async {
        bookmark.processingStatus = .pending
        bookmark.imageGenerated = false
        try? context.save()
        
        if !isProcessing {
            startProcessing()
        }
    }
    
    private func startProcessing() {
        guard !isProcessing else { return }
        
        processingTask = Task {
            isProcessing = true
            defer { isProcessing = false }
            
            while await hasItemsToProcess() {
                await processNext()
                
                // Small delay to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }
    
    private func hasItemsToProcess() async -> Bool {
        // SwiftData doesn't support enum comparisons in predicates
        // Fetch all and check manually
        let allBookmarks = (try? context.fetch(FetchDescriptor<CachedBookmark>())) ?? []
        let pendingCount = allBookmarks.filter { bookmark in
            bookmark.processingStatus == .pending || 
            bookmark.processingStatus == .processingDescription ||
            bookmark.processingStatus == .processingImage
        }.count
        return pendingCount > 0
    }
    
    // MARK: - Processing
    
    func processNext() async {
        // Get batch of items to process
        let descriptor = FetchDescriptor<CachedBookmark>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        let allBookmarks = (try? context.fetch(descriptor)) ?? []
        let pendingBookmarks = allBookmarks.filter { $0.processingStatus == .pending }.prefix(5) // Process up to 5 at once
        
        guard !pendingBookmarks.isEmpty else { return }
        
        DevLogger.shared.log("BookmarkProcessingQueue - Processing batch of \(pendingBookmarks.count) bookmarks")
        
        // Process batch using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for bookmark in pendingBookmarks {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    // Determine what needs processing
                    if bookmark.summary == nil || bookmark.summary?.isEmpty == true {
                        await self.processSummary(for: bookmark)
                    } else if bookmark.imageUrl == nil && bookmark.imageBlob == nil && !bookmark.imageGenerated {
                        await self.processImage(for: bookmark)
                    } else {
                        // Nothing to process, mark as completed
                        await MainActor.run {
                            bookmark.processingStatus = .completed
                            try? self.context.save()
                        }
                    }
                }
            }
            
            // Wait for all tasks to complete
            await group.waitForAll()
        }
    }
    
    private func processSummary(for bookmark: CachedBookmark) async {
        bookmark.processingStatus = .processingDescription
        try? context.save()
        
        do {
            // Use AI service to generate summary
            let url = URL(string: bookmark.url)!
            let aiService = AIService()
            let result = try await aiService.summarizeURL(url)
            
            bookmark.summary = result.summary
            bookmark.processingStatus = .completed
            
            DevLogger.shared.log("BookmarkProcessingQueue - Generated summary for: \(bookmark.title)")
        } catch {
            bookmark.processingStatus = .failed
            DevLogger.shared.log("BookmarkProcessingQueue - Failed to generate summary: \(error)")
        }
        
        try? context.save()
        
        // Update in AT Protocol
        await updateBookmarkInATProtocol(bookmark)
    }
    
    private func processImage(for bookmark: CachedBookmark) async {
        bookmark.processingStatus = .processingImage
        try? context.save()
        
        // Generate thumbnail/preview image
        // This is a placeholder - implement actual image generation
        // Could use:
        // 1. Web page screenshot service
        // 2. Open Graph image extraction
        // 3. AI image generation based on content
        
        bookmark.imageGenerated = true
        bookmark.processingStatus = .completed
        
        DevLogger.shared.log("BookmarkProcessingQueue - Processed image for: \(bookmark.title)")
        
        try? context.save()
    }
    
    // MARK: - AT Protocol Update
    
    private func updateBookmarkInATProtocol(_ bookmark: CachedBookmark) async {
        guard let protoClient = client.protoClient else { return }
        
        // Extract repo and rkey from URI using ATProtoUtils
        guard let (repo, rkey) = ATProtoUtils.extractRepoAndRkey(from: bookmark.uri) else {
            DevLogger.shared.log("BookmarkProcessingQueue - Invalid bookmark URI: \(bookmark.uri)")
            return
        }
        
        do {
            let updates = BookmarkUpdateInput(
                summary: bookmark.summary
            )
            
            // Use retry logic for better reliability
            _ = try await ATProtoUtils.withRetry(maxAttempts: 2, delay: 0.5) {
                try await protoClient.updateBookmark(
                    repo: repo,
                    rkey: rkey,
                    updates: updates
                )
            }
            
            bookmark.syncStatus = .synced
            bookmark.lastSynced = Date()
            try? context.save()
            
            DevLogger.shared.log("BookmarkProcessingQueue - Updated bookmark in AT Protocol: \(bookmark.title)")
        } catch {
            bookmark.syncStatus = .failed
            try? context.save()
            DevLogger.shared.log("BookmarkProcessingQueue - Failed to update AT Protocol: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
    }
}