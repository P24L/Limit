//
//  FavoritesConfiguration.swift
//  Limit
//
//  Created by Claude on 20.07.2025.
//

import Foundation
import SwiftData

enum FavoritesSchema {
    static let allModels: [any PersistentModel.Type] = [
        FavoriteURL.self,
        FavoritePost.self
    ]
}