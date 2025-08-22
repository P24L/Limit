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
        // Use the non-zero height, or the new one if the existing one is zero.
        value = value > 0 ? value : nextValue()
    }
}

struct PostItemWrappedView: View {
    @Environment(\.modelContext) var context
    @Environment(MultiAccountClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    @Namespace var namespace

    var post: TimelinePostWrapper
    var depth: Int = 0 // kontrola hloubky - ukazuji pouze hloubku 0 a 1
    var nextPostID: String? = nil
    var nextPostThreadRootID: String? = nil
    var isThreadView: Bool = false
    var postViewType: PostViewType = .timeline
    var showCard: Bool = true // Control card background visibility

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

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 4) {
            // MARK: Avatar
            HStack(alignment: .top) {
                if postViewType == .timeline {
                    VStack(spacing: 0) {
                        AvatarView(url: post.authorAvatarURL, size: 50)
                            .onTapGesture {
                                router.navigateTo(.actor(userID: post.authorID))
                            }

                        if let threadRootID = post.rootPost?.uri  {
                            if threadRootID == nextPostThreadRootID || threadRootID == nextPostID {
                                ThreadLinkView()
                                    //.frame(height: 90) // Set height for GeometryReader
                                    .offset(y: 20) // Extend down to bridge post gap
                                    .offset(x: 3)
                            }
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
                            .foregroundColor(.mintAccent)
                        Spacer(minLength: 8)
                        Text(post.createdAt.relativeFormatted)
                            .font(.footnote)
                            .foregroundStyle(.tertiaryText)
                    }

                    // MARK: reply text nad postem - na co ten post reaguje - pokud to není hned ten další
                    if let postRootID = post.rootPost?.uri,
                    let rootPost = post.rootPost,
                    postRootID != nextPostThreadRootID,
                    postRootID != nextPostID {

                        let replyAuthorRaw = rootPost.authorDisplayName ?? rootPost.authorHandle
                        let replyAuthor = replyAuthorRaw.count > 20 ? String(replyAuthorRaw.prefix(20)) + ".." : replyAuthorRaw
                        VStack(alignment: .leading, spacing: 2) {
                            Text("↪︎ Reply to \(replyAuthor)")
                                .font(.footnote)
                                .foregroundStyle(.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            if !rootPost.text.isEmpty {
                                Text(rootPost.text)
                                    .font(.footnote)
                                    .foregroundStyle(.secondaryText)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    
                    // MARK: Post - text
                    RichTextView(text: post.text, facets: post.facets, postWrapper: post)

                    // MARK: Weblink
                    if let linkExt = post.linkExt, depth < 2 {
                        WrappedPostLinkView(linkExt: linkExt)
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
                            .background(Color.warmBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.subtleGray.opacity(0.3), lineWidth: 0.5)
                            )
                            .cardShadow()
                    }
                    
                    // MARK: Enhanced Link Presentation - Facet Links + Action bar + Divider
                    if depth == 0 {
                        VStack(spacing: 4) {
                            // FacetLinksView jen když existují odkazy
                            if let facets = post.facets, !facets.uniqueLinks(excluding: post.linkExt?.uri).isEmpty {
                                FacetLinksView(post: post)
                            }
                            
                            // Action bar vždy
                            PostItemActionsView(postWrapper: post)
                            
                            // Divider removed - cards provide visual separation
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)

        let cardStyledContent = Group {
            if showCard {
                content
                    .padding(.vertical, 10)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cardBackground)
                            .subtleShadow()
                    )
            } else {
                content
            }
        }

        // This block of modifiers is the core of the height stabilization hack.
        // 1. .background(GeometryReader...): A GeometryReader is placed in the background
        //    to measure the actual rendered size of the `cardStyledContent`.
        // 2. .preference(...): The measured height is reported upwards using our PreferenceKey.
        // 3. .onPreferenceChange(...): We listen for the reported height. Once we get a
        //    valid (non-zero) height, we store it in the `measuredHeight` state variable.
        //    We only store it once to avoid layout loops.
        // 4. .frame(height: measuredHeight): This is the crucial step. If `measuredHeight` is set,
        //    it locks the view's frame to that specific height. This prevents the view from
        //    resizing after its initial render, which is what confuses LazyVStack.
        return cardStyledContent
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: PostHeightPreferenceKey.self, value: geometry.size.height)
                }
            )
            .onPreferenceChange(PostHeightPreferenceKey.self) { height in
                if height > 0 {
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
    var linkExt: TimelinePostWrapper.LinkEmbed

    var body: some View {
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
                                    .foregroundColor(.mintInactive)
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
                .background(Color.warmBackground)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Color.warmBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.subtleGray.opacity(0.3), lineWidth: 0.5)
        )
        .cardShadow()
    }
}


struct ThreadLinkView: View {
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let spacing: CGFloat = 24 // rozestup mezi trojúhelníky
            let triangleSize: CGFloat = 7
            let triangleCount = Int(height / spacing)
            
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.mintInactive)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)

                ForEach(0..<triangleCount, id: \.self) { i in
                    Triangle()
                        .fill(Color.mintInactive)
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

    var body: some View {
        if let url = url {
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
                .foregroundStyle(isBookmarked ? .mintAccent : .postAction)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Initialize state
            isBookmarked = bookmarkManager.isBookmarked(url)
        }
    }
}