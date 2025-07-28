//
//  MentionSuggestionsView.swift
//  Limit
//
//  Created by Assistant on 28.07.2025.
//

import SwiftUI

struct MentionSuggestionsView: View {
    let suggestions: [HandleSuggestion]
    let isLoading: Bool
    let onSelect: (HandleSuggestion) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading && suggestions.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            } else if !suggestions.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.element.handle) { index, suggestion in
                                MentionSuggestionRow(
                                    suggestion: suggestion,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    onSelect(suggestion)
                                }
                                
                                if index < suggestions.count - 1 {
                                    Divider()
                                        .padding(.leading, 50)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(suggestions.count) * 50, 200))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .onTapGesture {
            // Prevent dismissal when tapping inside
        }
        .background(
            // Invisible background to detect outside taps
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }
                .allowsHitTesting(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Keyboard Navigation Support
    
    func selectPrevious() {
        selectedIndex = max(0, selectedIndex - 1)
    }
    
    func selectNext() {
        selectedIndex = min(suggestions.count - 1, selectedIndex + 1)
    }
    
    func confirmSelection() {
        if selectedIndex < suggestions.count {
            onSelect(suggestions[selectedIndex])
        }
    }
}

// MARK: - Suggestion Row

struct MentionSuggestionRow: View {
    let suggestion: HandleSuggestion
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            Group {
                if let avatarURL = suggestion.avatarURL {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(String(suggestion.handle.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                if let displayName = suggestion.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Text("@\(suggestion.handle)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color(.systemGray5) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Position Calculation Extension

extension View {
    func positionedMentionSuggestions(
        isShowing: Binding<Bool>,
        suggestions: [HandleSuggestion],
        isLoading: Bool,
        cursorFrame: CGRect,
        textViewBounds: CGRect,
        onSelect: @escaping (HandleSuggestion) -> Void
    ) -> some View {
        self.overlay(
            Group {
                if isShowing.wrappedValue && (!suggestions.isEmpty || isLoading) {
                    MentionSuggestionsView(
                        suggestions: suggestions,
                        isLoading: isLoading,
                        onSelect: { suggestion in
                            onSelect(suggestion)
                            isShowing.wrappedValue = false
                        },
                        onDismiss: {
                            isShowing.wrappedValue = false
                        }
                    )
                    .frame(width: min(textViewBounds.width - 40, 300))
                    .position(
                        x: min(
                            max(cursorFrame.midX, 150),
                            textViewBounds.width - 150
                        ),
                        y: cursorFrame.maxY + 20
                    )
                    .zIndex(1000)
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        MentionSuggestionsView(
            suggestions: [
                HandleSuggestion(
                    did: "did:example:1",
                    handle: "alice.bsky.social",
                    displayName: "Alice",
                    avatarURL: nil
                ),
                HandleSuggestion(
                    did: "did:example:2",
                    handle: "bob.bsky.social",
                    displayName: "Bob Smith",
                    avatarURL: nil
                ),
                HandleSuggestion(
                    did: "did:example:3",
                    handle: "charlie.bsky.social",
                    displayName: nil,
                    avatarURL: nil
                )
            ],
            isLoading: false,
            onSelect: { _ in },
            onDismiss: { }
        )
        .frame(width: 300)
    }
}