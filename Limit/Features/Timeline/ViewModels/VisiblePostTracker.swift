//
//  VisiblePostTracker.swift
//  Limit
//
//  Created by Zdenek Indra on 11.07.2025.
//

import Foundation

struct VisiblePostTracker {
    private var visibleIDs: Set<String> = []

    mutating func add(_ id: String) {
        visibleIDs.insert(id)
    }

    mutating func remove(_ id: String) {
        visibleIDs.remove(id)
    }

    func topVisibleID(using indexMap: [String: Int]) -> String? {
        var bestMatch: (id: String, index: Int)?
        for id in visibleIDs {
            guard let index = indexMap[id] else { continue }
            if let current = bestMatch {
                if index < current.index {
                    bestMatch = (id, index)
                }
            } else {
                bestMatch = (id, index)
            }
        }
        return bestMatch?.id
    }

    mutating func reset(with initialID: String?) {
        visibleIDs.removeAll()
        if let initialID {
            visibleIDs = [initialID]
        }
    }
}
