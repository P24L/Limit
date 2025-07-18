//
//  ComposeToolbar.swift
//  Limit
//
//  Created by Assistant on 17.07.2025.
//

import SwiftUI
import ATProtoKit

struct ComposeToolbar: View {
    let characterCount: Int
    let remainingCharacters: Int
    let canAddMedia: Bool
    let languages: [Locale]
    let onAddImage: () -> Void
    let onAddVideo: () -> Void
    let onToggleLanguage: (Locale) -> Void
    let onAddThread: () -> Void
    
    @State private var showLanguageMenu = false
    
    var body: some View {
        HStack(spacing: 20) {
            // Media buttons
            Button(action: onAddImage) {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(canAddMedia ? .mintAccent : .gray)
            }
            .disabled(!canAddMedia)
            
            Button(action: onAddVideo) {
                Image(systemName: "video")
                    .font(.system(size: 20))
                    .foregroundColor(canAddMedia ? .mintAccent : .gray)
            }
            .disabled(!canAddMedia)
            
            // Language selector
            Menu {
                ForEach(availableLanguages, id: \.identifier) { locale in
                    Button(action: { onToggleLanguage(locale) }) {
                        HStack {
                            Text(languageName(for: locale))
                            if languages.contains(locale) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                    if !languages.isEmpty {
                        Text(languageCode(for: languages.first!))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(.mintAccent)
            }
            
            // Thread button
            Button(action: onAddThread) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 20))
                    .foregroundColor(.mintAccent)
            }
            
            Spacer()
            
            // Character counter
            CharacterCountView(
                count: characterCount,
                remaining: remainingCharacters
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private var availableLanguages: [Locale] {
        [
            Locale(identifier: "cs_CZ"),
            Locale(identifier: "en_US"),
            Locale(identifier: "de_DE"),
            Locale(identifier: "fr_FR"),
            Locale(identifier: "es_ES"),
            Locale(identifier: "ja_JP"),
            Locale(identifier: "pt_BR"),
            Locale(identifier: "ko_KR"),
            Locale(identifier: "zh_CN")
        ]
    }
    
    private func languageName(for locale: Locale) -> String {
        locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }
    
    private func languageCode(for locale: Locale) -> String {
        if #available(iOS 16, *) {
            return locale.language.languageCode?.identifier ?? "?"
        } else {
            return locale.languageCode ?? "?"
        }
    }
}

struct CharacterCountView: View {
    let count: Int
    let remaining: Int
    
    private var color: Color {
        switch remaining {
        case 51...:
            return .secondary
        case 21...50:
            return .orange
        case 0...20:
            return .red
        default:
            return .red
        }
    }
    
    private var progress: Double {
        Double(count) / 300.0
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(color, lineWidth: 3)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
                
                if remaining < 0 {
                    Text("!")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
            
            // Text counter
            if remaining <= 50 {
                Text("\(remaining)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .monospacedDigit()
            }
        }
    }
}

struct ImagePreviewGrid: View {
    let images: [ATProtoTools.ImageQuery]
    let onRemove: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images.indices, id: \.self) { index in
                    ImagePreviewCell(
                        imageData: images[index].imageData,
                        onDelete: { onRemove(index) }
                    )
                }
            }
        }
        .frame(height: 120)
    }
}

struct ImagePreviewCell: View {
    let imageData: Data
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(8)
            }
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .padding(4)
        }
    }
}

