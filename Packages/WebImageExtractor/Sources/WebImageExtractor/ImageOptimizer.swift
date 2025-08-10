import UIKit

public struct ImageOptimizer {
    
    public static func optimize(_ image: UIImage, maxSizeKB: Int) -> Data? {
        // Start with reasonable quality
        var quality: CGFloat = 0.8
        var imageData = image.jpegData(compressionQuality: quality)
        
        // If already under limit, return
        if let data = imageData, data.count <= maxSizeKB * 1024 {
            return data
        }
        
        // Try reducing quality first
        while quality > 0.3 {
            quality -= 0.1
            imageData = image.jpegData(compressionQuality: quality)
            
            if let data = imageData, data.count <= maxSizeKB * 1024 {
                return data
            }
        }
        
        // If still too large, resize
        let targetSize = calculateTargetSize(for: image, maxDataSize: maxSizeKB * 1024)
        if let resized = resize(image, to: targetSize) {
            return resized.jpegData(compressionQuality: 0.7)
        }
        
        return nil
    }
    
    private static func calculateTargetSize(for image: UIImage, maxDataSize: Int) -> CGSize {
        let currentSize = image.size
        let currentPixels = currentSize.width * currentSize.height
        
        // Estimate compression ratio (rough approximation)
        let bytesPerPixel: CGFloat = 0.3
        let targetPixels = CGFloat(maxDataSize) / bytesPerPixel
        
        let scale = sqrt(targetPixels / currentPixels)
        
        return CGSize(
            width: currentSize.width * scale,
            height: currentSize.height * scale
        )
    }
    
    private static func resize(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}