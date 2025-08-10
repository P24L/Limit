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

