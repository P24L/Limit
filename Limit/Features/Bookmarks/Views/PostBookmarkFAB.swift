//
//  PostBookmarkFAB.swift
//  Limit
//
//  Created by Assistant on 10.08.2025.
//

import SwiftUI

struct PostBookmarkFAB: View {
    @Binding var isPresented: Bool
    @Environment(AppRouter.self) private var router
    @State private var buttonsVisible = false
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(buttonsVisible ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }
                .animation(.easeInOut(duration: 0.2), value: buttonsVisible)
            
            // FAB buttons
            VStack {
                Spacer()
                
                // Container with background
                HStack(spacing: 30) {
                    // Post button
                    Button {
                        dismissOverlay()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            router.presentedSheet = .composePost()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.mintAccent)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 24))
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
                        dismissOverlay()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            router.presentedSheet = .bookmarkEdit(id: nil)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 24))
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
                .padding(.horizontal, 25)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.cardBackground)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                )
                .scaleEffect(buttonsVisible ? 1 : 0.5)
                .opacity(buttonsVisible ? 1 : 0)
                .padding(.bottom, 50) // Closer to tab bar
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: buttonsVisible)
            }
        }
        .onAppear {
            // Animate buttons appearing
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.05)) {
                buttonsVisible = true
            }
        }
    }
    
    private func dismissOverlay() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            buttonsVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

#Preview {
    @State var showFAB = true
    
    return ZStack {
        Color.gray.ignoresSafeArea()
        
        PostBookmarkFAB(isPresented: $showFAB)
    }
}