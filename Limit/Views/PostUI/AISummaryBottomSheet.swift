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
    
    let favoriteURL: FavoriteURL
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(.tertiary)
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
                                .foregroundStyle(.blue)
                            
                            Text("AI Summary")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Button {
                            router.presentedSheet = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // URL Info section
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = favoriteURL.title {
                            Text(title)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Text(favoriteURL.url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .onTapGesture {
                        router.presentedSheet = nil
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                            router.navigateTo(.safari(url: favoriteURL.url))
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // AI Summary section
                    VStack(alignment: .leading, spacing: 12) {
                        
                        if favoriteURL.safeSummaryStatus == .processing {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Generating summary...")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            
                        } else if favoriteURL.safeSummaryStatus == .failed {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.orange)
                                
                                Text("Unable to generate summary")
                                    .fontWeight(.semibold)
                                    .font(.subheadline)
                                
                                if let error = favoriteURL.summaryError {
                                    Text(error)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                
                                // Retry functionality to be implemented if needed
                                // if favoriteURL.canRetrySummarization {
                                //     Button("Try Again") {
                                //         Task {
                                //             // Retry functionality
                                //         }
                                //     }
                                //     .buttonStyle(.borderedProminent)
                                // }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            
                        } else if let summary = favoriteURL.summary, favoriteURL.safeSummaryStatus == .completed {
                            Text(summary)
                                .font(.subheadline)
                                .textSelection(.enabled)
                                .padding(12)
                                .background(.blue.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.blue.opacity(0.2), lineWidth: 1)
                                )
                            
                            if let genTime = favoriteURL.summaryGeneratedAt {
                                Text("Generated \(genTime.relativeFormatted) ago")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            
                        } else {
                            Text("Summary not available")
                                .foregroundStyle(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 16)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(.regularMaterial)
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

