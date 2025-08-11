import Foundation
import SwiftUI
import SwiftSoup

public class WebImageExtractor {
    
    // MARK: - Public Interface
    
    public struct ImageResult: Sendable {
        public let imageURL: String?      // Preferred option - URL of the image
        public let imageData: Data?        // Fallback - actual image data
        
        public init(imageURL: String? = nil, imageData: Data? = nil) {
            self.imageURL = imageURL
            self.imageData = imageData
        }
    }
    
    public struct WebMetadata: Sendable {
        public let title: String?
        public let description: String?
        public let imageUrl: String?
        
        public init(title: String? = nil, description: String? = nil, imageUrl: String? = nil) {
            self.title = title
            self.description = description
            self.imageUrl = imageUrl
        }
    }
    
    public init() {}
    
    /// Fetches the best possible image for a given URL
    /// Returns either an image URL (preferred) or image data
    public func fetchBestImage(for url: URL) async -> ImageResult {
        
        // 1. Try LPMetadataProvider (fast but often fails)
        if let lpResult = await tryLPMetadata(for: url) {
            return lpResult
        }
        
        // 2. Download HTML and look for images
        if let htmlResult = await tryHTMLExtraction(for: url) {
            return htmlResult
        }
        
        // 3. Try to generate a screenshot
        if let screenshotResult = await tryScreenshot(for: url) {
            return screenshotResult
        }
        
        // 4. Fallback to favicon
        return getFaviconResult(for: url)
    }
    
    /// Fetches metadata (title, description, image URL) from a webpage
    public func fetchMetadata(for url: URL) async -> WebMetadata {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return WebMetadata()
            }
            
            let extractor = ImageURLExtractor()
            
            // Extract title
            let title = extractor.extractTitle(from: html) ?? url.host ?? "Untitled"
            
            // Extract description
            let description = extractor.extractDescription(from: html)
            
            // Extract image URL
            var imageUrl: String? = nil
            if let ogImage = extractor.extractOpenGraphImage(from: html) {
                imageUrl = makeAbsoluteURL(ogImage, baseURL: url)
            } else if let twitterImage = extractor.extractTwitterCardImage(from: html) {
                imageUrl = makeAbsoluteURL(twitterImage, baseURL: url)
            }
            
            return WebMetadata(
                title: title,
                description: description,
                imageUrl: imageUrl
            )
        } catch {
            print("WebImageExtractor - Failed to fetch metadata: \(error)")
            return WebMetadata(title: url.host ?? "Untitled")
        }
    }
    
    /// Fetches both metadata and best image for a webpage
    /// More efficient than calling fetchMetadata and fetchBestImage separately
    public func fetchMetadataAndImage(for url: URL) async -> (metadata: WebMetadata, image: ImageResult) {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return (WebMetadata(), getFaviconResult(for: url))
            }
            
            let extractor = ImageURLExtractor()
            
            // Extract metadata
            let title = extractor.extractTitle(from: html) ?? url.host ?? "Untitled"
            let description = extractor.extractDescription(from: html)
            
            // Extract image URL
            var imageUrl: String? = nil
            if let ogImage = extractor.extractOpenGraphImage(from: html) {
                imageUrl = makeAbsoluteURL(ogImage, baseURL: url)
            } else if let twitterImage = extractor.extractTwitterCardImage(from: html) {
                imageUrl = makeAbsoluteURL(twitterImage, baseURL: url)
            } else if let firstImage = extractor.extractFirstSignificantImage(from: html) {
                imageUrl = makeAbsoluteURL(firstImage, baseURL: url)
            }
            
            let metadata = WebMetadata(
                title: title,
                description: description,
                imageUrl: imageUrl
            )
            
            // Prepare image result
            let imageResult: ImageResult
            if let imageUrl = imageUrl {
                imageResult = ImageResult(imageURL: imageUrl)
            } else {
                // Try screenshot or favicon as fallback
                if let screenshotResult = await tryScreenshot(for: url) {
                    imageResult = screenshotResult
                } else {
                    imageResult = getFaviconResult(for: url)
                }
            }
            
            return (metadata, imageResult)
            
        } catch {
            print("WebImageExtractor - Failed to fetch metadata and image: \(error)")
            return (
                WebMetadata(title: url.host ?? "Untitled"),
                getFaviconResult(for: url)
            )
        }
    }
    
    // MARK: - LPMetadata Approach
    
    private func tryLPMetadata(for url: URL) async -> ImageResult? {
        // LPMetadataProvider is not compatible with Swift 6 strict concurrency
        // and often fails anyway. We have better alternatives with HTML parsing.
        return nil
    }
    
    // MARK: - HTML Extraction
    
    private func tryHTMLExtraction(for url: URL) async -> ImageResult? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            let extractor = ImageURLExtractor()
            
            // Try Open Graph
            if let ogImageURL = extractor.extractOpenGraphImage(from: html) {
                let absoluteURL = makeAbsoluteURL(ogImageURL, baseURL: url)
                return ImageResult(imageURL: absoluteURL)
            }
            
            // Try Twitter Card
            if let twitterImageURL = extractor.extractTwitterCardImage(from: html) {
                let absoluteURL = makeAbsoluteURL(twitterImageURL, baseURL: url)
                return ImageResult(imageURL: absoluteURL)
            }
            
            // Try first significant image
            if let firstImageURL = extractor.extractFirstSignificantImage(from: html) {
                let absoluteURL = makeAbsoluteURL(firstImageURL, baseURL: url)
                return ImageResult(imageURL: absoluteURL)
            }
            
        } catch {
            print("WebImageExtractor - HTML extraction failed: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Screenshot Generation
    
    private func tryScreenshot(for url: URL) async -> ImageResult? {
        // WebScreenshotService needs to run on MainActor
        let screenshotService = await MainActor.run { WebScreenshotService() }
        let imageData = await screenshotService.generateScreenshot(for: url)
        
        if let imageData = imageData {
            return ImageResult(imageData: imageData)
        }
        
        return nil
    }
    
    // MARK: - Favicon Fallback
    
    private func getFaviconResult(for url: URL) -> ImageResult {
        guard let domain = url.host else {
            return ImageResult()
        }
        
        let faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=256"
        
        return ImageResult(imageURL: faviconURL)
    }
    
    // MARK: - Helpers
    
    private func makeAbsoluteURL(_ urlString: String, baseURL: URL) -> String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        return URL(string: urlString, relativeTo: baseURL)?.absoluteString ?? urlString
    }
}

