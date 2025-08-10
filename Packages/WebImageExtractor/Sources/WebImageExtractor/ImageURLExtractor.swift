import Foundation
import SwiftSoup

class ImageURLExtractor {
    
    func extractOpenGraphImage(from html: String) -> String? {
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Try different Open Graph patterns
            let selectors = [
                "meta[property=og:image]",
                "meta[property='og:image']",
                "meta[property=\"og:image\"]"
            ]
            
            for selector in selectors {
                if let element = try doc.select(selector).first(),
                   let content = try? element.attr("content"),
                   !content.isEmpty {
                    return content
                }
            }
        } catch {
            print("ImageURLExtractor - SwiftSoup parsing failed: \(error)")
        }
        
        return nil
    }
    
    func extractTwitterCardImage(from html: String) -> String? {
        do {
            let doc = try SwiftSoup.parse(html)
            
            let selectors = [
                "meta[name=twitter:image]",
                "meta[name='twitter:image']",
                "meta[property=twitter:image]"
            ]
            
            for selector in selectors {
                if let element = try doc.select(selector).first(),
                   let content = try? element.attr("content"),
                   !content.isEmpty {
                    return content
                }
            }
        } catch { }
        
        return nil
    }
    
    func extractFirstSignificantImage(from html: String) -> String? {
        do {
            let doc = try SwiftSoup.parse(html)
            let images = try doc.select("img")
            
            // Skip common non-content patterns
            let skipPatterns = ["logo", "icon", "avatar", "pixel", "tracking", "ad", "button", "banner"]
            
            for img in images {
                guard let src = try? img.attr("src"), !src.isEmpty else { continue }
                
                let lowercased = src.lowercased()
                let shouldSkip = skipPatterns.contains { lowercased.contains($0) }
                
                if !shouldSkip {
                    // Check for size hints
                    let widthStr = (try? img.attr("width")) ?? ""
                    let heightStr = (try? img.attr("height")) ?? ""
                    let width = Int(widthStr) ?? 0
                    let height = Int(heightStr) ?? 0
                    
                    // Skip small images
                    if width > 0 && height > 0 && (width < 200 || height < 200) {
                        continue
                    }
                    
                    return src
                }
            }
        } catch { }
        
        return nil
    }
}