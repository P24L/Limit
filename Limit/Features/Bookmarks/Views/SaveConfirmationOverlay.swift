//
//  SaveConfirmationOverlay.swift
//  Limit
//
//  Created by Assistant on 06.01.2025.
//

import SwiftUI

struct SaveConfirmationOverlay: View {
    @Environment(AppRouter.self) private var router
    
    let bookmarkId: String?
    let onEdit: (() -> Void)?
    
    @State private var isVisible = true
    @State private var dismissTimer: Timer?
    
    init(bookmarkId: String? = nil, onEdit: (() -> Void)? = nil) {
        self.bookmarkId = bookmarkId
        self.onEdit = onEdit
    }
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                // Checkmark icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                // Saved text
                Text("Saved")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Edit button
                Button {
                    dismissTimer?.invalidate()
                    isVisible = false
                    
                    if let onEdit = onEdit {
                        onEdit()
                    } else {
                        router.presentedSheet = .bookmarkEdit(id: bookmarkId)
                    }
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.mintAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.cardBackground)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.cardBackground)
                            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                    )
            )
            .padding(.horizontal, 20)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .onAppear {
                startDismissTimer()
            }
            .onTapGesture {
                // Dismiss on tap
                dismissTimer?.invalidate()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = false
                }
            }
        }
    }
    
    private func startDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}

// MARK: - View Modifier for easier use

struct SaveConfirmationModifier: ViewModifier {
    @Binding var showConfirmation: Bool
    let bookmarkId: String?
    let text: String
    let icon: String
    let onEdit: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            
            if showConfirmation {
                CustomSaveConfirmationOverlay(
                    bookmarkId: bookmarkId,
                    text: text,
                    icon: icon,
                    onEdit: onEdit
                )
                .padding(.bottom, 50) // Closer to tab bar
                .onDisappear {
                    showConfirmation = false
                }
            }
        }
    }
}

struct CustomSaveConfirmationOverlay: View {
    @Environment(AppRouter.self) private var router
    
    let bookmarkId: String?
    let text: String
    let icon: String
    let onEdit: (() -> Void)?
    
    @State private var isVisible = true
    @State private var dismissTimer: Timer?
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                // Custom icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                // Custom text
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Edit button (only if bookmarkId or onEdit provided)
                if bookmarkId != nil || onEdit != nil {
                    Button {
                        dismissTimer?.invalidate()
                        isVisible = false
                        
                        if let onEdit = onEdit {
                            onEdit()
                        } else {
                            router.presentedSheet = .bookmarkEdit(id: bookmarkId)
                        }
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.mintAccent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.cardBackground)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.cardBackground)
                            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                    )
            )
            .padding(.horizontal, 20)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .onAppear {
                startDismissTimer()
            }
            .onTapGesture {
                // Dismiss on tap
                dismissTimer?.invalidate()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = false
                }
            }
        }
    }
    
    private func startDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}

extension View {
    func saveConfirmationOverlay(
        show: Binding<Bool>,
        bookmarkId: String? = nil,
        text: String = "Saved",
        icon: String = "checkmark.circle.fill",
        onEdit: (() -> Void)? = nil
    ) -> some View {
        self.modifier(SaveConfirmationModifier(
            showConfirmation: show,
            bookmarkId: bookmarkId,
            text: text,
            icon: icon,
            onEdit: onEdit
        ))
    }
}

#Preview {
    VStack {
        Spacer()
        SaveConfirmationOverlay()
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}