//
//  RichTextView.swift
//  Limit
//
//  Created by Zdenek Indra on 02.07.2025.
//

import SwiftUI
import ATProtoKit
import AppRouter

struct RichTextView: View {
    @Environment(AppRouter.self) private var router
    
    let text: String
    let facets: TimelinePostWrapper.PostFacets?
    let font: Font
    let postWrapper: TimelinePostWrapper?
    
    init(text: String, facets: TimelinePostWrapper.PostFacets?, font: Font = .callout, postWrapper: TimelinePostWrapper? = nil) {
        self.text = text
        self.facets = facets
        self.font = font
        self.postWrapper = postWrapper
    }
    
    var body: some View {
        if let facets = facets, !facets.isEmpty {
            InteractiveRichText(text: text, facets: facets, font: font, postWrapper: postWrapper)
        } else {
            // Plain text - add thread navigation
            Text(text)
                .font(font)
                .onTapGesture {
                    if let postWrapper = postWrapper {
                        router.navigateTo(.postThreadWrapped(postThread: postWrapper))
                    }
                }
        }
    }
}

private struct InteractiveRichText: View {
    @Environment(AppRouter.self) private var router
    
    let text: String
    let facets: TimelinePostWrapper.PostFacets
    let font: Font
    let postWrapper: TimelinePostWrapper?
    
    // Cache the attributedText to prevent infinite re-computation
    @State private var cachedAttributedText: AttributedString?
    
    var body: some View {
        let attributedText = getCachedAttributedText()
        
        Text(attributedText)
            .font(font)
            .environment(\.openURL, OpenURLAction { [router] url in
                if url.scheme == "limit" {
                    handleCustomURL(url)
                    return .handled
                } else {
                    router.navigateTo(.safari(url: url))
                    return .handled
                }
            })
            .onAppear {
                if cachedAttributedText == nil {
                    cachedAttributedText = buildAttributedText()
                }
            }
    }
    
    private func getCachedAttributedText() -> AttributedString {
        if let cached = cachedAttributedText {
            return cached
        }
        let attributed = buildAttributedText()
        cachedAttributedText = attributed
        return attributed
    }
    
    private func handleCustomURL(_ url: URL) {
        guard let host = url.host else {
            return
        }
        
        let path = url.path
        
        switch host {
        case "mention":
            let did = String(path.dropFirst()) // Remove leading "/"
            router.navigateTo(.actor(userID: did))
        case "tag":
            let tag = String(path.dropFirst()) // Remove leading "/"
            router.selectedTab = .search
            router.navigateTo(.searchPosts(query: "#\(tag)"))
        case "thread":
            // Navigate to thread view
            if let postWrapper = postWrapper {
                router.navigateTo(.postThreadWrapped(postThread: postWrapper))
            }
        default:
            break
        }
    }
    
    private func buildAttributedText() -> AttributedString {
        let segments = createTextSegments()
        var result = AttributedString()
        
        for segment in segments {
            var segmentString = AttributedString(segment.text)
            segmentString.foregroundColor = segment.color
            
            if segment.isUnderlined {
                segmentString.underlineStyle = .single
            }
            
            // Add tap handling by setting custom attributes if needed
            if let facet = segment.facet {
                // Store facet data for potential tap handling
                segmentString.link = createLinkForFacet(facet)
            } else if postWrapper != nil {
                // Plain text - add thread navigation link
                segmentString.link = URL(string: "limit://thread/navigate")
            }
            
            result.append(segmentString)
        }
        
        return result
    }
    
    private func createLinkForFacet(_ facet: TimelinePostWrapper.ProcessedFacet) -> URL? {
        switch facet.data {
        case .link(let uri):
            return URL(string: uri)
        case .mention(let did, _):
            return URL(string: "limit://mention/\(did)")
        case .tag(let tag):
            return URL(string: "limit://tag/\(tag)")
        }
    }
    
    private func createTextSegments() -> [TextSegment] {
        var segments: [TextSegment] = []
        let sortedFacets = facets.facets.sorted { $0.range.location < $1.range.location }
        
        var currentIndex = 0
        
        for facet in sortedFacets {
            let range = facet.range
            
            // Validate range
            guard range.location >= currentIndex,
                  range.location + range.length <= text.count else {
                continue
            }
            
            // Add plain text before facet
            if range.location > currentIndex {
                let plainStart = text.index(text.startIndex, offsetBy: currentIndex)
                let plainEnd = text.index(text.startIndex, offsetBy: range.location)
                let plainText = String(text[plainStart..<plainEnd])
                
                segments.append(TextSegment(
                    text: plainText,
                    facet: nil,
                    color: .primary,
                    isUnderlined: false
                ))
            }
            
            // Add facet text
            let facetStart = text.index(text.startIndex, offsetBy: range.location)
            let facetEnd = text.index(text.startIndex, offsetBy: range.location + range.length)
            let facetText = String(text[facetStart..<facetEnd])
            
            let (color, isUnderlined) = styleForFacet(facet.type)
            
            segments.append(TextSegment(
                text: facetText,
                facet: facet,
                color: color,
                isUnderlined: isUnderlined
            ))
            
            currentIndex = range.location + range.length
        }
        
        // Add remaining plain text
        if currentIndex < text.count {
            let remainingStart = text.index(text.startIndex, offsetBy: currentIndex)
            let remainingText = String(text[remainingStart...])
            
            segments.append(TextSegment(
                text: remainingText,
                facet: nil,
                color: .primary,
                isUnderlined: false
            ))
        }
        
        return segments
    }
    
    private func styleForFacet(_ type: TimelinePostWrapper.FacetType) -> (Color, Bool) {
        switch type {
        case .link:
            return (.mintAccent, false)
        case .mention:
            return (.mintAccent, false)
        case .tag:
            return (.mintAccent, false)
        }
    }
}

private struct TextSegment {
    let text: String
    let facet: TimelinePostWrapper.ProcessedFacet?
    let color: Color
    let isUnderlined: Bool
}

#Preview {
    VStack(spacing: 20) {
        // Plain text
        RichTextView(text: "This is plain text without any facets", facets: nil)
        
        // Text with mock facets - we'll add proper preview data later
        RichTextView(text: "Check out https://example.com and @user.bsky.social #hashtag", facets: nil)
        
        Spacer()
    }
    .padding()
    .environment(AppRouter(initialTab: .timeline))
}