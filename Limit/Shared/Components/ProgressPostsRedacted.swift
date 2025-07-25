//
//  ProgressPostsRedacted.swift
//  Limit
//
//  Created by Zdenek Indra on 02.06.2025.
//

import SwiftUI


struct ProgressPostsRedacted: View {
    let posts: [TimelinePostWrapper] = SampleData.shared.makeFiveSamplePostWrappers()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(posts, id: \.id) { post in
                PostItemWrappedView(post: post)
                    .redacted(reason: .placeholder)
                    .allowsHitTesting(false)
            }
        }
    }
}
