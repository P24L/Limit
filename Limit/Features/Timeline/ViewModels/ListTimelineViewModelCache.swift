//
//  ListTimelineViewModelCache.swift
//  Limit
//
//  Created by Codex on 15.06.2025.
//

import SwiftUI
import ATProtoKit

@MainActor
final class ListTimelineViewModelCache: ObservableObject {
    private var cache: [TimelineContentSource: ListTimelineViewModel] = [:]

    func viewModel(for source: TimelineContentSource,
                   client: MultiAccountClient,
                   accountDID: String?) -> ListTimelineViewModel {
        if let existing = cache[source] {
            existing.updateClient(client)
            existing.updateSource(source)
            return existing
        }

        let viewModel = ListTimelineViewModel(
            source: source,
            client: client,
            accountDID: accountDID
        )
        cache[source] = viewModel
        return viewModel
    }

    func removeAll() {
        cache.removeAll()
    }

    func pruneSources(notIn validSources: Set<TimelineContentSource>) {
        cache = cache.filter { validSources.contains($0.key) }
    }
}
