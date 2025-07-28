//
//  RichTextEditor.swift
//  Limit
//
//  Created by Assistant on 17.07.2025.
//

import SwiftUI
import ATProtoKit

// Helper extension for UnderlineStyle
extension Text.LineStyle {
    func nsUnderlineStyle() -> NSUnderlineStyle {
        switch self {
        case .single:
            return .single
        default:
            return .single
        }
    }
}

struct RichTextEditor: View {
    @Binding var text: String
    let displayText: String
    let facets: [AppBskyLexicon.RichText.Facet]
    let onTextChange: (String) -> Void
    var onCursorFrameChange: ((CGRect) -> Void)?
    
    @State private var textEditorHeight: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background layer for sizing
            if !text.isEmpty {
                Text(text)
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .opacity(0.0) // Hidden, just for sizing
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    textEditorHeight = geometry.size.height
                                }
                                .onChange(of: text) { _, _ in
                                    textEditorHeight = geometry.size.height
                                }
                        }
                    )
            }
            
            // Actual TextEditor with syntax highlighting
            HighlightedTextEditor(
                text: $text,
                facets: facets,
                minHeight: max(100, textEditorHeight),
                onTextChange: onTextChange,
                onCursorFrameChange: onCursorFrameChange
            )
        }
    }
}

// MARK: - Custom TextEditor with Highlighting

struct HighlightedTextEditor: UIViewRepresentable {
    @Binding var text: String
    let facets: [AppBskyLexicon.RichText.Facet]
    let minHeight: CGFloat
    let onTextChange: (String) -> Void
    var onCursorFrameChange: ((CGRect) -> Void)?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 4)
        
        // Configure for better typing experience
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.smartDashesType = .default
        textView.smartQuotesType = .default
        textView.spellCheckingType = .yes
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if text actually changed to avoid cursor jumping
        if textView.text != text {
            textView.text = text
        }
        
        // Apply highlighting
        if !text.isEmpty {
            applyHighlighting(to: textView)
        }
        
        // Update height constraint
        textView.constraints.forEach { constraint in
            if constraint.firstAttribute == .height {
                constraint.constant = max(minHeight, textView.contentSize.height)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func applyHighlighting(to textView: UITextView) {
        // Create attributed string
        let nsAttributedString = NSMutableAttributedString(string: text)
        
        // Default attributes
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        nsAttributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: fullRange)
        nsAttributedString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        // Apply highlighting based on facets
        for facet in facets {
            // Convert byte offsets to character indices
            guard let startChar = text.characterIndex(at: facet.index.byteStart),
                  let endChar = text.characterIndex(at: facet.index.byteEnd) else {
                continue
            }
            
            // Convert to NSRange
            let startIndex = text.index(text.startIndex, offsetBy: startChar)
            let endIndex = text.index(text.startIndex, offsetBy: endChar)
            
            guard startIndex < text.endIndex, endIndex <= text.endIndex else {
                continue
            }
            
            let nsRange = NSRange(startIndex..<endIndex, in: text)
            
            // Apply styling based on facet type
            for feature in facet.features {
                switch feature {
                case .link:
                    nsAttributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: nsRange)
                    nsAttributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
                    
                case .mention:
                    nsAttributedString.addAttribute(.foregroundColor, value: UIColor.systemPurple, range: nsRange)
                    nsAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .medium), range: nsRange)
                    
                case .tag:
                    nsAttributedString.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: nsRange)
                    nsAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .medium), range: nsRange)
                    
                case .unknown:
                    break
                }
            }
        }
        
        // Preserve cursor position
        let selectedRange = textView.selectedRange
        textView.attributedText = nsAttributedString
        textView.selectedRange = selectedRange
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: HighlightedTextEditor
        
        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange(textView.text)
            reportCursorFrame(textView)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            reportCursorFrame(textView)
        }
        
        private func reportCursorFrame(_ textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange else { return }
            
            // Get cursor frame in text view coordinates
            let cursorRect = textView.caretRect(for: selectedRange.start)
            
            // Convert to window coordinates for proper positioning
            if let window = textView.window {
                let convertedRect = textView.convert(cursorRect, to: window)
                parent.onCursorFrameChange?(convertedRect)
            }
        }
    }
}

