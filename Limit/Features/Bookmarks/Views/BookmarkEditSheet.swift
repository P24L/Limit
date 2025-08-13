//
//  BookmarkEditSheet+Design.swift
//  Limit
//
//  A refreshed, modern design for the bookmark editor.
//  - Card-based layout with soft shadows and rounded corners
//  - Hero preview with site favicon + cover
//  - Sticky bottom action bar (Save / Delete)
//  - Token-style tags & pill list picker
//  - Subtle, consistent section headers
//
//  Created by Assistant on 11.08.2025.
//

import SwiftUI
import SwiftData
import SDWebImageSwiftUI

struct BookmarkEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(BlueskyClient.self) private var client

    @State private var editState = BookmarkEditState()
    @State private var showDeleteAlert = false
    @State private var showOptions = false

    let bookmarkId: String?

    init(bookmarkId: String? = nil) {
        self.bookmarkId = bookmarkId
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    headerPreview
                    sectionCard { urlSection }
                    sectionCard { metadataSection }
                    sectionCard { descriptionSection }
                    sectionCard { noteSection }
                    // Only show AI Summary for existing bookmarks with summary
                    if editState.isEditMode && !editState.summary.isEmpty {
                        sectionCard { aiSummarySection }
                    }
                    sectionCard { tagsSection }
                    sectionCard { listsSection }
                    if showOptions { sectionCard { optionsSection } }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color(.systemBackground), location: 0),
                        .init(color: Color(.secondarySystemBackground), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            )
            .toolbarTitleDisplayMode(.inline)
            .navigationTitle(editState.isEditMode ? "Edit Bookmark" : "New Bookmark")
            .toolbar { topBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomActionBar }
            .alert("Delete Bookmark", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { Task { await deleteBookmark() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this bookmark? This action cannot be undone.")
            }
        }
        .task { await onAppearTask() }
    }
}

// MARK: - Top Bar
private extension BookmarkEditSheet {
    @ToolbarContentBuilder
    var topBar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                Button { withAnimation(.spring(duration: 0.35)) { showOptions.toggle() } } label: {
                    Image(systemName: showOptions ? "slider.horizontal.2.square" : "slider.horizontal.3")
                        .imageScale(.medium)
                }
                .accessibilityLabel("Options")

                Button(action: { Task { await saveBookmark() } }) {
                    Text("Save")
                        .fontWeight(.semibold)
                }
                .disabled(editState.url.isEmpty || editState.title.isEmpty || editState.isSaving)
            }
        }
    }
}

// MARK: - Header Preview
private extension BookmarkEditSheet {
    var headerPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let imageUrl = editState.imageUrl, let url = URL(string: imageUrl) {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .transition(.fade(duration: 0.25))
                    } else {
                        Rectangle().fill(.secondary.opacity(0.15))
                            .overlay(
                                Image(systemName: "bookmark.square")
                                    .font(.system(size: 40, weight: .regular))
                                    .opacity(0.4)
                            )
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.black.opacity(0.06))
                )

                HStack(spacing: 10) {
                    faviconView(for: editState.url)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(editState.title.isEmpty ? "Untitled" : editState.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(domain(from: editState.url))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    .ultraThinMaterial, in: Capsule(style: .continuous)
                )
                .padding(12)
            }
        }
    }

    func faviconView(for urlString: String) -> some View {
        let host = domain(from: urlString)
        let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
        return Group {
            if let faviconURL {
                WebImage(url: faviconURL)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.05))
                    )
            } else {
                Image(systemName: "globe")
                    .frame(width: 22, height: 22)
            }
        }
    }
}

// MARK: - Sections (Cards)
private extension BookmarkEditSheet {
    @ViewBuilder
    func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.black.opacity(0.04))
            )
            .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }
}

// MARK: - URL Section
private extension BookmarkEditSheet {
    var urlSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "URL", systemImage: "link")
            HStack(spacing: 10) {
                TextField("https://example.com", text: $editState.url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .fontDesign(.monospaced)
                    .textFieldStyle(.roundedBorder)

                if editState.isLoading { ProgressView().scaleEffect(0.8) }

                if !editState.url.isEmpty && !editState.isLoading {
                    Button { Task { await editState.fetchMetadata() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.mintAccent)
                }
            }
        }
    }
}

// MARK: - Metadata Section
private extension BookmarkEditSheet {
    var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Title", systemImage: "textformat")
            TextField("Enter title", text: $editState.title)
                .textFieldStyle(.roundedBorder)

            if let imageUrl = editState.imageUrl, let url = URL(string: imageUrl) {
                ZStack(alignment: .topTrailing) {
                    WebImage(url: url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.05))
                        )
                    Button {
                        withAnimation(.spring) { editState.imageUrl = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            }
        }
    }
}

// MARK: - Description
private extension BookmarkEditSheet {
    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Description", systemImage: "text.alignleft")
            VStack(spacing: 6) {
                TextEditor(text: $editState.description)
                    .frame(minHeight: 66, maxHeight: 140)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.06))
                    )
            }
        }
    }
}

// MARK: - Note
private extension BookmarkEditSheet {
    var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Personal Note", systemImage: "note.text")
            TextEditor(text: $editState.note)
                .frame(minHeight: 56, maxHeight: 120)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.06))
                )
        }
    }
}

// MARK: - AI Summary
private extension BookmarkEditSheet {
    var aiSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title: "AI Summary", systemImage: "sparkles")
                Spacer()
                if !editState.url.isEmpty && editState.summary.isEmpty {
                    Button {
                        Task { await editState.generateAISummary() }
                    } label: {
                        if editState.isGeneratingAISummary { ProgressView().scaleEffect(0.7) }
                        else { Label("Generate", systemImage: "wand.and.stars") }
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .tint(.mintAccent)
                    .disabled(editState.isGeneratingAISummary)
                }
            }

            if !editState.summary.isEmpty {
                DisclosureGroup("Show Summary") {
                    Text(editState.summary)
                        .font(.footnote)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.06)))
                }
                .disclosureGroupStyle(.automatic)
            }
        }
    }
}

// MARK: - Tags
private extension BookmarkEditSheet {
    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Tags", systemImage: "tag")

            HStack(spacing: 8) {
                TextField("Add tag", text: $editState.tagInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { editState.addTag() }
                    .submitLabel(.done)
                Button("Add") { editState.addTag() }
                    .buttonStyle(.bordered)
                    .disabled(editState.tagInput.isEmpty)
            }

            if !editState.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(editState.tags, id: \.self) { tag in
                        TagChip(tag: tag) { editState.removeTag(tag) }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Lists
private extension BookmarkEditSheet {
    var listsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Lists", systemImage: "folder")

            if editState.availableLists.isEmpty {
                Label("No lists available", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(editState.availableLists, id: \.uri) { list in
                        let isSelected = editState.selectedLists.contains(list.uri)
                        Button {
                            withAnimation(.snappy) {
                                if isSelected { editState.selectedLists.remove(list.uri) }
                                else { editState.selectedLists.insert(list.uri) }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? .mintAccent : .secondary)
                                Text(list.record.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.mintAccent.opacity(0.12) : Color(.tertiarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Color.mintAccent.opacity(0.5) : .black.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Options
private extension BookmarkEditSheet {
    var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Options", systemImage: "gear")
            Toggle(isOn: $editState.pinned) {
                Label("Pin to top", systemImage: "pin.fill")
            }
            .toggleStyle(.switch)
            .tint(.mintAccent)

            Toggle(isOn: $editState.archived) {
                Label("Archive", systemImage: "archivebox")
            }
            .toggleStyle(.switch)
        }
    }
}

// MARK: - Bottom Action Bar
private extension BookmarkEditSheet {
    var bottomActionBar: some View {
        VStack(spacing: 10) {
            Divider()
            HStack(spacing: 12) {
                if editState.isEditMode {
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete", systemImage: "trash")
                            .frame(maxWidth: 120)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    Task { await saveBookmark() }
                } label: {
                    HStack(spacing: 8) {
                        if editState.isSaving { ProgressView() }
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mintAccent)
                .disabled(editState.url.isEmpty || editState.title.isEmpty || editState.isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .padding(.top, 6)
            .background(.bar)
        }
    }
}

// MARK: - Shared Helpers
private extension BookmarkEditSheet {
    func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    func domain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

// MARK: - Actions
private extension BookmarkEditSheet {
    func onAppearTask() async {
        editState.setup(bookmarkManager: bookmarkManager, client: client)

        if let bookmarkId = bookmarkId, let bookmark = bookmarkManager.bookmarks.first(where: { $0.uri.contains(bookmarkId) }) {
            // Edit mode - load existing bookmark
            editState.loadBookmark(bookmark)
        } else {
            // Create mode - check clipboard for URL
            editState.checkClipboard()
            if !editState.url.isEmpty {
                await editState.fetchMetadata()
            }
        }
    }

    func saveBookmark() async {
        do {
            try await editState.save()
            dismiss()
        } catch {
            DevLogger.shared.log("BookmarkEditSheet - Save failed: \(error)")
            editState.error = error.localizedDescription
        }
    }

    func deleteBookmark() async {
        guard let bookmark = editState.originalBookmark else { return }
        do {
            try await bookmarkManager.deleteBookmark(uri: bookmark.uri)
            dismiss()
        } catch {
            DevLogger.shared.log("BookmarkEditSheet - Delete failed: \(error)")
        }
    }
}

// MARK: - Supporting Views
struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(.tertiarySystemBackground))
        )
        .overlay(
            Capsule().stroke(.black.opacity(0.06))
        )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxWidth: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > width && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                maxWidth = max(maxWidth, currentX - spacing)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
