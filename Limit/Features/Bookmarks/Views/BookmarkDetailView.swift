//
//  BookmarkDetailView.swift
//  Limit
//
//  Created by Assistant on 06.01.2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct BookmarkDetailView: View {
    let bookmarkId: String
    
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(AppRouter.self) private var router
    
    var bookmark: BookmarkView? {
        // bookmarkId is the rkey - find bookmark by checking if URI ends with this rkey
        bookmarkManager.bookmarks.first { bookmark in
            // Parse URI to get rkey: at://did/collection/rkey
            if let lastComponent = bookmark.uri.split(separator: "/").last {
                return String(lastComponent) == bookmarkId
            }
            return false
        }
    }
    
    var body: some View {
        if let bookmark = bookmark {
            ScrollView {
                VStack(spacing: 16) {
                    // HEADER THUMBNAIL
                    HeaderThumbnail(imageUrl: bookmark.record.imageUrl)

                    // TITLE + META
                    VStack(alignment: .leading, spacing: 10) {
                        Text(bookmark.record.title.isEmpty ? "Untitled" : bookmark.record.title)
                            .font(.title3).fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            if let url = URL(string: bookmark.record.url) {
                                Text(url.host() ?? url.host ?? bookmark.record.url)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Text("•")
                            Text(bookmark.record.createdAt, style: .relative)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        // Primary actions
                        HStack(spacing: 10) {
                            if let url = URL(string: bookmark.record.url) {
                                Button {
                                    router.navigateTo(.safari(url: url))
                                } label: {
                                    Label("Open Link", systemImage: "safari")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.mintAccent)
                            }

                            Menu {
                                Button {
                                    // Share to Bluesky composer (read-only viewer can still share)
                                    router.presentedSheet = .composePost(quotedPost: nil, replyTo: nil, bookmark: bookmark)
                                } label: { Label("Share to Bluesky", systemImage: "text.bubble") }
                                Button {
                                    UIPasteboard.general.string = bookmark.record.url
                                } label: { Label("Copy Link", systemImage: "link") }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.cardBackground)
                            .subtleShadow()
                    )

                    // SUMMARY
                    if let summary = bookmark.record.summary, !summary.isEmpty {
                        Button {
                            router.presentedSheet = .aiSummary(bookmark: bookmark)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles").font(.caption).foregroundStyle(.blue)
                                Text(summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(6)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    // DESCRIPTION
                    if let description = bookmark.record.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Description", systemImage: "text.justify")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(description)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.cardBackground)
                                .subtleShadow()
                        )
                    }

                    // NOTE
                    if let note = bookmark.record.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Note", systemImage: "note.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(note)
                                .font(.body)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.cardBackground)
                                .subtleShadow()
                        )
                    }

                    // TAGS
                    if let tags = bookmark.record.tags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Tags", systemImage: "tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.cardBackground)
                                .subtleShadow()
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            router.presentedSheet = .composePost(quotedPost: nil, replyTo: nil, bookmark: bookmark)
                        } label: { Label("Share to Bluesky", systemImage: "text.bubble") }
                        Button {
                            UIPasteboard.general.string = bookmark.record.url
                        } label: { Label("Copy Link", systemImage: "link") }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.mintAccent)
                    }
                }
            }
        } else {
            VStack(spacing: 20) {
                Text("⚠️ BOOKMARK NOT FOUND")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                    .padding()
                
                Text("Looking for bookmark with ID:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(bookmarkId)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                
                Text("Total bookmarks in cache: \(bookmarkManager.bookmarks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            //.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.yellow.opacity(0.3))
        }
    }
}

private struct HeaderThumbnail: View {
    let imageUrl: String?

    var body: some View {
        Group {
            if let imageUrl, let url = URL(string: imageUrl) {
                WebImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack { Rectangle().fill(.gray.opacity(0.25)); ProgressView() }
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        Rectangle().fill(.gray.opacity(0.25))
                    }
                }
            } else {
                ZStack {
                    Rectangle().fill(.gray.opacity(0.2))
                    Image(systemName: "link").font(.title2).foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}