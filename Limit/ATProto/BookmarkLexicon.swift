//
//  BookmarkLexicon.swift
//  Limit
//
//  Created by Assistant on 22.07.2025.
//

import Foundation
import ATProtoKit

// MARK: - Bookmark Record Types

/// Represents app.hyper-limit.bookmark
public struct BookmarkRecord: ATRecordProtocol {
    public static let type = "app.hyper-limit.bookmark"
    
    // Required fields
    public let url: String
    public let title: String
    public let createdAt: Date
    
    // Optional fields
    public let description: String?
    public let note: String?
    public let imageUrl: String?
    public let imageBlob: ComAtprotoLexicon.Repository.BlobContainer?
    public let tags: [String]?
    public let listUris: [String]?
    public let pinned: Bool?
    public let archived: Bool?
    public let reminder: BookmarkReminder?
    public let sourceUri: String?
    public let encrypted: Bool?
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case url, title, createdAt
        case description, note, imageUrl, imageBlob
        case tags, listUris, pinned, archived
        case reminder, sourceUri, encrypted, updatedAt
    }
    
    public init(
        url: String,
        title: String,
        createdAt: Date = Date(),
        description: String? = nil,
        note: String? = nil,
        imageUrl: String? = nil,
        imageBlob: ComAtprotoLexicon.Repository.BlobContainer? = nil,
        tags: [String]? = nil,
        listUris: [String]? = nil,
        pinned: Bool? = false,
        archived: Bool? = false,
        reminder: BookmarkReminder? = nil,
        sourceUri: String? = nil,
        encrypted: Bool? = false,
        updatedAt: Date? = nil
    ) {
        self.url = url
        self.title = title
        self.createdAt = createdAt
        self.description = description
        self.note = note
        self.imageUrl = imageUrl
        self.imageBlob = imageBlob
        self.tags = tags
        self.listUris = listUris
        self.pinned = pinned
        self.archived = archived
        self.reminder = reminder
        self.sourceUri = sourceUri
        self.encrypted = encrypted
        self.updatedAt = updatedAt
    }
    
    // MARK: - Decodable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.url = try container.decode(String.self, forKey: .url)
        self.title = try container.decode(String.self, forKey: .title)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        self.imageBlob = try container.decodeIfPresent(ComAtprotoLexicon.Repository.BlobContainer.self, forKey: .imageBlob)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.listUris = try container.decodeIfPresent([String].self, forKey: .listUris)
        self.pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned)
        self.archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        self.reminder = try container.decodeIfPresent(BookmarkReminder.self, forKey: .reminder)
        self.sourceUri = try container.decodeIfPresent(String.self, forKey: .sourceUri)
        self.encrypted = try container.decodeIfPresent(Bool.self, forKey: .encrypted)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    // MARK: - Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(Self.type, forKey: .type)
        try container.encode(url, forKey: .url)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(imageBlob, forKey: .imageBlob)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(listUris, forKey: .listUris)
        try container.encodeIfPresent(pinned, forKey: .pinned)
        try container.encodeIfPresent(archived, forKey: .archived)
        try container.encodeIfPresent(reminder, forKey: .reminder)
        try container.encodeIfPresent(sourceUri, forKey: .sourceUri)
        try container.encodeIfPresent(encrypted, forKey: .encrypted)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

/// Reminder structure for bookmarks
public struct BookmarkReminder: Codable, Sendable, Equatable, Hashable {
    public let date: Date
    public let note: String?
    
    public init(date: Date, note: String? = nil) {
        self.date = date
        self.note = note
    }
}

/// Represents app.hyper-limit.bookmark.list
public struct BookmarkListRecord: ATRecordProtocol {
    public static let type = "app.hyper-limit.bookmark.list"
    
    // Required fields
    public let name: String
    public let visibility: BookmarkListVisibility
    public let createdAt: Date
    
    // Optional fields
    public let description: String?
    public let color: String?
    public let icon: BookmarkListIcon?
    public let coverImage: ComAtprotoLexicon.Repository.BlobContainer?
    public let parent: String?
    public let permissions: BookmarkListPermissions?
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case name, visibility, createdAt
        case description, color, icon, coverImage
        case parent, permissions, updatedAt
    }
    
    public init(
        name: String,
        visibility: BookmarkListVisibility,
        createdAt: Date = Date(),
        description: String? = nil,
        color: String? = nil,
        icon: BookmarkListIcon? = .folder,
        coverImage: ComAtprotoLexicon.Repository.BlobContainer? = nil,
        parent: String? = nil,
        permissions: BookmarkListPermissions? = nil,
        updatedAt: Date? = nil
    ) {
        self.name = name
        self.visibility = visibility
        self.createdAt = createdAt
        self.description = description
        self.color = color
        self.icon = icon
        self.coverImage = coverImage
        self.parent = parent
        self.permissions = permissions
        self.updatedAt = updatedAt
    }
    
    // MARK: - Decodable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decode(String.self, forKey: .name)
        self.visibility = try container.decode(BookmarkListVisibility.self, forKey: .visibility)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.icon = try container.decodeIfPresent(BookmarkListIcon.self, forKey: .icon)
        self.coverImage = try container.decodeIfPresent(ComAtprotoLexicon.Repository.BlobContainer.self, forKey: .coverImage)
        self.parent = try container.decodeIfPresent(String.self, forKey: .parent)
        self.permissions = try container.decodeIfPresent(BookmarkListPermissions.self, forKey: .permissions)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    // MARK: - Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(Self.type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(createdAt, forKey: .createdAt)
        
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(coverImage, forKey: .coverImage)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encodeIfPresent(permissions, forKey: .permissions)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

/// List visibility options
public enum BookmarkListVisibility: String, Codable, Sendable {
    case `private` = "private"
    case collaborative = "collaborative"
    case `public` = "public"
}

/// List icon options
public enum BookmarkListIcon: String, Codable, Sendable {
    case folder = "folder"
    case list = "list"
    case star = "star"
    case tag = "tag"
}

/// Permissions for bookmark lists
public struct BookmarkListPermissions: Codable, Sendable, Equatable, Hashable {
    public let canAdd: [String]? // Array of DIDs
    
    public init(canAdd: [String]? = nil) {
        self.canAdd = canAdd
    }
}

/// Represents app.hyper-limit.bookmark.embed
public struct BookmarkEmbed: Codable, Sendable, Equatable, Hashable {
    public let type: String = "app.hyper-limit.bookmark.embed"
    public let bookmark: ComAtprotoLexicon.Repository.StrongReference
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case bookmark
    }
    
    public init(bookmark: ComAtprotoLexicon.Repository.StrongReference) {
        self.bookmark = bookmark
    }
}

// MARK: - API Response Models

/// Combined bookmark record with metadata
public struct BookmarkView: Codable, Sendable {
    public let uri: String
    public let cid: String
    public let record: BookmarkRecord
    public let author: String // DID
    public let indexedAt: Date?
    
    public init(
        uri: String,
        cid: String,
        record: BookmarkRecord,
        author: String,
        indexedAt: Date? = nil
    ) {
        self.uri = uri
        self.cid = cid
        self.record = record
        self.author = author
        self.indexedAt = indexedAt
    }
}

/// Combined list record with metadata
public struct BookmarkListView: Codable, Sendable, Identifiable {
    public var id: String { uri }
    public let uri: String
    public let cid: String
    public let record: BookmarkListRecord
    public let bookmarkCount: Int?
    
    public init(
        uri: String,
        cid: String,
        record: BookmarkListRecord,
        bookmarkCount: Int? = nil
    ) {
        self.uri = uri
        self.cid = cid
        self.record = record
        self.bookmarkCount = bookmarkCount
    }
}

/// Response for fetching bookmark lists
public struct GetBookmarkListsOutput: Codable, Sendable {
    public let lists: [BookmarkListView]
    public let cursor: String?
    
    public init(lists: [BookmarkListView], cursor: String? = nil) {
        self.lists = lists
        self.cursor = cursor
    }
}

/// Response for fetching bookmarks
public struct GetBookmarksOutput: Codable, Sendable {
    public let bookmarks: [BookmarkView]
    public let cursor: String?
    
    public init(bookmarks: [BookmarkView], cursor: String? = nil) {
        self.bookmarks = bookmarks
        self.cursor = cursor
    }
}

// MARK: - ATProtoKit Extensions

extension ATProtoKit {
    
    // MARK: Bookmark CRUD Operations
    
    /// Creates a new bookmark
    public func createBookmark(
        url: String,
        title: String,
        description: String? = nil,
        note: String? = nil,
        imageUrl: String? = nil,
        imageBlob: ComAtprotoLexicon.Repository.BlobContainer? = nil,
        tags: [String]? = nil,
        listUris: [String]? = nil,
        pinned: Bool = false,
        archived: Bool = false,
        reminder: BookmarkReminder? = nil,
        sourceUri: String? = nil,
        encrypted: Bool = false
    ) async throws -> ComAtprotoLexicon.Repository.StrongReference {
        guard let session = try await getUserSession() else {
            throw ATRequestPrepareError.missingActiveSession
        }
        
        let record = BookmarkRecord(
            url: url,
            title: title,
            createdAt: Date(),
            description: description,
            note: note,
            imageUrl: imageUrl,
            imageBlob: imageBlob,
            tags: tags,
            listUris: listUris,
            pinned: pinned,
            archived: archived,
            reminder: reminder,
            sourceUri: sourceUri,
            encrypted: encrypted
        )
        
        let recordData = UnknownType.record(record)
        
        return try await createRecord(
            repositoryDID: session.sessionDID,
            collection: "app.hyper-limit.bookmark",
            shouldValidate: false, // Important for custom lexicons
            record: recordData
        )
    }
    
    /// Gets a specific bookmark
    public func getBookmark(
        repo: String,
        rkey: String
    ) async throws -> BookmarkView {
        guard let session = try await getUserSession(),
              let keychain = sessionConfiguration?.keychainProtocol else {
            throw ATRequestPrepareError.missingActiveSession
        }
        
        let accessToken = try await keychain.retrieveAccessToken()
        
        // Use the PDS URL from the session instead of the default public API URL
        let sessionPDSURL = session.pdsURL ?? pdsURL
        
        guard let requestURL = URL(string: "\(sessionPDSURL)/xrpc/com.atproto.repo.getRecord") else {
            throw ATRequestPrepareError.invalidRequestURL
        }
        
        var queryItems = [(String, String)]()
        queryItems.append(("repo", repo))
        queryItems.append(("collection", "app.hyper-limit.bookmark"))
        queryItems.append(("rkey", rkey))
        
        let queryURL = try apiClientService.setQueryItems(
            for: requestURL,
            with: queryItems
        )
        
        let request = apiClientService.createRequest(
            forRequest: queryURL,
            andMethod: .get,
            acceptValue: "application/json",
            contentTypeValue: nil,
            authorizationValue: "Bearer \(accessToken)"
        )
        
        let response = try await apiClientService.sendRequest(
            request,
            decodeTo: ComAtprotoLexicon.Repository.GetRecordOutput.self
        )
        
        // Extract the bookmark record
        guard let value = response.value,
              let bookmarkRecord = value.getRecord(ofType: BookmarkRecord.self) else {
            throw ATRequestPrepareError.invalidRecord
        }
        
        return BookmarkView(
            uri: response.uri,
            cid: response.cid,
            record: bookmarkRecord,
            author: repo
        )
    }
    
    /// Updates an existing bookmark
    public func updateBookmark(
        repo: String,
        rkey: String,
        updates: BookmarkUpdateInput
    ) async throws -> ComAtprotoLexicon.Repository.StrongReference {
        // First get the existing bookmark
        let existing = try await getBookmark(repo: repo, rkey: rkey)
        
        // Create updated record
        let updatedRecord = BookmarkRecord(
            url: updates.url ?? existing.record.url,
            title: updates.title ?? existing.record.title,
            createdAt: existing.record.createdAt,
            description: updates.description ?? existing.record.description,
            note: updates.note ?? existing.record.note,
            imageUrl: updates.imageUrl ?? existing.record.imageUrl,
            imageBlob: updates.imageBlob ?? existing.record.imageBlob,
            tags: updates.tags ?? existing.record.tags,
            listUris: updates.listUris ?? existing.record.listUris,
            pinned: updates.pinned ?? existing.record.pinned,
            archived: updates.archived ?? existing.record.archived,
            reminder: updates.reminder ?? existing.record.reminder,
            sourceUri: existing.record.sourceUri,
            encrypted: updates.encrypted ?? existing.record.encrypted,
            updatedAt: Date()
        )
        
        let recordData = UnknownType.record(updatedRecord)
        
        return try await putRecord(
            repository: repo,
            collection: "app.hyper-limit.bookmark",
            recordKey: rkey,
            shouldValidate: false,
            record: recordData,
            swapRecord: nil,
            swapCommit: nil
        )
    }
    
    /// Deletes a bookmark
    public func deleteBookmark(
        repo: String,
        rkey: String
    ) async throws {
        try await deleteRecord(
            repositoryDID: repo,
            collection: "app.hyper-limit.bookmark",
            recordKey: rkey
        )
    }
    
    // MARK: List Management Operations
    
    /// Creates a new bookmark list
    public func createBookmarkList(
        name: String,
        visibility: BookmarkListVisibility = .private,
        description: String? = nil,
        color: String? = nil,
        icon: BookmarkListIcon? = .folder,
        coverImage: ComAtprotoLexicon.Repository.BlobContainer? = nil,
        parent: String? = nil,
        permissions: BookmarkListPermissions? = nil
    ) async throws -> ComAtprotoLexicon.Repository.StrongReference {
        guard let session = try await getUserSession() else {
            throw ATRequestPrepareError.missingActiveSession
        }
        
        let record = BookmarkListRecord(
            name: name,
            visibility: visibility,
            createdAt: Date(),
            description: description,
            color: color,
            icon: icon,
            coverImage: coverImage,
            parent: parent,
            permissions: permissions
        )
        
        let recordData = UnknownType.record(record)
        
        do {
            let result = try await createRecord(
                repositoryDID: session.sessionDID,
                collection: "app.hyper-limit.bookmark.list",
                shouldValidate: false,
                record: recordData
            )
            
            DevLogger.shared.log("BookmarkLexicon - createBookmarkList - Success! URI: \(result.recordURI)")
            return result
        } catch {
            DevLogger.shared.log("BookmarkLexicon - createBookmarkList - Error: \(error)")
            throw error
        }
    }
    
    /// Gets bookmark lists for a user
    public func getBookmarkLists(
        actorDID: String? = nil,
        limit: Int? = 50,
        cursor: String? = nil
    ) async throws -> GetBookmarkListsOutput {
        guard let session = try await getUserSession(),
              let keychain = sessionConfiguration?.keychainProtocol else {
            throw ATRequestPrepareError.missingActiveSession
        }
        
        let accessToken = try await keychain.retrieveAccessToken()
        let targetDID = actorDID ?? session.sessionDID
        
        // Use the PDS URL from the session instead of the default public API URL
        let sessionPDSURL = session.pdsURL ?? pdsURL
        
        guard let requestURL = URL(string: "\(sessionPDSURL)/xrpc/com.atproto.repo.listRecords") else {
            throw ATRequestPrepareError.invalidRequestURL
        }
        
        var queryItems = [(String, String)]()
        queryItems.append(("repo", targetDID))
        queryItems.append(("collection", "app.hyper-limit.bookmark.list"))
        
        if let limit {
            let finalLimit = max(1, min(limit, 100))
            queryItems.append(("limit", "\(finalLimit)"))
        }
        
        if let cursor {
            queryItems.append(("cursor", cursor))
        }
        
        let queryURL = try apiClientService.setQueryItems(
            for: requestURL,
            with: queryItems
        )
        
        let request = apiClientService.createRequest(
            forRequest: queryURL,
            andMethod: .get,
            acceptValue: "application/json",
            contentTypeValue: nil,
            authorizationValue: "Bearer \(accessToken)"
        )
        
        do {
            let response = try await apiClientService.sendRequest(
                request,
                decodeTo: ComAtprotoLexicon.Repository.ListRecordsOutput.self
            )
        
            // Convert records to BookmarkListView
            let lists = response.records.compactMap { record -> BookmarkListView? in
                guard let value = record.value,
                      let listRecord = value.getRecord(ofType: BookmarkListRecord.self) else {
                    return nil
                }
                
                return BookmarkListView(
                    uri: record.uri,
                    cid: record.cid,
                    record: listRecord
                )
            }
            
            DevLogger.shared.log("BookmarkLexicon - getBookmarkLists - Found \(lists.count) lists")
            
            return GetBookmarkListsOutput(lists: lists, cursor: response.cursor)
        } catch {
            DevLogger.shared.log("BookmarkLexicon - getBookmarkLists - Error: \(error)")
            throw error
        }
    }
    
    /// Updates a bookmark list
    public func updateBookmarkList(
        repo: String,
        rkey: String,
        updates: BookmarkListUpdateInput
    ) async throws -> ComAtprotoLexicon.Repository.StrongReference {
        guard let session = try await getUserSession(),
              let keychain = sessionConfiguration?.keychainProtocol else {
            throw ATRequestPrepareError.missingActiveSession
        }
        
        // Use the PDS URL from the session instead of the default public API URL
        let sessionPDSURL = session.pdsURL ?? pdsURL
        
        // First get the existing list
        guard let requestURL = URL(string: "\(sessionPDSURL)/xrpc/com.atproto.repo.getRecord") else {
            throw ATRequestPrepareError.invalidRequestURL
        }
        
        let accessToken = try await keychain.retrieveAccessToken()
        
        var queryItems = [(String, String)]()
        queryItems.append(("repo", repo))
        queryItems.append(("collection", "app.hyper-limit.bookmark.list"))
        queryItems.append(("rkey", rkey))
        
        let queryURL = try apiClientService.setQueryItems(
            for: requestURL,
            with: queryItems
        )
        
        let request = apiClientService.createRequest(
            forRequest: queryURL,
            andMethod: .get,
            acceptValue: "application/json",
            contentTypeValue: nil,
            authorizationValue: "Bearer \(accessToken)"
        )
        
        let existingResponse = try await apiClientService.sendRequest(
            request,
            decodeTo: ComAtprotoLexicon.Repository.GetRecordOutput.self
        )
        
        guard let value = existingResponse.value,
              let existingRecord = value.getRecord(ofType: BookmarkListRecord.self) else {
            throw ATRequestPrepareError.invalidRecord
        }
        
        // Create updated record
        let updatedRecord = BookmarkListRecord(
            name: updates.name ?? existingRecord.name,
            visibility: updates.visibility ?? existingRecord.visibility,
            createdAt: existingRecord.createdAt,
            description: updates.description ?? existingRecord.description,
            color: updates.color ?? existingRecord.color,
            icon: updates.icon ?? existingRecord.icon,
            coverImage: updates.coverImage ?? existingRecord.coverImage,
            parent: updates.parent ?? existingRecord.parent,
            permissions: updates.permissions ?? existingRecord.permissions,
            updatedAt: Date()
        )
        
        let recordData = UnknownType.record(updatedRecord)
        
        return try await putRecord(
            repository: repo,
            collection: "app.hyper-limit.bookmark.list",
            recordKey: rkey,
            shouldValidate: false,
            record: recordData,
            swapRecord: nil,
            swapCommit: nil
        )
    }
    
    /// Deletes a bookmark list
    public func deleteBookmarkList(
        repo: String,
        rkey: String
    ) async throws {
        try await deleteRecord(
            repositoryDID: repo,
            collection: "app.hyper-limit.bookmark.list",
            recordKey: rkey
        )
    }
    
    /// Adds a bookmark to one or more lists
    public func addBookmarkToLists(
        bookmarkRepo: String,
        bookmarkRkey: String,
        listUris: [String]
    ) async throws {
        // Get the existing bookmark
        let bookmark = try await getBookmark(repo: bookmarkRepo, rkey: bookmarkRkey)
        
        // Merge list URIs
        var updatedListUris = bookmark.record.listUris ?? []
        for uri in listUris {
            if !updatedListUris.contains(uri) {
                updatedListUris.append(uri)
            }
        }
        
        // Update the bookmark
        _ = try await updateBookmark(
            repo: bookmarkRepo,
            rkey: bookmarkRkey,
            updates: BookmarkUpdateInput(listUris: updatedListUris)
        )
    }
    
    /// Removes a bookmark from a list
    public func removeBookmarkFromList(
        bookmarkRepo: String,
        bookmarkRkey: String,
        listUri: String
    ) async throws {
        // Get the existing bookmark
        let bookmark = try await getBookmark(repo: bookmarkRepo, rkey: bookmarkRkey)
        
        // Remove list URI
        var updatedListUris = bookmark.record.listUris ?? []
        updatedListUris.removeAll { $0 == listUri }
        
        // Update the bookmark
        _ = try await updateBookmark(
            repo: bookmarkRepo,
            rkey: bookmarkRkey,
            updates: BookmarkUpdateInput(listUris: updatedListUris)
        )
    }
    
    /// Gets bookmarks for a specific list
    public func getBookmarksInList(
        listUri: String,
        limit: Int? = 50,
        cursor: String? = nil
    ) async throws -> GetBookmarksOutput {
        guard let session = try await getUserSession(),
              let keychain = sessionConfiguration?.keychainProtocol else {
            throw ATRequestPrepareError.missingActiveSession
        }
        
        let accessToken = try await keychain.retrieveAccessToken()
        
        // Use the PDS URL from the session instead of the default public API URL
        let sessionPDSURL = session.pdsURL ?? pdsURL
        
        // For now, we'll get all bookmarks and filter client-side
        // In a real implementation, this would be a server-side query
        guard let requestURL = URL(string: "\(sessionPDSURL)/xrpc/com.atproto.repo.listRecords") else {
            throw ATRequestPrepareError.invalidRequestURL
        }
        
        var queryItems = [(String, String)]()
        queryItems.append(("repo", session.sessionDID))
        queryItems.append(("collection", "app.hyper-limit.bookmark"))
        
        if let limit {
            let finalLimit = max(1, min(limit, 100))
            queryItems.append(("limit", "\(finalLimit)"))
        }
        
        if let cursor {
            queryItems.append(("cursor", cursor))
        }
        
        let queryURL = try apiClientService.setQueryItems(
            for: requestURL,
            with: queryItems
        )
        
        let request = apiClientService.createRequest(
            forRequest: queryURL,
            andMethod: .get,
            acceptValue: "application/json",
            contentTypeValue: nil,
            authorizationValue: "Bearer \(accessToken)"
        )
        
        let response = try await apiClientService.sendRequest(
            request,
            decodeTo: ComAtprotoLexicon.Repository.ListRecordsOutput.self
        )
        
        // Filter bookmarks that belong to the specified list
        let bookmarks = response.records.compactMap { record -> BookmarkView? in
            guard let value = record.value,
                  let bookmarkRecord = value.getRecord(ofType: BookmarkRecord.self),
                  let listUris = bookmarkRecord.listUris,
                  listUris.contains(listUri) else {
                return nil
            }
            
            return BookmarkView(
                uri: record.uri,
                cid: record.cid,
                record: bookmarkRecord,
                author: session.sessionDID
            )
        }
        
        return GetBookmarksOutput(bookmarks: bookmarks, cursor: response.cursor)
    }
}

// MARK: - Update Input Types

/// Input for updating a bookmark
public struct BookmarkUpdateInput {
    public let url: String?
    public let title: String?
    public let description: String?
    public let note: String?
    public let imageUrl: String?
    public let imageBlob: ComAtprotoLexicon.Repository.BlobContainer?
    public let tags: [String]?
    public let listUris: [String]?
    public let pinned: Bool?
    public let archived: Bool?
    public let reminder: BookmarkReminder?
    public let encrypted: Bool?
    
    public init(
        url: String? = nil,
        title: String? = nil,
        description: String? = nil,
        note: String? = nil,
        imageUrl: String? = nil,
        imageBlob: ComAtprotoLexicon.Repository.BlobContainer? = nil,
        tags: [String]? = nil,
        listUris: [String]? = nil,
        pinned: Bool? = nil,
        archived: Bool? = nil,
        reminder: BookmarkReminder? = nil,
        encrypted: Bool? = nil
    ) {
        self.url = url
        self.title = title
        self.description = description
        self.note = note
        self.imageUrl = imageUrl
        self.imageBlob = imageBlob
        self.tags = tags
        self.listUris = listUris
        self.pinned = pinned
        self.archived = archived
        self.reminder = reminder
        self.encrypted = encrypted
    }
}

/// Input for updating a bookmark list
public struct BookmarkListUpdateInput {
    public let name: String?
    public let visibility: BookmarkListVisibility?
    public let description: String?
    public let color: String?
    public let icon: BookmarkListIcon?
    public let coverImage: ComAtprotoLexicon.Repository.BlobContainer?
    public let parent: String?
    public let permissions: BookmarkListPermissions?
    
    public init(
        name: String? = nil,
        visibility: BookmarkListVisibility? = nil,
        description: String? = nil,
        color: String? = nil,
        icon: BookmarkListIcon? = nil,
        coverImage: ComAtprotoLexicon.Repository.BlobContainer? = nil,
        parent: String? = nil,
        permissions: BookmarkListPermissions? = nil
    ) {
        self.name = name
        self.visibility = visibility
        self.description = description
        self.color = color
        self.icon = icon
        self.coverImage = coverImage
        self.parent = parent
        self.permissions = permissions
    }
}