//
//  BookmarkCacheConfiguration.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import Foundation
import SwiftData

enum BookmarkCacheSchema {
    static let allModels: [any PersistentModel.Type] = [
        CachedBookmark.self,
        CachedBookmarkList.self
    ]
}