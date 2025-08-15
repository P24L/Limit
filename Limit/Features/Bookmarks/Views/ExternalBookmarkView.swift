//
//  ExternalBookmarkView.swift
//  Limit
//
//  Created by Assistant on 10.08.2025.
//

import SwiftUI
import SDWebImageSwiftUI
import ATProtoKit
import SwiftData

/// View for displaying external bookmarks shared via deep links
/// Read-only view that allows saving to user's own bookmarks
struct ExternalBookmarkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(BlueskyClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    let bookmarkUri: String
    let isOwner: Bool
    
    @State private var externalBookmark: BookmarkView?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isSaving = false
    @State private var showSaveConfirmation = false
    @State private var authorHandle: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading bookmark...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else if let error = error {
                VStack(spacing: 16) {
                    if error == "deleted" {
                        // UI for deleted bookmark
                        Image(systemName: "bookmark.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Bookmark was deleted")
                            .font(.headline)
                        Text("This bookmark no longer exists or was removed by the author")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Close") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        // UI for other errors
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Failed to load bookmark")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") { Task { await loadExternalBookmark() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            } else if let bookmark = externalBookmark {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header image
                        HeaderThumbnail(imageUrl: bookmark.record.imageUrl)

                        // Optional shared-by badge
                        if let handle = authorHandle, !isOwner {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle").font(.caption)
                                Text("Shared by @\(handle)").font(.caption).foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                            )
                            .padding(.horizontal, 16)
                        }

                        // Title + meta + primary actions
                        VStack(alignment: .leading, spacing: 12) {
                            Text(bookmark.record.title.isEmpty ? "Untitled" : bookmark.record.title)
                                .font(.title3).fontWeight(.semibold)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)

                            HStack(spacing: 8) {
                                let h = host(from: bookmark.record.url)
                                if !h.isEmpty { Text(h) }
                                if !h.isEmpty { Text("•") }
                                Text(bookmark.record.createdAt, style: .relative)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

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
                                        router.presentedSheet = .composePost(quotedPost: nil, replyTo: nil, bookmark: bookmark)
                                    } label: { Label("Share to Bluesky", systemImage: "text.bubble") }
                                    Button {
                                        UIPasteboard.general.string = bookmark.record.url
                                    } label: { Label("Copy Link", systemImage: "link") }
                                    Button {
                                        let deep = generateDeepLink()
                                        let activityVC = UIActivityViewController(activityItems: [deep], applicationActivities: nil)
                                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let rootVC = windowScene.windows.first?.rootViewController {
                                            var top = rootVC
                                            while let presented = top.presentedViewController { top = presented }
                                            activityVC.popoverPresentationController?.sourceView = top.view
                                            activityVC.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
                                            top.present(activityVC, animated: true)
                                        }
                                    } label: { Label("Share...", systemImage: "square.and.arrow.up") }
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                            }

                            if !isOwner {
                                Button {
                                    Task { await saveToMyBookmarks() }
                                } label: {
                                    HStack {
                                        if isSaving { ProgressView().scaleEffect(0.9) }
                                        Image(systemName: "bookmark.fill")
                                        Text("Save to My Bookmarks")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.mintAccent)
                                .disabled(isSaving)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14).fill(Color.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        // Summary
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
                                        .lineLimit(8)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                }
                                .padding(12)
                                .background(Color.blue.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }

                        // Description
                        if let description = bookmark.record.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Description", systemImage: "text.justify")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(description)
                                    .font(.body)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14).fill(Color.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }

                        // Tags
                        if let tags = bookmark.record.tags, !tags.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Tags", systemImage: "tag").font(.caption).foregroundStyle(.secondary)
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
                                RoundedRectangle(cornerRadius: 14).fill(Color.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                    .padding(.top, 12)
                }
            } else {
                Text("No bookmark data available").foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle(isOwner ? "My Bookmark" : "Shared Bookmark")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task { await loadExternalBookmark() }
        .saveConfirmationOverlay(
            show: $showSaveConfirmation,
            text: "Saved to your bookmarks!",
            icon: "bookmark.fill"
        )
    }
    // Helper to extract host from url
    private func host(from urlString: String) -> String {
        guard let url = URL(string: urlString), let h = url.host() ?? url.host else { return "" }
        return h.replacingOccurrences(of: "www.", with: "")
    }
    
    
    // MARK: - Loading
    
    private func loadExternalBookmark() async {
        isLoading = true
        error = nil
        
        do {
            // Parse URI to get repo and rkey
            guard let (repo, rkey) = ATProtoUtils.extractRepoAndRkey(from: bookmarkUri) else {
                throw BookmarkError.invalidURL
            }
            
            // Fetch bookmark from AT Protocol
            guard let protoClient = client.protoClient else {
                throw BookmarkError.noClient
            }
            
            // Get the bookmark record
            let response = try await protoClient.getBookmark(repo: repo, rkey: rkey)
            
            // Convert to BookmarkView
            externalBookmark = BookmarkView(
                uri: bookmarkUri,
                cid: response.cid ?? "",
                record: response.value,
                author: repo
            )
            
            // Try to resolve author handle
            if !isOwner {
                authorHandle = try? await resolveHandle(for: repo)
            }
            
        } catch let apiError as ATAPIError {
            switch apiError {
            case .badRequest(let httpError):
                // Check if it's specifically a RecordNotFound error
                if httpError.error == "RecordNotFound" {
                    self.error = "deleted"  // Special flag for deleted bookmark
                    DevLogger.shared.log("ExternalBookmarkView - Bookmark was deleted (RecordNotFound)")
                } else {
                    self.error = "Failed to load bookmark. Please check your connection and try again."
                    DevLogger.shared.log("ExternalBookmarkView - Failed to load bookmark: \(apiError)")
                }
            case .notFound:
                // Keep this case for potential future API changes
                self.error = "deleted"
                DevLogger.shared.log("ExternalBookmarkView - Bookmark was deleted (404)")
            default:
                self.error = "Failed to load bookmark. Please check your connection and try again."
                DevLogger.shared.log("ExternalBookmarkView - Failed to load bookmark: \(apiError)")
            }
        } catch {
            self.error = "Failed to load bookmark. Please check your connection and try again."
            DevLogger.shared.log("ExternalBookmarkView - Failed to load bookmark: \(error)")
        }
        
        isLoading = false
    }
    
    private func resolveHandle(for did: String) async throws -> String? {
        guard let protoClient = client.protoClient else { return nil }
        
        do {
            let profile = try await protoClient.getProfile(for: did)
            return profile.actorHandle
        } catch {
            // Fallback to DID if handle resolution fails
            return did
        }
    }
    
    // MARK: - Actions
    
    private func saveToMyBookmarks() async {
        guard let bookmark = externalBookmark else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            // Create new bookmark with only public data
            // Don't copy: lists, note (personal data)
            try await bookmarkManager.createBookmark(
                url: bookmark.record.url,
                title: bookmark.record.title,
                description: bookmark.record.description,
                summary: bookmark.record.summary,
                note: nil,  // Don't copy personal note
                imageUrl: bookmark.record.imageUrl,
                imageBlob: nil,
                tags: bookmark.record.tags,  // Tags can be copied
                listUris: nil,  // Don't copy to other user's lists
                pinned: false,
                archived: false,
                reminder: nil,
                sourceUri: bookmarkUri  // Reference to original
            )
            
            showSaveConfirmation = true
            
            // Dismiss after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
            
        } catch {
            self.error = "Failed to save bookmark: \(error.localizedDescription)"
            DevLogger.shared.log("ExternalBookmarkView - Failed to save bookmark: \(error)")
        }
    }
    
    private func generateDeepLink() -> URL {
        // Generate deep link for sharing using ATProtoUtils
        guard let components = ATProtoUtils.parseURI(bookmarkUri) else {
            DevLogger.shared.log("ExternalBookmarkView - Failed to parse URI: \(bookmarkUri)")
            // Fallback to bookmark URL if available, otherwise Bluesky
            return URL(string: externalBookmark?.record.url ?? "https://bsky.app")!
        }
        
        // Format: limit://bookmark/{did}/{collection}/{rkey}
        let deepLink = "limit://bookmark/\(components.repo)/\(components.collection)/\(components.rkey)"
        DevLogger.shared.log("ExternalBookmarkView - Generated deep link: \(deepLink)")
        return URL(string: deepLink) ?? URL(string: "https://bsky.app")!
    }
}

// MARK: - Preview

#Preview {
    ExternalBookmarkView(
        bookmarkUri: "at://did:plc:example/app.bsky.bookmark/abc123",
        isOwner: false
    )
    .environment(BookmarkManager(
        context: ModelContext(try! ModelContainer(for: CachedBookmark.self)),
        client: BlueskyClient()
    ))
}

// MARK: - HeaderThumbnail

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
            RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}