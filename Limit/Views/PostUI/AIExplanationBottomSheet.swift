//
//  AIExplanationBottomSheet.swift
//  Limit
//
//  Created by Zdenek Indra on 05.07.2025.
//

import AppRouter
import SwiftUI

struct AIExplanationBottomSheet: View {
    @Environment(AppRouter.self) private var router
    @Environment(AIService.self) private var aiService
    
    let postWrapper: TimelinePostWrapper
    
    @State private var explanation: String = ""
    @State private var hasError = false
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
                        Text("AI Explanation")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if aiService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Button {
                            router.presentedSheet = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // AI Explanation section
                    VStack(alignment: .leading, spacing: 12) {
                        
                        if aiService.isLoading {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Analyzing post...")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            
                        } else if hasError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.orange)
                                
                                Text("Unable to explain post")
                                    .fontWeight(.semibold)
                                    .font(.subheadline)
                                
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
                            .padding(.vertical, 16)
                            
                        } else if !explanation.isEmpty {
                            Text(explanation)
                                .font(.subheadline)
                                .padding(12)
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
            DevLogger.shared.log("AIExplanationBottomSheet.swift - Failed to load post explanation: \(error)")
        }
    }
}

#Preview {
    AIExplanationBottomSheet(postWrapper: SampleData.shared.makeOneSamplePostWrapper())
        .environment(AIService())
}