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
    @Environment(BlueskyClient.self) private var client
    @Environment(AppRouter.self) private var router
    
    @State private var viewModel = PostComposerViewModel()
    @State private var showImagePicker = false
    @State private var showVideoPicker = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var keyboardHeight: CGFloat = 0
    
    @FocusState private var isTextFieldFocused: Bool
    
    let quotedPost: TimelinePostWrapper?
    
    init(quotedPost: TimelinePostWrapper? = nil) {
        self.quotedPost = quotedPost
    }
    
    var body: some View {
        NavigationView {
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
                            }
                        )
                        .focused($isTextFieldFocused)
                        .frame(minHeight: 120)
                        .padding(.horizontal)
                        
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
                .background(Color(UIColor.systemBackground))
                .overlay(alignment: .top) {
                    Divider()
                }
            }
            .onAppear {
                isTextFieldFocused = true
                if let quotedPost = quotedPost {
                    viewModel.setQuotedPost(quotedPost)
                }
            }
            .onReceive(keyboardPublisher) { height in
                withAnimation(.easeOut(duration: 0.16)) {
                    keyboardHeight = height
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

// MARK: - Supporting Views

struct ComposeHeaderView: View {
    let canPost: Bool
    let isPosting: Bool
    let onCancel: () -> Void
    let onPost: () -> Void
    
    var body: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .foregroundColor(.mintAccent)
            
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
                .foregroundColor(canPost ? .white : .gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(canPost ? Color.mintAccent : Color.gray.opacity(0.3))
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
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.mintAccent : (hasContent ? Color.mintInactive : Color.gray.opacity(0.3)))
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
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct VideoPreviewView: View {
    let video: VideoAttachment
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "video.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text("Video")
                    .font(.subheadline)
                Text("\(String(format: "%.1f", video.sizeInMB)) MB")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct LinkPreviewCard: View {
    let preview: ExternalLinkPreview
    
    var body: some View {
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
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                }
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.title)
                    .font(.subheadline)
                    .lineLimit(2)
                
                if let description = preview.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(preview.url.host() ?? "")
                    .font(.caption2)
                    .foregroundColor(.mintAccent)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

