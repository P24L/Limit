//
//  BookmarkProcessingQueue.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import Foundation
import SwiftData
import UIKit
import ATProtoKit
import WebImageExtractor 

@MainActor
class BookmarkProcessingQueue {
    private let client: MultiAccountClient
    private let context: ModelContext
    weak var bookmarkManager: BookmarkManager?
    private var processingTask: Task<Void, Never>?
    private var isProcessing = false
    
    init(client: MultiAccountClient, context: ModelContext, bookmarkManager: BookmarkManager? = nil) {
        self.client = client
        self.context = context
        self.bookmarkManager = bookmarkManager
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
                    let needsSummary = bookmark.summary == nil || bookmark.summary?.isEmpty == true
                    let needsImage = bookmark.imageUrl == nil && bookmark.imageBlob == nil && !bookmark.imageGenerated
                    
                    if needsSummary {
                        await self.processSummary(for: bookmark)
                    }
                    
                    if needsImage {
                        DevLogger.shared.log("BookmarkProcessingQueue - Processing image for: \(bookmark.title)")
                        await self.processImage(for: bookmark)
                    }
                    
                    if !needsSummary && !needsImage {
                        // Nothing to process, mark as completed
                        DevLogger.shared.log("BookmarkProcessingQueue - Nothing to process for: \(bookmark.title) (has image: \(bookmark.imageUrl != nil || bookmark.imageBlob != nil), generated: \(bookmark.imageGenerated))")
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
        
        // Generate thumbnail/preview image using WebImageExtractor
        guard let url = URL(string: bookmark.url) else {
            bookmark.processingStatus = .failed
            try? context.save()
            return
        }
        
        let imageExtractor = WebImageExtractor()
        let result = await imageExtractor.fetchBestImage(for: url)
        
        DevLogger.shared.log("BookmarkProcessingQueue - WebImageExtractor result: imageURL=\(result.imageURL ?? "nil"), hasData=\(result.imageData != nil)")
        
        // Store image URL if available, otherwise store data
        if let imageURL = result.imageURL {
            bookmark.imageUrl = imageURL
            bookmark.imageBlob = nil
            DevLogger.shared.log("BookmarkProcessingQueue - Stored image URL: \(imageURL)")
        } else if let imageData = result.imageData {
            bookmark.imageUrl = nil
            bookmark.imageBlob = imageData
            DevLogger.shared.log("BookmarkProcessingQueue - Stored image data: \(imageData.count) bytes")
        }
        
        bookmark.imageGenerated = true
        bookmark.processingStatus = .completed
        
        DevLogger.shared.log("BookmarkProcessingQueue - Processed image for: \(bookmark.title)")
        
        try? context.save()
        
        // Update in AT Protocol with image
        await updateBookmarkInATProtocol(bookmark)
        
        // Refresh the bookmark in BookmarkManager to update UI
        if let bookmarkManager = bookmarkManager {
            await bookmarkManager.refreshBookmark(uri: bookmark.uri)
        }
        
        // If we only have a URL, optionally download the image data in the background
        // Uncomment if you want to pre-download images for offline viewing
        /*
        if let imageURL = bookmark.imageUrl, bookmark.imageBlob == nil {
            Task.detached { [weak self] in
                guard let self = self else { return }
                if let data = await self.downloadImage(from: imageURL) {
                    await MainActor.run {
                        bookmark.imageBlob = data
                        try? self.context.save()
                    }
                }
            }
        }
        */
    }
    
    private func downloadImage(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            return ImageOptimizer.optimize(image, maxSizeKB: 480)
        } catch {
            DevLogger.shared.log("BookmarkProcessingQueue - Failed to download image: \(error)")
            return nil
        }
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
            // Handle image blob upload if needed
            var imageBlob: ComAtprotoLexicon.Repository.BlobContainer? = nil
            
            if bookmark.imageUrl == nil, let imageData = bookmark.imageBlob {
                // Upload the blob first
                do {
                    // Get access token from keychain
                    guard let keychain = protoClient.sessionConfiguration?.keychainProtocol,
                          let accessToken = try? await keychain.retrieveAccessToken() else {
                        DevLogger.shared.log("BookmarkProcessingQueue - Failed to get access token for blob upload")
                        throw ATRequestPrepareError.missingActiveSession
                    }
                    
                    // Get PDS URL from session
                    let session = try await protoClient.getUserSession()
                    let pdsURL = session?.pdsURL ?? "https://bsky.social"
                    
                    imageBlob = try await protoClient.uploadBlob(
                        pdsURL: pdsURL,
                        accessToken: accessToken,
                        filename: "bookmark-image.jpg",
                        imageData: imageData
                    )
                    DevLogger.shared.log("BookmarkProcessingQueue - Uploaded image blob: \(imageData.count) bytes")
                } catch {
                    DevLogger.shared.log("BookmarkProcessingQueue - Failed to upload image blob: \(error)")
                    // Continue without image if upload fails
                }
            }
            
            let updates = BookmarkUpdateInput(
                summary: bookmark.summary,
                imageUrl: bookmark.imageUrl,
                imageBlob: imageBlob
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