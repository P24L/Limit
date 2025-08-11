//
//  PostBookmarkOverlay.swift
//  Limit
//
//  Created by Assistant on 06.01.2025.
//

import SwiftUI

struct PostBookmarkOverlay: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                // Post button
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        router.presentedSheet = .composePost()
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.mintAccent)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        
                        Text("Post")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                
                // Bookmark button
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        router.presentedSheet = .bookmarkEdit(id: nil)
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        
                        Text("Bookmark")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            
            // Tap outside to dismiss
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.001))
        .onTapGesture {
            dismiss()
        }
    }
}

#Preview {
    PostBookmarkOverlay()
        .background(Color.gray)
}