# WebImageExtractor

A Swift package for extracting the best available image from web pages for iOS apps.

## Features

- Multiple extraction strategies with automatic fallback
- Prefers image URLs over data to save memory and storage
- Automatic image optimization (under 480KB)
- Support for Open Graph and Twitter Card metadata
- Screenshot generation as fallback
- Google Favicon API integration

## Usage

```swift
import WebImageExtractor

let extractor = WebImageExtractor()
let result = await extractor.fetchBestImage(for: url)

if let imageURL = result.imageURL {
    // Preferred: Use the URL directly
    // Load asynchronously with SDWebImage or similar
} else if let imageData = result.imageData {
    // Fallback: Use the actual image data
    let image = UIImage(data: imageData)
}
```

## Extraction Hierarchy

1. **LinkPresentation Framework** - Fast metadata extraction
2. **HTML Parsing** - Open Graph, Twitter Cards, first significant image
3. **Screenshot Generation** - WKWebView snapshot
4. **Favicon Fallback** - Google Favicon Service

## Requirements

- iOS 18.4+
- Swift 6.0+
- SwiftSoup for HTML parsing