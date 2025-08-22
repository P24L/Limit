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
    @Environment(MultiAccountClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    let post: TimelinePostWrapper
    
    @State private var isReposting = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    
    private var isOwnPost: Bool {
        post.authorHandle == client.handle || post.authorID == client.currentDID
    }
    
    private var isRepostedByMe: Bool {
        post.repostedByHandle == client.handle || post.repostedByID == client.currentDID
    }
    
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
                // First button - Repost/Undo Repost/Delete Post
                if isOwnPost {
                    // Delete Post button for own posts
                    Button {
                        Task {
                            await performDelete()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Delete Post")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("This action cannot be undone")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isDeleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isDeleting)
                } else if post.isReposted || isRepostedByMe {
                    // Undo Repost button
                    Button {
                        Task {
                            await performUndoRepost()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.2.squarepath")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Undo Repost")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Remove your repost of this post")
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
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isReposting)
                } else {
                    // Normal Repost button
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
                }
                
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
    
    private func performUndoRepost() async {
        isReposting = true
        errorMessage = nil
        
        // toggleRepost will undo if already reposted
        await post.toggleRepost(using: client)
        
        // Add slight delay for better UX
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        
        dismiss()
    }
    
    private func performDelete() async {
        isDeleting = true
        errorMessage = nil
        
        let success = await client.deletePost(uri: post.uri)
        
        if success {
            // Add slight delay for better UX
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            dismiss()
        } else {
            errorMessage = "Failed to delete post"
            isDeleting = false
        }
    }
}