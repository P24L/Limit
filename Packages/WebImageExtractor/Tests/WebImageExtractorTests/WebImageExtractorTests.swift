import XCTest
@testable import WebImageExtractor

final class WebImageExtractorTests: XCTestCase {
    
    func testImageResultInitialization() throws {
        let result1 = WebImageExtractor.ImageResult(imageURL: "https://example.com/image.jpg")
        XCTAssertEqual(result1.imageURL, "https://example.com/image.jpg")
        XCTAssertNil(result1.imageData)
        
        let data = Data([0x1, 0x2, 0x3])
        let result2 = WebImageExtractor.ImageResult(imageData: data)
        XCTAssertNil(result2.imageURL)
        XCTAssertEqual(result2.imageData, data)
    }
    
    func testArrayChunking() throws {
        let array = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        let chunked = array.chunked(into: 3)
        
        XCTAssertEqual(chunked.count, 3)
        XCTAssertEqual(chunked[0], [1, 2, 3])
        XCTAssertEqual(chunked[1], [4, 5, 6])
        XCTAssertEqual(chunked[2], [7, 8, 9])
    }
}