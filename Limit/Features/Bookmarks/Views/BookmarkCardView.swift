//
//  BookmarkCardView.swift
//  Limit
//
//  Created by Assistant on 24.07.2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct BookmarkCardView: View {
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(AppRouter.self) private var router

    let bookmark: BookmarkView

    // UI State
    @State private var isSummaryPressed = false
    @State private var isSharing = false
    @State private var showShareConfirmation = false

    // Design tokens
    private let cornerRadius: CGFloat = 14
    private let hPadding: CGFloat = 12
    private let vPadding: CGFloat = 10
    private let thumbSize: CGFloat = 88

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: Header
            HStack(alignment: .top, spacing: 12) {
                thumbnail(size: thumbSize)

                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(bookmark.record.title.isEmpty ? "Untitled" : bookmark.record.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                        .foregroundStyle(.primary)

                    // Meta (host · relative time)
                    HStack(spacing: 6) {
                        if !host(from: bookmark.record.url).isEmpty {
                            Text(host(from: bookmark.record.url))
                        }
                        if !host(from: bookmark.record.url).isEmpty {
                            Text("•")
                        }
                        Text(bookmark.record.createdAt, style: .relative)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    // Description
                    if let description = bookmark.record.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }

            // Summary chip
            if let summary = bookmark.record.summary, !summary.isEmpty {
                summaryChip(summary)
            }

            // Tags
            if let tags = bookmark.record.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(Color.gray.opacity(0.12))
                                )
                                .overlay(
                                    Capsule().stroke(Color.gray.opacity(0.16), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }

            Divider().padding(.top, 4)

            // MARK: Footer actions
            HStack(spacing: 10) {
                // Open
                Button {
                    if let url = URL(string: bookmark.record.url) {
                        router.navigateTo(.safari(url: url))
                    }
                } label: {
                    actionLabel(system: "safari", title: "Open")
                }
                .buttonStyle(.plain)

                // Share (menu)
                Menu {
                    Button {
                        Task { await shareBookmark() }
                    } label: { Label("Share to Bluesky", systemImage: "text.bubble") }

                    Button { shareDeepLink() } label: { Label("Copy Link", systemImage: "link") }
                    Button { shareToSystem() } label: { Label("Share...", systemImage: "square.and.arrow.up") }
                } label: {
                    HStack(spacing: 6) {
                        if isSharing { ProgressView().scaleEffect(0.7) }
                        else { Image(systemName: "square.and.arrow.up").font(.caption) }
                        Text("Share").font(.caption)
                    }
                    .foregroundColor(.mintAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSharing)

                // Edit
                Button {
                    router.presentedSheet = .bookmarkEdit(id: extractBookmarkId())
                } label: {
                    actionLabel(system: "pencil", title: "Edit")
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(.vertical, vPadding)
        .padding(.horizontal, hPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.cardBackground)
                .subtleShadow()
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: bookmark.record.url) {
                router.navigateTo(.safari(url: url))
            }
        }
        .saveConfirmationOverlay(
            show: $showShareConfirmation,
            text: "Link Copied!",
            icon: "link.circle.fill"
        )
        .onAppear {
            bookmarkManager.trackAccess(for: bookmark.uri)
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func thumbnail(size: CGFloat) -> some View {
        Group {
            if let imageUrl = bookmark.record.imageUrl, let url = URL(string: imageUrl) {
                WebImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.25))
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.25))
                    }
                }
                .aspectRatio(1, contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let imageBlob = getCachedImageBlob(), let uiImage = UIImage(data: imageBlob) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.2))
                    Image(systemName: "link").font(.title3).foregroundStyle(.secondary)
                }
                .frame(width: size, height: size)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func summaryChip(_ text: String) -> some View {
        Button {
            router.presentedSheet = .aiSummary(bookmark: bookmark)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles").font(.caption).foregroundStyle(.blue)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .scaleEffect(isSummaryPressed ? 0.97 : 1)
        .onLongPressGesture(minimumDuration: 0.08) { } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.12)) { isSummaryPressed = pressing }
        }
    }

    // MARK: - Helpers
    private func host(from urlString: String) -> String {
        guard let url = URL(string: urlString), let h = url.host() ?? url.host else { return "" }
        return h.replacingOccurrences(of: "www.", with: "")
    }

    private func extractBookmarkId() -> String {
        let components = bookmark.uri.split(separator: "/")
        return components.last.map(String.init) ?? bookmark.uri
    }

    // MARK: - Share helpers
    private func shareBookmark() async {
        await MainActor.run {
            router.presentedSheet = .composePost(quotedPost: nil, replyTo: nil, bookmark: bookmark)
        }
    }

    private func shareDeepLink() {
        // Use universal link instead of deep link
        guard let universalLink = BookmarkShareUtils.generateUniversalLink(for: bookmark.uri) else {
            DevLogger.shared.log("BookmarkCardView - Failed to generate universal link")
            return
        }
        
        UIPasteboard.general.string = universalLink.absoluteString
        withAnimation { showShareConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showShareConfirmation = false }
        }
        DevLogger.shared.log("BookmarkCardView - Universal link copied: \(universalLink.absoluteString)")
    }

    private func shareToSystem() {
        // Use universal link instead of deep link
        guard let universalLink = BookmarkShareUtils.generateUniversalLink(for: bookmark.uri) else {
            DevLogger.shared.log("BookmarkCardView - Failed to generate universal link for system share")
            return
        }
        
        let shareText = BookmarkShareUtils.generateShareText(
            title: bookmark.record.title,
            description: bookmark.record.description,
            universalLink: universalLink
        )
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var top = rootVC
            while let presented = top.presentedViewController { top = presented }
            activityVC.popoverPresentationController?.sourceView = top.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            top.present(activityVC, animated: true)
        }
    }

    // Note: generateDeepLink() removed - now using BookmarkShareUtils for universal links

    private func getCachedImageBlob() -> Data? { nil }

    // MARK: - Small action label
    private func actionLabel(system: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system).font(.caption)
            Text(title).font(.caption)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }
}