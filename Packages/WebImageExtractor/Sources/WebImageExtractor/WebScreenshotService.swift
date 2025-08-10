import Foundation
import WebKit
import UIKit

@MainActor
class WebScreenshotService {
    
    func generateScreenshot(for url: URL, size: CGSize = CGSize(width: 1200, height: 630)) async -> Data? {
        await withCheckedContinuation { continuation in
            let webView = WKWebView(frame: CGRect(origin: .zero, size: size))
            
            let delegate = ScreenshotDelegate { webView in
                let config = WKSnapshotConfiguration()
                config.rect = CGRect(origin: .zero, size: size)
                
                webView.takeSnapshot(with: config) { image, error in
                    if let image = image,
                       let optimized = ImageOptimizer.optimize(image, maxSizeKB: 480) {
                        continuation.resume(returning: optimized)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            
            webView.navigationDelegate = delegate
            webView.load(URLRequest(url: url))
            
            // Timeout after 10 seconds
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                continuation.resume(returning: nil)
            }
        }
    }
}

private class ScreenshotDelegate: NSObject, WKNavigationDelegate {
    let completion: (WKWebView) -> Void
    private var hasCompleted = false
    
    init(completion: @escaping (WKWebView) -> Void) {
        self.completion = completion
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        // Wait for images to load
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            self.completion(webView)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(webView)
    }
}