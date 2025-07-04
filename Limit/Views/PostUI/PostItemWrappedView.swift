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


struct PostItemWrappedView: View {
    @Environment(\.modelContext) var context
    @Environment(BlueskyClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    @Namespace var namespace

    var post: TimelinePostWrapper
    var depth: Int = 0 // kontrola hloubky - ukazuji pouze hloubku 0 a 1
    var nextPostID: String? = nil
    var nextPostThreadRootID: String? = nil
    var isThreadView: Bool = false
    var postViewType: PostViewType = .timeline

    @State private var selectedImageIndex: Int = 0
    @State private var fullScreenImages: [PostImage] = []
    //@State private var isImageFullScreen: Bool = false

    @Query(
        sort: \TimelinePost.createdAt,
        order: .reverse
    ) var posts: [TimelinePost]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                                .foregroundStyle(.gray)
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
                        Spacer()
                        Text(post.createdAt.relativeFormatted)
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }

                    // MARK: reply text nad postem - na co ten post reaguje - pokud to není hned ten další
                    if let postRootID = post.rootPost?.uri, let rootPost = post.rootPost  {
                        if postRootID != nextPostThreadRootID && postRootID != nextPostID {

                            let replyAuthorRaw = rootPost.authorDisplayName ?? rootPost.authorHandle
                            let replyAuthor = replyAuthorRaw.count > 20 ? String(replyAuthorRaw.prefix(20)) + ".." : replyAuthorRaw
                            HStack {
                                VStack(alignment:.leading) {
                                    Text("↪︎ Reply to \(replyAuthor)")
                                        .font(.footnote)
                                        .foregroundStyle(.gray)
                                    
                                    if rootPost.text.count > 0 {
                                        Text(rootPost.text)
                                            .font(.footnote)
                                            .foregroundStyle(.gray)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                    // MARK: Post - text
                    RichTextView(text: post.text, facets: post.facets, postWrapper: post)

                    // MARK: Weblink
                    if let linkExt = post.linkExt {
                        WrappedPostLinkView(linkExt: linkExt)
                    }


                    // MARK: Post - images
                    if post.embeds.count == 1, let image = post.embeds.first {
                        EmbeddedImageView(url: image.thumbURL)
                            .onTapGesture {
                                let images = post.embeds.map { $0.toDisplayImage() }
                                
                                router.presentedSheet = .fullScreenImage(
                                    images: images,
                                    initialIndex: 0,
                                    namespace: namespace
                                )
                            }

                    } else if post.embeds.count > 1 {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(Array(post.embeds.enumerated()), id:\.offset) {  index,image in
                                    EmbeddedImageView(url: image.thumbURL)
                                        .onTapGesture {
                                            let images = post.embeds.map { $0.toDisplayImage() }
                                            
                                            router.presentedSheet = .fullScreenImage(
                                                images: images,
                                                initialIndex: index,
                                                namespace: namespace
                                            )
                                        }
                                }
                            }
                        }
                        .frame(maxHeight: 230)
                    }

                    // MARK: Post - video
                    if let videoEmbed = post.postVideo,
                       let url = URL(string: videoEmbed.playlistURI) {
                        EmbeddedVideoView(playlistURL: url, height: videoEmbed.height, width: videoEmbed.width)
                            .aspectRatio(
                                CGFloat(videoEmbed.width ?? 16) / CGFloat(videoEmbed.height ?? 9), 
                                contentMode: .fit
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }

                    // MARK: Quoted post
                    
                    if let quotedPost = post.quotedPost, depth < 2 {
                        PostItemWrappedView(post: quotedPost, depth: depth + 1, postViewType: .quoted)
                            .padding(10)
                            .background(Color.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                            )
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
                            
                            // Divider jen na timeline a podle thread podmínek
                            if postViewType == .timeline {
                                let showDivider = {
                                    guard let threadRootID = post.rootPost?.uri else { return true }
                                    return !(threadRootID == nextPostThreadRootID || threadRootID == nextPostID)
                                }()
                                if showDivider {
                                    Divider()
                                        .frame(height: 1)
                                        .background(.mintInactive)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct WrappedPostLinkView: View {
    @Environment(AppRouter.self) private var router
    @Environment(FavoriteURLManager.self) private var favoritesURL
    var linkExt: TimelinePostWrapper.LinkEmbed

    var body: some View {
        VStack {
            // Clickable content area (image + text)
            Button(action: {
                if let url = URL(string: linkExt.uri) {
                    router.navigateTo(.safari(url: url))
                }
            }) {
                VStack {
                    if let thumbnail = linkExt.thumbnailImageURL {
                        WebImage(url: thumbnail) { phase in
                            switch phase {
                            case .empty:
                                Rectangle().foregroundStyle(.gray)
                            case .success(let image):
                                image.resizable()
                            case .failure:
                                Rectangle().foregroundStyle(.gray)
                            }
                        }
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 160)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    HStack(alignment: .top, spacing: 12) {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if !linkExt.title.isEmpty {
                                Text(linkExt.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(linkExt.desc.count > 0 ? linkExt.desc : linkExt.uri)
                                .font(.footnote)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.gray)
                            if let mainURL = URL(string:linkExt.uri), let hostURL = mainURL.host() {
                                Text(hostURL)
                                .font(.footnote)
                                .lineLimit(1)
                                .foregroundColor(.mintInactive)
                            }
                        }
                        Spacer()
                        
                        // Bookmark button (separate action)
                        VStack {
                            Spacer()
                            if let url = URL(string: linkExt.uri) {
                                Button {
                                    Task {
                                        if favoritesURL.isFavorited(url) {
                                            await favoritesURL.removeFavorite(url: url)
                                        } else {
                                            await favoritesURL.addFavorite(url: url, title: linkExt.title, thumbnailImageURL: linkExt.thumbnailImageURL)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "bookmark")
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                                .symbolVariant(favoritesURL.isFavorited(url) ? .fill : .none)
                                .symbolEffect(.bounce, value: favoritesURL.isFavorited(url))
                                .foregroundStyle(favoritesURL.isFavorited(url) ? .mintAccent : .postAction)
                            }
                            Spacer()
                        }
                    }
                    .frame(minHeight: 60)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}


struct ThreadLinkView: View {
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let spacing: CGFloat = 24 // rozestup mezi trojúhelníky
            let triangleSize: CGFloat = 6

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.mintInactive)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity, alignment: .top)

                ForEach(0..<Int(height / spacing), id: \.self) { i in
                    Triangle()
                        .fill(Color.mintInactive)
                        .frame(width: triangleSize, height: triangleSize)
                        .rotationEffect(.degrees(0)) // směřuje nahoru
                        .position(x: 0.5, y: CGFloat(i) * spacing + triangleSize / 2)
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
                    Rectangle().foregroundStyle(.gray)
                        .aspectRatio(4/3, contentMode: .fit)
                case .success(let image):
                    image.resizable()
                case .failure(_):
                    Rectangle().foregroundStyle(.gray)
                        .aspectRatio(4/3, contentMode: .fit)
                }
            }
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .shadow(color: .black.opacity(0.7), radius: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.trailing, 8)
        } else {
            EmptyView()
        }
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
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
