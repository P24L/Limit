//
//  ColorPickerSheet.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import SwiftUI

struct ColorPickerSheet: View {
    @Binding var selectedColor: String?
    @Environment(\.dismiss) private var dismiss
    
    // Predefined colors for bookmark lists
    let colors: [String] = [
        "#FF0000", // Red
        "#FF4500", // Orange Red
        "#FFA500", // Orange
        "#FFFF00", // Yellow
        "#32CD32", // Lime Green
        "#00FF00", // Green
        "#00CED1", // Dark Turquoise
        "#00BFFF", // Deep Sky Blue
        "#0000FF", // Blue
        "#4169E1", // Royal Blue
        "#9370DB", // Medium Purple
        "#FF1493", // Deep Pink
        "#FF69B4", // Hot Pink
        "#808080", // Gray
        "#2F4F4F", // Dark Slate Gray
        "#000000"  // Black
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current color preview
                if let selectedColor = selectedColor {
                    HStack {
                        Text("Current color:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: selectedColor))
                            .frame(width: 60, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text(selectedColor)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding()
                }
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        // No color option
                        Button(action: {
                            selectedColor = nil
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "xmark")
                                            .foregroundColor(.gray)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedColor == nil ? Color.orange : Color.gray.opacity(0.3), lineWidth: selectedColor == nil ? 2 : 1)
                                    )
                                
                                Text("None")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // Color options
                        ForEach(colors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                                dismiss()
                            }) {
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: color))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedColor == color ? Color.orange : Color.gray.opacity(0.3), lineWidth: selectedColor == color ? 2 : 1)
                                        )
                                    
                                    Text(color)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ColorPickerSheet(selectedColor: .constant("#FF0000"))
}