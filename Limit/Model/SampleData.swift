//
//  SampleData.swift
//  Limit
//
//  Created by Zdenek Indra on 18.05.2025.
//

import Foundation
import SwiftData

@MainActor
final class SampleData {
    static var shared = SampleData()
    let modelContainer: ModelContainer
    
    var context: ModelContext {
        modelContainer.mainContext
    }
    
    init() {
        let modelConfiguration = ModelConfiguration(schema: Schema(AppSchema.allModels), isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: Schema(AppSchema.allModels), configurations: [modelConfiguration])
            for favURL in makeFiveSampleFavoriteURLs() {
                context.insert(favURL)
            }
            try context.save()
        } catch {
            fatalError("Could not initiate modelContainer, error: \(error)")
        }
    }

    public func makeOneSamplePostWrapper() -> TimelinePostWrapper {
        let uri = UUID().uuidString
        return TimelinePostWrapper(
            uri: uri,
            cid: UUID().uuidString,
            createdAt: Date(),
            type: .post,
            authorID: "sample.user",
            authorHandle: "sample.user",
            authorDisplayName: "Sample User",
            authorAvatarURL: nil,
            text: "This is a sample post for testing purposes. It contains some sample text to demonstrate the app functionality.",
            likeCount: 42,
            replyCount: 7,
            repostCount: 5,
            quoteCount: 0
        )
    }

    public func makeFiveSamplePostWrappers() -> [TimelinePostWrapper] {
        return (0..<5).map { _ in makeOneSamplePostWrapper() }
    }
    
    public func makeSampleFavoriteURL() -> FavoriteURL {
        let favURL = FavoriteURL(url: URL(string: "https://www.example.com")!, title: "Example.com")
        return favURL
    }
    
    public func makeFiveSampleFavoriteURLs() -> [FavoriteURL] {
        let sample1 = FavoriteURL(url: URL(string: "https://www.example.com")!, title: "Example.com")
        let sample2 = FavoriteURL(url: URL(string: "https://www.google.com")!, title: "Google.com")
        let sample3 = FavoriteURL(url: URL(string: "https://www.techcrunch.com")!, title: "TechCrunch")
        let sample4 = FavoriteURL(url: URL(string: "https://www.techmeme.com/djfds/fdsfa")!)
        let sample5 = FavoriteURL(url: URL(string: "https://www.invalidurl.com/ahoj")!, title: "Invalid URL")
        
        return [sample1, sample2, sample3, sample4, sample5]
    }
}
