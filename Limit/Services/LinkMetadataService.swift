//
//  LinkMetadataService.swift
//  Limit
//
//  Created by Claude on 02.07.2025.
//

import Foundation
import LinkPresentation
import SwiftData

@MainActor
@Observable
final class LinkMetadataService {
    static let shared = LinkMetadataService()
    
    private var context: ModelContext?
    
    private init() {}
    
    func configure(context: ModelContext) {
        self.context = context
    }
    
    /// Fetches link metadata and updates PostFacet in database
    func fetchMetadata(for facet: PostFacet) async {
        guard facet.facetType == .link,
              let uri = facet.uri,
              let url = URL(string: uri),
              !facet.metadataFetched else {
            return
        }
        
        DevLogger.shared.log("LinkMetadataService - Fetching metadata for: \(uri)")
        
        do {
            // Create new provider for each request - LPMetadataProvider is one-shot
            let metadataProvider = LPMetadataProvider()
            let metadata = try await metadataProvider.startFetchingMetadata(for: url)
            
            // Update facet with metadata
            await updateFacet(facet, with: metadata)
            
        } catch {
            DevLogger.shared.log("LinkMetadataService - Failed to fetch metadata: \(error.localizedDescription)")
            
            // Mark as fetched even if failed to avoid repeated attempts
            facet.metadataFetched = true
            try? context?.save()
        }
    }
    
    /// Updates PostFacet with fetched metadata
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
            try context?.save()
            DevLogger.shared.log("LinkMetadataService - Metadata saved for: \(facet.uri ?? "")")
        } catch {
            DevLogger.shared.log("LinkMetadataService - Failed to save metadata: \(error.localizedDescription)")
        }
    }
    
    /// Batch fetch metadata for multiple link facets
    func fetchMetadataForLinks(_ facets: [PostFacet]) async {
        let linkFacets = facets.filter { 
            $0.facetType == .link && !$0.metadataFetched && $0.uri != nil 
        }
        
        // Limit concurrent requests to avoid overwhelming the system
        let batchSize = 3
        for batch in linkFacets.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for facet in batch {
                    group.addTask {
                        await self.fetchMetadata(for: facet)
                    }
                }
            }
        }
    }
    
    // MARK: - Google Favicon Service Helper
    
    /// Gets Google Favicon URL for a given domain
    private func getGoogleFaviconURL(for domain: String) -> URL? {
        let googleFaviconAPI = "https://www.google.com/s2/favicons?domain=\(domain)&sz=256"
        return URL(string: googleFaviconAPI)
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}