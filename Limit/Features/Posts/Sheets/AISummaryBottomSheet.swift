//
//  AISummaryBottomSheet.swift
//  Limit
//
//  Created by Zdenek Indra on 07.07.2025.
//

import AppRouter
import SwiftUI

struct AISummaryBottomSheet: View {
    @Environment(AppRouter.self) private var router
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(ThemeManager.self) private var themeManager
    
    let bookmark: BookmarkView
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        let colors = themeManager.colors
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(colors.backgroundSecondary.opacity(0.6))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with close button
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(colors.accent)
                            
                            Text("AI Summary")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colors.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button {
                            router.presentedSheet = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // URL Info section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bookmark.record.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(colors.textPrimary)
                        
                        Text(bookmark.record.url)
                            .font(.caption)
                            .foregroundColor(colors.textSecondary)
                            .lineLimit(2)
                    }
                    .onTapGesture {
                        router.presentedSheet = nil
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                            if let url = URL(string: bookmark.record.url) {
                                router.navigateTo(.safari(url: url))
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // AI Summary section
                    VStack(alignment: .leading, spacing: 12) {
                        if let summary = bookmark.record.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.subheadline)
                                .textSelection(.enabled)
                                .padding(12)
                                .background(colors.accent.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(colors.accent.opacity(0.25), lineWidth: 1)
                                )
                            
                            if let updatedAt = bookmark.record.updatedAt {
                                Text("Generated \(updatedAt, style: .relative) ago")
                                    .font(.caption2)
                                    .foregroundColor(colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        } else {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Generating summary...")
                                    .foregroundColor(colors.textSecondary)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(colors.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        router.presentedSheet = nil
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
    }
}
