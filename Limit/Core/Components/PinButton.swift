//
//  PinButton.swift
//  Limit
//
//  Created by Assistant on 26.07.2025.
//

import SwiftUI

struct PinButton: View {
    let isPinned: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "pin")
                .font(.body)
                .symbolVariant(isPinned ? .fill : .none)
                .foregroundColor(isPinned ? .orange : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel(isPinned ? "Unpin" : "Pin")
        .accessibilityHint(isPinned ? "Double tap to unpin this item" : "Double tap to pin this item")
    }
}