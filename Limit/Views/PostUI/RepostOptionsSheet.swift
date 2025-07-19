//
//  RepostOptionsSheet.swift
//  Limit
//
//  Created by Assistant on 19.07.2025.
//

import SwiftUI
import AppRouter

struct RepostOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BlueskyClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    let post: TimelinePostWrapper
    
    @State private var isReposting = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)
            
            // Options
            VStack(spacing: 12) {
                // Repost button
                Button {
                    Task {
                        await performRepost()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.title2)
                            .foregroundColor(.mintAccent)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Repost")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Share this post with your followers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isReposting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .disabled(isReposting)
                
                // Quote button
                Button {
                    dismiss()
                    // Navigate to compose with quoted post
                    router.presentedSheet = .composePost(quotedPost: post)
                } label: {
                    HStack {
                        Image(systemName: "quote.bubble")
                            .font(.title2)
                            .foregroundColor(.mintAccent)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quote")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Add your thoughts to this post")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxHeight: 300)
        .background(Color(UIColor.systemBackground))
        .onTapGesture {
            // Prevent dismissing when tapping on the sheet content
        }
    }
    
    private func performRepost() async {
        isReposting = true
        errorMessage = nil
        
        await post.toggleRepost(using: client)
        
        // Add slight delay for better UX
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        
        dismiss()
    }
}

#Preview {
    RepostOptionsSheet(post: SampleData.shared.makeOneSamplePostWrapper())
        .environment(BlueskyClient.preview())
        .environment(AppRouter(initialTab: .timeline))
}