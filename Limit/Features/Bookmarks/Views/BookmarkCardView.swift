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
    @Environment(ThemeManager.self) private var themeManager

    let bookmark: BookmarkView

    // UI State
    @State private var isSummaryPressed = false
    @State private var isSharing = false
    @State private var showShareConfirmation = false

    // Design tokens
    private let cornerRadius: CGFloat = 14
    private let hPadding: CGFloat = 12
    private let vPadding: CGFloat = 10

    var body: some View {
        let colors = themeManager.colors

        VStack(alignment: .leading, spacing: 12) {
            // MARK: Header
            HStack(alignment: .top, spacing: 12) {
                thumbnail()

                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(bookmark.record.title.isEmpty ? "Untitled" : bookmark.record.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                        .foregroundColor(colors.textPrimary)

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
                    .foregroundColor(colors.textSecondary)
                    .lineLimit(1)

                    // Description
                    if let description = bookmark.record.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundColor(colors.textSecondary)
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
                                .foregroundColor(colors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(colors.backgroundSecondary.opacity(0.6))
                                )
                                .overlay(
                                    Capsule().stroke(colors.border.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }

            //Divider().padding(.top, 4)

            // MARK: Footer actions
            HStack(spacing: 10) {
                // Open
                Button {
                    if let url = URL(string: bookmark.record.url) {
                        router.navigateTo(.safari(url: url))
                    }
                } label: {
                    Image(systemName: "safari")
                        .font(.caption)
                        .foregroundColor(colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(colors.backgroundSecondary.opacity(0.6))
                        .clipShape(Capsule())
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
                    .foregroundColor(colors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(colors.backgroundSecondary.opacity(0.6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSharing)

                // Archive/Unarchive
                Button {
                    Task { await toggleArchiveBookmark() }
                } label: {
                    Image(systemName: bookmark.record.archived == true ? "archivebox.fill" : "archivebox")
                        .font(.caption)
                        .foregroundColor(colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(colors.backgroundSecondary.opacity(0.6))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Edit
                Button {
                    router.presentedSheet = .bookmarkEdit(id: extractBookmarkId())
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(colors.backgroundSecondary.opacity(0.6))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(.vertical, vPadding)
        .padding(.horizontal, hPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(colors.backgroundSecondary)
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
    private func thumbnail() -> some View {
        let colors = themeManager.colors
        Group {
            if let imageUrl = bookmark.record.imageUrl, let url = URL(string: imageUrl) {
                WebImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12).fill(colors.backgroundSecondary.opacity(0.5))
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        RoundedRectangle(cornerRadius: 12).fill(colors.backgroundSecondary.opacity(0.5))
                    }
                }
                .aspectRatio(1, contentMode: .fill)
                .containerRelativeFrame(.horizontal, count: 4, span: 1, spacing: hPadding)
                .frame(minHeight: 88)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let imageBlob = getCachedImageBlob(), let uiImage = UIImage(data: imageBlob) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .containerRelativeFrame(.horizontal, count: 4, span: 1, spacing: hPadding)
                    .frame(minHeight: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(colors.backgroundSecondary.opacity(0.5))
                    Image(systemName: "link")
                        .font(.title3)
                        .foregroundColor(colors.textSecondary)
                }
                .containerRelativeFrame(.horizontal, count: 4, span: 1, spacing: hPadding)
                .frame(minHeight: 88)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colors.border.opacity(0.25), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func summaryChip(_ text: String) -> some View {
        let colors = themeManager.colors
        Button {
            router.presentedSheet = .aiSummary(bookmark: bookmark)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(colors.accent)
                Text(text)
                    .font(.caption)
                    .foregroundColor(colors.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(colors.textSecondary)
            }
            .padding(10)
            .background(colors.accent.opacity(0.08))
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
    
    private func toggleArchiveBookmark() async {
        // Toggle the archived state
        let newArchivedState = !(bookmark.record.archived ?? false)
        
        // Create a copy of the record with toggled archived state
        let updatedRecord = BookmarkRecord(
            url: bookmark.record.url,
            title: bookmark.record.title,
            createdAt: bookmark.record.createdAt,
            description: bookmark.record.description,
            summary: bookmark.record.summary,
            note: bookmark.record.note,
            imageUrl: bookmark.record.imageUrl,
            imageBlob: bookmark.record.imageBlob,
            tags: bookmark.record.tags,
            listUris: bookmark.record.listUris,
            pinned: bookmark.record.pinned,
            archived: newArchivedState,  // Toggle archived state
            reminder: bookmark.record.reminder,
            sourceUri: bookmark.record.sourceUri,
            encrypted: bookmark.record.encrypted,
            updatedAt: Date()  // Update the timestamp
        )
        
        do {
            try await bookmarkManager.updateBookmark(uri: bookmark.uri, record: updatedRecord)
            let action = newArchivedState ? "Archived" : "Unarchived"
            DevLogger.shared.log("BookmarkCardView - \(action) bookmark: \(bookmark.uri)")
        } catch {
            DevLogger.shared.log("BookmarkCardView - Failed to toggle archive state: \(error)")
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

}
