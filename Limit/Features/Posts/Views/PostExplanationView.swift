//
//  PostExplanationView.swift
//  Limit
//
//  Created by Zdenek Indra on 05.07.2025.
//

import AppRouter
import SwiftUI

struct PostExplanationView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AIService.self) private var aiService
    
    let postWrapper: TimelinePostWrapper
    
    @State private var explanation: String = ""
    @State private var hasError = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Post header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explain Post")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI analysis of this Bluesky post")
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Original post
                VStack(alignment: .leading, spacing: 12) {
                    Text("Original Post")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Author info
                        HStack {
                            AsyncImage(url: postWrapper.authorAvatarURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(.gray.opacity(0.3))
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(postWrapper.authorDisplayName ?? postWrapper.authorHandle)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                Text("@\(postWrapper.authorHandle)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        
                        // Post text
                        Text(postWrapper.text)
                            .padding()
                            .background(.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                
                Divider()
                
                // AI Explanation section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AI Explanation")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if aiService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if aiService.isLoading {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Analyzing post...")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        
                    } else if hasError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 24))
                                .foregroundStyle(.orange)
                            
                            Text("Unable to explain post")
                                .fontWeight(.semibold)
                            
                            if let error = aiService.lastError {
                                Text(error.localizedDescription)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button("Try Again") {
                                Task {
                                    await loadExplanation()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        
                    } else if !explanation.isEmpty {
                        Text(explanation)
                            .padding()
                            .background(.blue.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.blue.opacity(0.2), lineWidth: 1)
                            )
                        
                    } else {
                        Text("No explanation available")
                            .foregroundStyle(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .task {
            await loadExplanation()
        }
    }
    
    @MainActor
    private func loadExplanation() async {
        hasError = false
        explanation = ""
        
        do {
            explanation = try await aiService.explainPost(postWrapper)
        } catch {
            hasError = true
            print("Failed to load post explanation: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        PostExplanationView(postWrapper: SampleData.shared.makeOneSamplePostWrapper())
            .environment(AIService())
    }
}