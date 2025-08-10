// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebImageExtractor",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "WebImageExtractor",
            targets: ["WebImageExtractor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.9.6")
    ],
    targets: [
        .target(
            name: "WebImageExtractor",
            dependencies: ["SwiftSoup"]),
        .testTarget(
            name: "WebImageExtractorTests",
            dependencies: ["WebImageExtractor"]),
    ]
)
