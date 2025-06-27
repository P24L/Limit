//
//  LimitConfiguration.swift
//  Limit
//
//  Created by Zdenek Indra on 18.05.2025.
//

import Foundation
import SwiftData

//let modelList: [any PersistentModel.Type] = [TimelinePost.self, UserProfile.self, PostImage.self, FavoriteURL.self, FavoritePost.self]
//let schema = Schema(modelList)


enum AppSchema {
    static let allModels: [any PersistentModel.Type] = [
        TimelinePost.self,
        PostImage.self,
        FavoriteURL.self,
        FavoritePost.self
    ]
}

let maxTimelineFetchLoops = 10
let maxPostsInTimeline = 1_000
