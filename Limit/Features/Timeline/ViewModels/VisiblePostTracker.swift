//
//  VisiblePostTracker.swift
//  Limit
//
//  Created by Zdenek Indra on 11.07.2025.
//

import Foundation

struct VisiblePostTracker {
    private var orderedIDs: [String] = []
    private var idSet: Set<String> = []

    mutating func add(_ id: String) {
        guard !idSet.contains(id) else { return }
        orderedIDs.insert(id, at: 0)
        idSet.insert(id)
    }

    mutating func remove(_ id: String) {
        guard idSet.contains(id) else { return }
        idSet.remove(id)
        orderedIDs.removeAll { $0 == id }
    }

    var topVisibleID: String? {
        orderedIDs.first
    }

    mutating func reset(with initialID: String?) {
        orderedIDs.removeAll()
        idSet.removeAll()
        if let initialID {
            orderedIDs = [initialID]
            idSet = [initialID]
        }
    }
}
