//
//  ComposePostView.swift
//  Limit
//
//  Created by Assistant on 17.07.2025.
//

import SwiftUI
import PhotosUI
import ATProtoKit
import Combine

struct ComposePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MultiAccountClient.self) private var client
    @Environment(AppRouter.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var viewModel = PostComposerViewModel()
    @State private var showImagePicker = false
    @State private var showVideoPicker = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var keyboardHeight: CGFloat = 0
    @State private var cursorFrame: CGRect = .zero
    
    @FocusState private var isTextFieldFocused: Bool
    
    let quotedPost: TimelinePostWrapper?
    let replyTo: TimelinePostWrapper?
    let bookmark: BookmarkView?
    let initialText: String?
    
    init(quotedPost: TimelinePostWrapper? = nil, replyTo: TimelinePostWrapper? = nil, bookmark: BookmarkView? = nil, initialText: String? = nil) {
        self.quotedPost = quotedPost
        self.replyTo = replyTo
        self.bookmark = bookmark
        self.initialText = initialText
    }
    
    var body: some View {
        NavigationView {
            let colors = themeManager.colors
            VStack(spacing: 0) {
                // Header
                ComposeHeaderView(
                    canPost: viewModel.canPost,
                    isPosting: viewModel.isPosting,
                    onCancel: { dismiss() },
                    onPost: {
                        Task {
                            do {
                                try await viewModel.submitPost(using: client)
                                // Switch to home tab before dismissing
                                router.selectedTab = .timeline
                                dismiss()
                            } catch {
                                // Error is handled in viewModel
                            }
                        }
                    }
                )
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Reply preview - show if this is a reply
                        if let replyTo = replyTo {
                            ReplyPreview(post: replyTo)
                        }
                        
                        // Thread mode indicator
                        if viewModel.isThreadMode {
                            ThreadModeIndicator(
                                drafts: viewModel.allDrafts,
                                currentIndex: viewModel.allDrafts.firstIndex(where: { $0.id == viewModel.currentDraft.id }) ?? 0,
                                onSelect: { index in
                                    viewModel.switchToThreadPost(at: index)
                                }
                            )
                        }
                        
                        // Main text editor
                        RichTextEditor(
                            text: $viewModel.currentDraft.text,
                            displayText: viewModel.currentDraft.displayText,
                            facets: viewModel.currentDraft.facets,
                            onTextChange: { newText in
                                viewModel.textDidChange(newText)
                            },
                            onCursorFrameChange: { frame in
                                cursorFrame = frame
                            }
                        )
                        .focused($isTextFieldFocused)
                        .frame(minHeight: 120)
                        .padding(.horizontal)
                        
                        // Mention suggestions below current line
                        if viewModel.showMentionSuggestions {
                            SimpleMentionSuggestionsView(
                                suggestions: viewModel.mentionSuggestions,
                                isLoading: viewModel.isLoadingSuggestions,
                                onSelect: { suggestion in
                                    viewModel.selectMention(suggestion)
                                }
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .offset(y: -10) // Slight offset to bring closer to text
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.easeInOut(duration: 0.2), value: viewModel.showMentionSuggestions)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Don't propagate tap to parent
                            }
                        }
                        
                        // Media preview
                        if !viewModel.currentDraft.images.isEmpty {
                            ImagePreviewGrid(
                                images: viewModel.currentDraft.images,
                                onRemove: { index in
                                    viewModel.removeImage(at: index)
                                }
                            )
                            .padding(.horizontal)
                        }
                        
                        if let video = viewModel.currentDraft.video {
                            VideoPreviewView(
                                video: video,
                                onRemove: {
                                    viewModel.removeVideo()
                                }
                            )
                            .padding(.horizontal)
                        }
                        
                        // External link preview
                        if let linkPreview = viewModel.currentDraft.externalLink {
                            LinkPreviewCard(preview: linkPreview)
                                .padding(.horizontal)
                        }
                        
                        // Quoted post preview - show only if current draft has quoted post
                        if viewModel.currentDraft.quotedPost != nil, let quotedPost = quotedPost {
                            QuotedPostPreview(post: quotedPost)
                                .padding(.horizontal)
                        }
                        
                        // Validation error
                        if let error = viewModel.validationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, keyboardHeight > 0 ? 60 : 100)
                }
                
                // Bottom toolbar
                ComposeToolbar(
                    characterCount: viewModel.currentDraft.characterCount,
                    remainingCharacters: viewModel.currentDraft.remainingCharacters,
                    canAddMedia: viewModel.currentDraft.images.isEmpty && viewModel.currentDraft.video == nil,
                    languages: viewModel.currentDraft.languages,
                    onAddImage: { showImagePicker = true },
                    onAddVideo: { showVideoPicker = true },
                    onToggleLanguage: { locale in
                        viewModel.toggleLanguage(locale)
                    },
                    onAddThread: {
                        viewModel.addThreadPost()
                        // Keep keyboard open and focus on new post
                        isTextFieldFocused = true
                    }
                )
                .background(colors.backgroundSecondary)
                .overlay(alignment: .top) {
                    Divider()
                }
            }
            .onAppear {
                isTextFieldFocused = true
                if let quotedPost = quotedPost {
                    viewModel.setQuotedPost(quotedPost)
                }
                if let replyTo = replyTo {
                    viewModel.setReplyTo(replyTo)
                }
                
                // Set bookmark as external link if provided
                if let bookmark = bookmark {
                    setupBookmarkAsExternalLink(bookmark)
                }
                
                // Prefill initial text if provided (e.g., feedback mention)
                if let initial = initialText, !initial.isEmpty {
                    viewModel.currentDraft.text = initial
                    viewModel.textDidChange(initial)
                }
                
                // Configure handle validator
                if let protoClient = client.protoClient {
                    let validator = HandleValidator(atProtoKit: protoClient)
                    viewModel.configureHandleValidator(validator)
                }
            }
            .onReceive(keyboardPublisher) { height in
                withAnimation(.easeOut(duration: 0.16)) {
                    keyboardHeight = height
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss mention suggestions when tapping outside
                if viewModel.showMentionSuggestions {
                    viewModel.dismissMentionSuggestions()
                }
            }
            .photosPicker(
                isPresented: $showImagePicker,
                selection: $selectedImages,
                maxSelectionCount: 4 - viewModel.currentDraft.images.count,
                matching: .images
            )
            .onChange(of: selectedImages) { _, newItems in
                Task {
                    var images: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    
                    if !images.isEmpty {
                        try? await viewModel.addImages(images)
                    }
                    selectedImages = []
                }
            }
            .photosPicker(
                isPresented: $showVideoPicker,
                selection: $selectedVideos,
                maxSelectionCount: 1,
                matching: .videos
            )
            .onChange(of: selectedVideos) { _, newVideos in
                Task {
                    guard let video = newVideos.first else { return }
                    
                    do {
                        if let data = try await video.loadTransferable(type: Data.self) {
                            // TODO: Add video validation and conversion to MP4
                            try viewModel.addVideo(data: data, altText: nil)
                        }
                    } catch {
                        DevLogger.shared.log("ComposePostView - Failed to load video: \(error)")
                    }
                    
                    selectedVideos = []
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupBookmarkAsExternalLink(_ bookmark: BookmarkView) {
        // Set flag to indicate this is a bookmark share
        viewModel.currentDraft.isBookmarkShare = true
        
        // Set default text with article URL at the end
        var shareText = "Check out this bookmark I saved: \(bookmark.record.title)"
        shareText += "\n\n\(bookmark.record.url)"
        viewModel.currentDraft.text = shareText
        
        // Create external link preview using universal link instead of article URL
        if let universalLink = BookmarkShareUtils.generateUniversalLink(for: bookmark.uri) {
            viewModel.currentDraft.externalLink = ExternalLinkPreview(
                url: universalLink,
                title: bookmark.record.title,
                description: bookmark.record.description ?? "View this bookmark in Limit app",
                thumbnailURL: bookmark.record.imageUrl.flatMap { URL(string: $0) }
            )
        } else if let url = URL(string: bookmark.record.url) {
            // Fallback to article URL if universal link generation fails
            viewModel.currentDraft.externalLink = ExternalLinkPreview(
                url: url,
                title: bookmark.record.title,
                description: bookmark.record.description,
                thumbnailURL: bookmark.record.imageUrl.flatMap { URL(string: $0) }
            )
        }
        
        // Trigger text parsing for facets
        viewModel.textDidChange(viewModel.currentDraft.text)
    }
}

// MARK: - Keyboard Publisher
private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
    Publishers.Merge(
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
            },
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
    )
    .eraseToAnyPublisher()
}

// MARK: - Mention Suggestions View

struct SimpleMentionSuggestionsView: View {
    let suggestions: [HandleSuggestion]
    let isLoading: Bool
    let onSelect: (HandleSuggestion) -> Void
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        let colors = themeManager.colors
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && suggestions.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(colors.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !suggestions.isEmpty {
                ForEach(Array(suggestions.prefix(5)), id: \.handle) { suggestion in
                    SimpleMentionRow(
                        suggestion: suggestion,
                        onTap: { onSelect(suggestion) }
                    )
                    
                    if suggestion.handle != suggestions.prefix(5).last?.handle {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
        }
        .background(colors.backgroundPrimary)
    }
}

struct SimpleMentionRow: View {
    let suggestion: HandleSuggestion
    let onTap: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        let colors = themeManager.colors
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Avatar
                Group {
                    if let avatarURL = suggestion.avatarURL {
                        AsyncImage(url: URL(string: avatarURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(colors.backgroundSecondary.opacity(0.5))
                        }
                    } else {
                        Circle()
                            .fill(colors.backgroundSecondary.opacity(0.5))
                            .overlay(
                                Text(String(suggestion.handle.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(colors.textSecondary)
                            )
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    if let displayName = suggestion.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.subheadline)
                            .foregroundColor(colors.textPrimary)
                            .lineLimit(1)
                    }
                    
                    Text("@\(suggestion.handle)")
                        .font(.caption)
                        .foregroundColor(colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views

struct ComposeHeaderView: View {
    let canPost: Bool
    let isPosting: Bool
    let onCancel: () -> Void
    let onPost: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let colors = themeManager.colors
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .foregroundColor(colors.accent)

            Spacer()

            if isPosting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            } else {
                Button("Post") {
                    onPost()
                }
                .fontWeight(.semibold)
                .foregroundColor(canPost ? Color.white : colors.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(canPost ? colors.accent : colors.backgroundSecondary.opacity(0.6))
                )
                .disabled(!canPost)
            }
        }
        .padding()
    }
}

struct ThreadModeIndicator: View {
    let drafts: [PostDraft]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(drafts.indices, id: \.self) { index in
                    ThreadPostIndicator(
                        number: index + 1,
                        isActive: index == currentIndex,
                        hasContent: !drafts[index].text.isEmpty
                    )
                    .onTapGesture {
                        onSelect(index)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ThreadPostIndicator: View {
    let number: Int
    let isActive: Bool
    let hasContent: Bool
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let colors = themeManager.colors
        VStack(spacing: 4) {
            Circle()
                .fill(
                    isActive
                        ? colors.accent
                        : (hasContent ? colors.accentMuted : colors.backgroundSecondary.opacity(0.6))
                )
                .frame(width: 30, height: 30)
                .overlay(
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                )

            if isActive {
                Text("Post \(number)")
                    .font(.caption2)
                    .foregroundColor(colors.textSecondary)
            }
        }
    }
}

struct VideoPreviewView: View {
    let video: VideoAttachment
    let onRemove: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let colors = themeManager.colors
        HStack {
            Image(systemName: "video.fill")
                .font(.title2)
                .foregroundColor(colors.accent)

            VStack(alignment: .leading) {
                Text("Video")
                    .font(.subheadline)
                Text("\(String(format: "%.1f", video.sizeInMB)) MB")
                    .font(.caption)
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(colors.textSecondary)
            }
        }
        .padding()
        .background(colors.backgroundSecondary.opacity(0.6))
        .cornerRadius(8)
    }
}

struct LinkPreviewCard: View {
    let preview: ExternalLinkPreview
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let colors = themeManager.colors
        HStack(spacing: 12) {
            if let thumbnailURL = preview.thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(colors.backgroundSecondary.opacity(0.5))
                        .frame(width: 60, height: 60)
                }
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(preview.title)
                    .font(.subheadline)
                    .foregroundColor(colors.textPrimary)
                    .lineLimit(2)

                if let description = preview.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(colors.textSecondary)
                        .lineLimit(2)
                }

                Text(preview.url.host() ?? "")
                    .font(.caption2)
                    .foregroundColor(colors.accent)
            }

            Spacer()
        }
        .padding()
        .background(colors.backgroundSecondary.opacity(0.6))
        .cornerRadius(12)
    }
}
