//
//  TrendsView.swift
//  Limit
//
//  Created by Claude on 01.07.2025.
//

import SwiftUI
import ATProtoKit
import SDWebImageSwiftUI

struct TrendsView: View {
    @Environment(BlueskyClient.self) private var client
    
    @State private var trends: [AppBskyLexicon.Unspecced.TrendViewDefinition] = []
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading trends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack {
                    Text("Error loading trends")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadTrends()
                        }
                    }
                    .padding(.top)
                }
                .padding()
            } else if trends.isEmpty {
                Text("No trends available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(trends.enumerated()), id: \.element.topic) { index, trend in
                            TrendItemView(trend: trend, rank: index + 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .refreshable {
                    await loadTrends()
                }
            }
        }
        .task {
            await loadTrends()
        }
    }
    
    private func loadTrends() async {
        guard !isLoading else { return }
        guard client.isAuthenticated, let protoClient = client.protoClient else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await protoClient.getTrends(limit: 10)
            await MainActor.run {
                self.trends = response.trends
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
}

struct TrendItemView: View {
    let trend: AppBskyLexicon.Unspecced.TrendViewDefinition
    let rank: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Rank number
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 20, alignment: .leading)
            
            // 1st line
            VStack(alignment: .leading, spacing: 4) {
                // Trend name with hot indicator
                HStack {
                    Text(trend.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if trend.status == .hot {
                        Text("🔥")
                            .font(.caption)
                    }

                    // Category if available
                    if let category = trend.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    Text("\(trend.startedAt.relativeFormatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                }                
                
                // Post count and time
                HStack {                    
                    // Actors if available
                    if !trend.actors.isEmpty {
                        HStack {
                            ForEach(Array(trend.actors.prefix(3)), id: \.actorDID) { actor in
                                WebImage(url: actor.avatarImageURL) { phase in
                                    switch phase {
                                    case .empty:
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure:
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                }
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                            }
                            
                            if trend.actors.count > 3 {
                                Text("+\(trend.actors.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()

                    Text("\(formatPostCount(trend.postCount)) posts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }    
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatPostCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    TrendsView()
        .environment(BlueskyClient())
}