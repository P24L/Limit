//
//  PostItemWrappedView.swift
//  Limit
//
//  Created by Zdenek Indra on 14.06.2025.
//

import ATProtoKit
import Foundation
import SDWebImageSwiftUI

import SwiftUI
import SwiftData

enum PostViewType {
    case timeline
    case quoted
    case favorites
}


// MARK: - Height Measurement Hack
// This PreferenceKey is used to report the measured height of the post view content
// up the view hierarchy. It's a key part of the solution to prevent LazyVStack
// from creating unwanted gaps when cell heights change dynamically.
private struct PostHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Always take the latest reported height
        value = nextValue()
    }
}

struct PostItemWrappedView: View {
    @Environment(\.modelContext) var context
    @Environment(MultiAccountClient.self) private var client
    @Environment(AppRouter.self) private var router
    @Environment(ThemeManager.self) private var themeManager

    @Namespace var namespace

    var post: TimelinePostWrapper
    var depth: Int = 0 // kontrola hloubky - ukazuji pouze hloubku 0 a 1
    var previousPostID: String? = nil
    var previousPostThreadRootID: String? = nil
    var nextPostID: String? = nil
    var nextPostThreadRootID: String? = nil
    var isThreadView: Bool = false
    var postViewType: PostViewType = .timeline
    var showCard: Bool = true // Control card background visibility (deprecated, use useListStyle instead)
    var threadDepth: Int? = nil // Thread hierarchy depth for visualization
    var useListStyle: Bool = false // New parameter for List-based rendering

    @AppStorage("showDirectReplyContext") private var showDirectReplyContext: Bool = true

    @State private var selectedImageIndex: Int = 0
    @State private var fullScreenImages: [PostImage] = []
    @State private var showSaveConfirmation: Bool = false
    @State private var savedBookmarkId: String? = nil

    // Stores the calculated height of the view's content.
    // When nil, the view renders with a flexible height. Once a height is measured
    // and set, it's used to fix the frame size, providing stability for LazyVStack.
    @State private var measuredHeight: CGFloat? = nil

    @Query(
        sort: \TimelinePost.createdAt,
        order: .reverse
    ) var posts: [TimelinePost]

    // Helper function to detect GIF URLs (ignoring query parameters)
    private func isGIFURL(_ urlString: String) -> Bool {
        // Remove query parameters and fragment
        let cleanURL = urlString.split(separator: "?").first ?? ""
        return cleanURL.lowercased().hasSuffix(".gif")
    }

    var body: some View {
        let colors = themeManager.colors
        let content = VStack(alignment: .leading, spacing: 8) {
            // MARK: Top content (avatar + main body)
            HStack(alignment: .top) {
                if postViewType == .timeline {
                    let currentRootID = post.rootPost?.uri
                    let threadIdentifier = currentRootID ?? post.uri
                    let connectsToPrevious: Bool = {
                        guard let previousRootID = previousPostThreadRootID else { return false }
                        if let currentRootID {
                            return previousRootID == currentRootID
                        }
                        return previousRootID == post.uri
                    }()

                    VStack(spacing: 0) {
                        AvatarView(url: post.authorAvatarURL, size: 50)
                            .overlay(alignment: .top) {
                                // ThreadLink upward to previous post (using overlay to avoid layout space)
                                if !isThreadView, connectsToPrevious {
                                    ThreadLinkView()
                                        .frame(height: 40)
                                        .offset(y: -40) // Position above avatar
                                        .offset(x: 3)
                                }
                            }
                            .onTapGesture {
                                router.navigateTo(.actor(userID: post.authorID))
                            }

                        // ThreadLink downward to next post (existing logic)
                        if !isThreadView,
                           (nextPostThreadRootID == threadIdentifier) || (nextPostID == threadIdentifier) {
                            ThreadLinkView()
                                //.frame(height: 90) // Set height for GeometryReader
                                .offset(y: 20) // Extend down to bridge post gap
                                .offset(x: 3)
                        }
                    }
                }

                // MARK: Autor a čas postu
                VStack(alignment: .leading, spacing: 4){
                    // MARK: Reposted by
                    if let repostHandle = post.repostedByHandle
                    {
                        Text("Reposted by \(post.repostedByDisplayName ?? repostHandle)")
                                .font(.footnote)
                                .foregroundStyle(.secondaryText)
                    }

                    HStack(alignment:.top) {
                        // Pokud quoted nebo favorite, pak je avatar tady a menší
                        if [.quoted, .favorites].contains(postViewType) {
                            AvatarView(url: post.authorAvatarURL, size: 50)
                                .onTapGesture {
                                    router.navigateTo(.actor(userID: post.authorID))
                                }
                        }
                        Text(!(post.authorDisplayName ?? "").isEmpty ? (post.authorDisplayName ?? "") : post.authorHandle)
                            .font(.subheadline)
                            .foregroundColor(colors.accent)
                        Spacer(minLength: 8)
                        Text(post.createdAt.relativeFormatted)
                            .font(.footnote)
                            .foregroundStyle(.tertiaryText)
                    }

                    // MARK: Reply context (root + parent) in main timeline
                    if !isThreadView && postViewType == .timeline, let rootPost = post.rootPost {
                        let threadRootID = rootPost.uri
                        let showsThreadLink = (threadRootID == nextPostThreadRootID) || (threadRootID == nextPostID)

                        // Show root context only when ThreadLink is NOT visible
                        if !showsThreadLink {
                            // Root context first
                            let rootAuthorRaw = rootPost.authorDisplayName ?? rootPost.authorHandle
                            let rootAuthor = rootAuthorRaw.count > 20 ? String(rootAuthorRaw.prefix(20)) + ".." : rootAuthorRaw
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.footnote)
                                        .foregroundStyle(.secondaryText)
                                    Text("In thread: \(rootAuthor)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondaryText)
                                }

                                if !rootPost.text.isEmpty {
                                    Text(rootPost.text)
                                        .font(.footnote)
                                        .foregroundStyle(.secondaryText)
                                        .lineLimit(2)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                router.navigateTo(.postThreadWrapped(postThread: post))
                            }
                        }

                        // Show parent context (Reply to) with expanded conditions
                        // Show when: ThreadLink is NOT visible OR replying to different author
                        if showDirectReplyContext,
                           let parent = post.parentPost,
                           parent.uri != rootPost.uri {

                            // Show "Reply to" when:
                            // 1. ThreadLink is NOT visible (existing behavior)
                            // 2. OR ThreadLink IS visible BUT replying to different author
                            let shouldShowReplyTo = !showsThreadLink || (parent.authorID != post.authorID)

                            if shouldShowReplyTo {
                                let parentAuthorRaw = parent.authorDisplayName ?? parent.authorHandle
                                let parentAuthor = parentAuthorRaw.count > 20 ? String(parentAuthorRaw.prefix(20)) + ".." : parentAuthorRaw
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("↪︎ Reply to \(parentAuthor)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondaryText)

                                    if !parent.text.isEmpty {
                                        Text(parent.text)
                                            .font(.footnote)
                                            .foregroundStyle(.secondaryText)
                                            .lineLimit(2)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    router.navigateTo(.postThreadWrapped(postThread: post))
                                }
                            }
                        }
                    }
                    
                    // MARK: Post - text
                    RichTextView(text: post.text, facets: post.facets, postWrapper: post)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.navigateTo(.postThreadWrapped(postThread: post))
                        }

                    // MARK: Weblink
                    if let linkExt = post.linkExt, depth < 2 {
                        // Check if this is a GIF link that should be displayed as an image
                        if isGIFURL(linkExt.uri) {
                            // Display as animated image
                            if let gifURL = URL(string: linkExt.uri) {
                                AnimatedImage(url: gifURL)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 400)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.subtleGray.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .cardShadow()
                                    .onTapGesture {
                                        router.navigateTo(.safari(url: gifURL))
                                    }
                            }
                        } else {
                            // Display as regular link card
                            WrappedPostLinkView(linkExt: linkExt)
                        }
                    }


                    // MARK: Post - images (optimized)
                    if post.embeds.count == 1, let image = post.embeds.first {
                        EmbeddedImageView(url: image.thumbURL)
                            .onTapGesture {
                                self.openImageGallery(at: 0)
                            }

                    } else if post.embeds.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 8) {
                                ForEach(Array(post.embeds.enumerated()), id:\.offset) {  index,image in
                                    EmbeddedImageView(url: image.thumbURL)
                                        .frame(width: 200, height: 200)
                                        .onTapGesture {
                                            self.openImageGallery(at: index)
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 208) // Fixed height instead of maxHeight
                    }

                    // MARK: Post - video
                    if let videoEmbed = post.postVideo,
                       let url = URL(string: videoEmbed.playlistURI) {
                        EmbeddedVideoView(playlistURL: url, height: videoEmbed.height, width: videoEmbed.width)
                            .aspectRatio(
                                CGFloat(videoEmbed.width ?? 16) / CGFloat(videoEmbed.height ?? 9), 
                                contentMode: .fit
                            )
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .padding(.top, 4)
                    }

                    // MARK: Quoted post
                    
                    if let quotedPost = post.quotedPost, depth < 2 {
                        PostItemWrappedView(post: quotedPost, depth: depth + 1, postViewType: .quoted, showCard: false)
                            .padding(10)
                            .background(themeManager.colors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.subtleGray.opacity(0.3), lineWidth: 0.5)
                            )
                            .cardShadow()
                    }
                    
                    // MARK: Enhanced Link Presentation - Facet Links (no actions here)
                    if depth == 0 {
                        // FacetLinksView jen když existují odkazy
                        if let facets = post.facets, !facets.uniqueLinks(excluding: post.linkExt?.uri).isEmpty {
                            FacetLinksView(post: post)
                        }
                    }

                    // MARK: Action bar under content
                    if depth == 0 {
                        PostItemActionsView(postWrapper: post)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)

        // Add thread depth visualization if in thread view
        let contentWithThreadDepth = Group {
            if let threadDepth = threadDepth, threadDepth > 0 {
                content
                    .padding(.leading, CGFloat(threadDepth * 5 + 16)) // Offset for depth lines
                    .background(alignment: .leading) {
                        // Draw vertical lines in background
                        HStack(spacing: 3) {
                            ForEach(0..<threadDepth, id: \.self) { index in
                                Rectangle()
                                    // Last line uses palette accent, others subdued border
                                    .fill(index == threadDepth - 1 ? colors.accent : colors.border.opacity(0.35))
                                    .frame(width: 2)
                            }
                        }
                        .padding(.leading, 8)
                    }
            } else {
                content
            }
        }

        let cardStyledContent = Group {
            if useListStyle {
                // For List style - no card, just content
                contentWithThreadDepth
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 6)
            } else if showCard {
                // For ScrollView with cards
                contentWithThreadDepth
                    .padding(.vertical, 10)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.colors.backgroundListRow)
                            .subtleShadow()
                    )
            } else {
                contentWithThreadDepth
            }
        }

        // Apply height measurement hack to stabilize row height in Lists and Lazy stacks
        return cardStyledContent
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: PostHeightPreferenceKey.self, value: geometry.size.height)
                }
            )
            .onPreferenceChange(PostHeightPreferenceKey.self) { height in
                guard height > 0 else { return }
                // Shrink-only: allow reducing locked height, but never increase it
                if let current = self.measuredHeight {
                    // Use a tiny epsilon to avoid needless churn from sub-pixel jitter
                    if height + 0.5 < current {
                        self.measuredHeight = height
                    }
                } else {
                    self.measuredHeight = height
                }
            }
            .frame(height: measuredHeight)
            .padding(.bottom, 0)
    }

    // MARK: - Optimized Image Gallery Helper
    private func openImageGallery(at index: Int) {
        // Lazy evaluation: create images array only when needed
        let images = self.post.embeds.map { $0.toDisplayImage() }
        
        self.router.presentedSheet = .fullScreenImage(
            images: images,
            initialIndex: index,
            namespace: self.namespace
        )
    }
}

struct WrappedPostLinkView: View {
    @Environment(AppRouter.self) private var router
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(ThemeManager.self) private var themeManager
    var linkExt: TimelinePostWrapper.LinkEmbed

    var body: some View {
        let colors = themeManager.colors
        Button(action: {
            if let url = URL(string: linkExt.uri) {
                router.navigateTo(.safari(url: url))
            }
        }) {
            VStack(spacing: 0) {
                if let thumbnail = linkExt.thumbnailImageURL {
                    Color.black
                        .frame(height: 160)
                        .overlay(
                            WebImage(url: thumbnail) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .empty, .failure:
                                    Rectangle()
                                        .foregroundStyle(Color.gray.opacity(0.2))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                                .font(.largeTitle)
                                        )
                                }
                            }
                        )
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 12
                        ))
                }
                    
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            if !linkExt.title.isEmpty {
                                Text(linkExt.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                            }
                            Text(linkExt.desc.count > 0 ? linkExt.desc : linkExt.uri)
                                .font(.footnote)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.secondaryText)
                            if let mainURL = URL(string:linkExt.uri), let hostURL = mainURL.host() {
                                Text(hostURL)
                                    .font(.footnote)
                                    .lineLimit(1)
                                    .foregroundColor(colors.accent)
                            }
                        }
                        Spacer()
                        
                        // Bookmark button (separate action)
                        if let url = URL(string: linkExt.uri) {
                            BookmarkToggleButton(
                                url: url,
                                title: linkExt.title,
                                description: linkExt.desc,
                                imageUrl: linkExt.thumbnailImageURL?.absoluteString
                            )
                        }
                }
                .padding(12)
                .frame(height: 88)
                .background(Color.cardSecondaryBackground)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Color.cardSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.subtleGray.opacity(0.3), lineWidth: 0.5)
        )
        .cardShadow()
    }
}


struct ThreadLinkView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let colors = themeManager.colors
        GeometryReader { geometry in
            let height = geometry.size.height
            let spacing: CGFloat = 24 // rozestup mezi trojúhelníky
            let triangleSize: CGFloat = 7
            let triangleCount = Int(height / spacing)
            
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(colors.accentMuted)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)

                ForEach(0..<triangleCount, id: \.self) { i in
                    Triangle()
                        .fill(colors.accentMuted)
                        .frame(width: triangleSize, height: triangleSize)
                        .rotationEffect(.degrees(0)) // směřuje nahoru
                        .offset(x: (triangleSize * -0.5) + 1, y: CGFloat(i) * spacing + triangleSize / 2)
                }
            }
        }
        .frame(width: 10) // šířka celého ThreadLinkView
    }
}


struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY)) // vrchol nahoře
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}


// MARK: LazyImage pro images
struct EmbeddedImageView: View {
    let url: URL?

    private var isGIF: Bool {
        guard let url = url else { return false }
        return url.absoluteString.lowercased().hasSuffix(".gif")
    }

    var body: some View {
        if let url = url {
            if isGIF {
                // Use AnimatedImage for GIFs
                AnimatedImage(url: url)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .frame(maxWidth: .infinity)
                    .background(backgroundView)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.trailing, 8)
            } else {
                // Use WebImage for static images
                WebImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderView
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                    case .failure(_):
                        placeholderView
                    }
                }
                .frame(maxWidth: .infinity)
                .background(backgroundView)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.trailing, 8)
            }
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Optimized Subviews
    private var placeholderView: some View {
        Rectangle()
            .foregroundStyle(.gray)
            .aspectRatio(4/3, contentMode: .fit)
            .frame(maxHeight: 300)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.clear)
            .imageShadow()
    }
}

struct PostLinkView: View {
    @Environment(AppRouter.self) private var router
    
    var linkExt: PostLinkExt

    var body: some View {
        Button(action: {
            if let url = URL(string: linkExt.uri) {
                router.navigateTo(.safari(url: url))
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                if let thumbnail = linkExt.thumbnailImageURL {
                    WebImage(url: thumbnail) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().foregroundStyle(.gray)
                        case .success(let image):
                            image.resizable()
                        case .failure(_):
                            Rectangle().foregroundStyle(.gray)
                        }
                    }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    if !linkExt.title.isEmpty {
                        Text(linkExt.title)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    Text(linkExt.desc.count > 0 ? linkExt.desc : linkExt.uri)
                        .font(.footnote)
                        .lineLimit(2)
                        .foregroundColor(.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}


private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct BookmarkToggleButton: View {
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(ThemeManager.self) private var themeManager
    let url: URL
    let title: String?
    let description: String?
    let imageUrl: String?
    
    @State private var isBookmarked: Bool = false
    @State private var isAnimating: Bool = false
    
    var body: some View {
        Button {
            // Optimistic update
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isBookmarked.toggle()
                isAnimating = true
            }
            
            // Background operation
            Task {
                await bookmarkManager.toggleBookmark(
                    for: url,
                    title: title,
                    description: description,
                    imageUrl: imageUrl
                )
                
                // Verify state after operation completes
                await MainActor.run {
                    let actualState = bookmarkManager.isBookmarked(url)
                    if actualState != isBookmarked {
                        // Revert if operation result differs
                        withAnimation {
                            isBookmarked = actualState
                        }
                    }
                    isAnimating = false
                }
            }
        } label: {
            Image(systemName: "bookmark")
                .font(.title2)
                .symbolVariant(isBookmarked ? .fill : .none)
                .symbolEffect(.bounce, value: isBookmarked)
                .foregroundStyle(isBookmarked ? themeManager.colors.accent : themeManager.colors.textSecondary)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Initialize state
            isBookmarked = bookmarkManager.isBookmarked(url)
        }
    }
}
