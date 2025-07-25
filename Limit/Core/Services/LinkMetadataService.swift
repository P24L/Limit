//
//  LinkMetadataService.swift
//  Limit
//
//  Created by Claude on 02.07.2025.
//

import Foundation
import LinkPresentation
import SwiftData

@Observable
final class LinkMetadataService {
    static let shared = LinkMetadataService()
    
    private var _context: ModelContext?
    
    var context: ModelContext? {
        return _context
    }
    
    private init() {}
    
    func configure(context: ModelContext) {
        Task { @MainActor in
            self._context = context
        }
    }
    
    /// Fetches link metadata and updates PostFacet in database
    func fetchMetadata(for facet: PostFacet) async {
        guard facet.facetType == .link,
              let uri = facet.uri,
              let url = URL(string: uri),
              !facet.metadataFetched else {
            return
        }
        
        do {
            // Create new provider for each request - LPMetadataProvider is one-shot
            let metadataProvider = LPMetadataProvider()
            
            // Add timeout to prevent hanging
            let metadata = try await withTimeout(seconds: 10) {
                try await metadataProvider.startFetchingMetadata(for: url)
            }
            
            // Update facet with metadata
            await updateFacet(facet, with: metadata)
            
        } catch {         
            // Mark as fetched even if failed to avoid repeated attempts
            await markFacetAsAttempted(facet)
        }
    }
    
    /// Updates PostFacet with fetched metadata
    @MainActor
    private func updateFacet(_ facet: PostFacet, with metadata: LPLinkMetadata) async {
        facet.title = metadata.title
        facet.linkDescription = nil // Will handle description later
        
        // Handle thumbnail image - fallback to Google Favicon Service
        if let uri = facet.uri, let url = URL(string: uri) {
            if let domain = url.host {
                facet.thumbnailURL = getGoogleFaviconURL(for: domain)?.absoluteString
            }
        }
        
        facet.metadataFetched = true
        
        // Save to database
        do {
            try _context?.save()
        } catch {
            DevLogger.shared.log("LinkMetadataService - Failed to save metadata: \(error.localizedDescription)")
        }
    }
    
    /// Marks a facet as attempted (failed or completed)
    @MainActor
    private func markFacetAsAttempted(_ facet: PostFacet) {
        facet.metadataFetched = true
        try? _context?.save()
    }
    
    /// Batch fetch metadata for multiple link facets
    func fetchMetadataForLinks(_ facets: [PostFacet]) async {
        let linkFacets = facets.filter { 
            $0.facetType == .link && !$0.metadataFetched && $0.uri != nil 
        }
        
        // Limit concurrent requests to avoid overwhelming the system
        let batchSize = 2  // Reduced to be more conservative
        for batch in linkFacets.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for facet in batch {
                    group.addTask {
                        await self.fetchMetadata(for: facet)
                    }
                }
            }
            
            // Small delay between batches to prevent overwhelming
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
    
    // MARK: - Google Favicon Service Helper
    
    /// Gets Google Favicon URL for a given domain
    private func getGoogleFaviconURL(for domain: String) -> URL? {
        let googleFaviconAPI = "https://www.google.com/s2/favicons?domain=\(domain)&sz=256"
        return URL(string: googleFaviconAPI)
    }
}

