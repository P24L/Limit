//
//  BookmarkModels.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import Foundation
import SwiftData

enum SyncStatus: String, Codable {
    case synced = "synced"
    case pending = "pending"
    case syncing = "syncing"
    case failed = "failed"
}

enum ProcessingStatus: String, Codable {
    case pending = "pending"
    case processingImage = "processingImage"
    case processingDescription = "processingDescription"
    case completed = "completed"
    case failed = "failed"
}

@Model
final class CachedBookmark {
    @Attribute(.unique) var uri: String
    var ownerDID: String
    var cid: String
    var url: String
    var title: String
    var descriptionText: String?
    var note: String?
    var imageUrl: String?
    var imageBlob: Data?
    var imageGenerated: Bool = false
    var tags: [String]?
    var listUris: [String]?
    var pinned: Bool = false
    var archived: Bool = false
    var reminderData: Data? // Encoded BookmarkReminder
    var sourceUri: String?
    var encrypted: Bool = false
    var createdAt: Date
    var updatedAt: Date?
    var syncStatus: SyncStatus
    var lastSynced: Date?
    var processingStatus: ProcessingStatus?
    
    init(
        uri: String,
        ownerDID: String,
        cid: String,
        url: String,
        title: String,
        createdAt: Date
    ) {
        self.uri = uri
        self.ownerDID = ownerDID
        self.cid = cid
        self.url = url
        self.title = title
        self.createdAt = createdAt
        self.syncStatus = .synced
    }
    
    var reminder: BookmarkReminder? {
        get {
            guard let data = reminderData else { return nil }
            return try? JSONDecoder().decode(BookmarkReminder.self, from: data)
        }
        set {
            reminderData = try? JSONEncoder().encode(newValue)
        }
    }
}

@Model
final class CachedBookmarkList {
    @Attribute(.unique) var uri: String
    var ownerDID: String
    var cid: String
    var name: String
    var visibility: String
    var descriptionText: String?
    var color: String?
    var icon: String?
    var pinned: Bool = false
    var createdAt: Date
    var updatedAt: Date?
    var syncStatus: SyncStatus
    var lastSynced: Date?
    
    init(
        uri: String,
        ownerDID: String,
        cid: String,
        name: String,
        visibility: String,
        createdAt: Date
    ) {
        self.uri = uri
        self.ownerDID = ownerDID
        self.cid = cid
        self.name = name
        self.visibility = visibility
        self.createdAt = createdAt
        self.syncStatus = .synced
    }
}

struct BookmarkReminder: Codable {
    let date: Date
    let note: String?
}