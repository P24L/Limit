//
//  CreateBookmarkListView.swift
//  Limit
//
//  Created by Assistant on 22.07.2025.
//
//
//  CreateBookmarkListView.swift
//  Limit
//
//  Redesigned in a modern, card-based style consistent with BookmarkEditSheet redesign.
//  - Card sections with rounded corners and subtle borders/shadows
//  - Header preview with icon + color swatch
//  - Unified section headers
//  - Sticky bottom action bar (Create/Save)
//
//  Created by Assistant on 22.07.2025
//  Updated by Assistant on 11.08.2025
//

import SwiftUI

struct CreateBookmarkListView: View {
    @Environment(MultiAccountClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(\.dismiss) private var dismiss

    // Optional editing list - if provided, view operates in edit mode
    var editingList: BookmarkListView? = nil

    @State private var listName = ""
    @State private var listDescription = ""
    @State private var visibility: BookmarkListVisibility = .private
    @State private var selectedColor: String? = nil
    @State private var selectedIcon: BookmarkListIcon = .folder
    @State private var collaborativeUsers: [CollaborativeUser] = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showColorPicker = false
    @State private var isLoadingUsers = false
    @State private var showOptions = false

    @FocusState private var isNameFieldFocused: Bool

    // Edit mode helpers
    private var isEditMode: Bool { editingList != nil }
    private var navigationTitle: String { isEditMode ? "Edit Bookmark List" : "Create Bookmark List" }
    private var actionButtonTitle: String { isEditMode ? "Save Changes" : "Create Bookmark List" }
    private var actionButtonLoadingTitle: String { isEditMode ? "Saving..." : "Creating..." }
    private var isValidName: Bool { !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && listName.count <= 100 }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    headerPreview

                    sectionCard { nameSection }
                    sectionCard { descriptionSection }
                    sectionCard { visibilitySection }
                    sectionCard { iconSection }
                    sectionCard { colorSection }

                    if visibility == .collaborative {
                        sectionCard { collaborativeSection }
                    }

                    if let errorMessage { errorLabel(errorMessage) }

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
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { topBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomActionBar }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedColor: $selectedColor)
                    .presentationDetents([.height(500)])
                    .presentationDragIndicator(.visible)
            }
            .onAppear { onAppear() }
        }
    }
}

// MARK: - Top Bar
private extension CreateBookmarkListView {
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
                .opacity(0) // Reserved for future options; hidden for now to match Bookmark style

                Button(action: { Task { await primaryAction() } }) {
                    Text(isEditMode ? "Save" : "Create")
                        .fontWeight(.semibold)
                }
                .disabled(!isValidName || isCreating || listDescription.count > 1000)
            }
        }
    }
}

// MARK: - Header Preview
private extension CreateBookmarkListView {
    var headerPreview: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14).stroke(.black.opacity(0.06))
                    )
                Image(systemName: iconSystemName(for: selectedIcon))
                    .font(.system(size: 22, weight: .semibold))
            }
            .frame(width: 52, height: 52)
            .overlay(alignment: .bottomTrailing) {
                if let hex = selectedColor {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: hex))
                        .frame(width: 16, height: 16)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.06)))
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isValidName ? listName : "New Bookmark List")
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitleForHeader)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
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

    var subtitleForHeader: String {
        switch visibility {
        case .private: return "Private list"
        case .public: return "Public list"
        case .collaborative: return "Collaborative list"
        }
    }
}

// MARK: - Sections (Cards)
private extension CreateBookmarkListView {
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

    func sectionHeader(_ title: String, systemImage: String) -> some View {
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
}

// MARK: - Name
private extension CreateBookmarkListView {
    var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("List Name", systemImage: "text.cursor")
            TextField("Enter list name", text: $listName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isNameFieldFocused)
                .submitLabel(.done)
                .onSubmit { Task { await primaryActionIfValid() } }

            HStack {
                Text("\(listName.count)/100")
                    .font(.caption)
                    .foregroundStyle(listName.count > 100 ? .red : .secondary)
                Spacer()
            }
        }
    }
}

// MARK: - Description
private extension CreateBookmarkListView {
    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Description (optional)", systemImage: "text.alignleft")
            TextEditor(text: $listDescription)
                .frame(minHeight: 80, maxHeight: 160)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.06)))

            HStack {
                Text("\(listDescription.count)/1000")
                    .font(.caption)
                    .foregroundStyle(listDescription.count > 1000 ? .red : .secondary)
                Spacer()
            }
        }
    }
}

// MARK: - Visibility
private extension CreateBookmarkListView {
    var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Visibility", systemImage: "eye")
            Picker("Visibility", selection: $visibility) {
                Label("Private", systemImage: "lock.fill").tag(BookmarkListVisibility.private)
                Label("Public", systemImage: "globe").tag(BookmarkListVisibility.public)
                Label("Collaborative", systemImage: "person.2.fill").tag(BookmarkListVisibility.collaborative)
            }
            .pickerStyle(.segmented)

            Text(visibilityDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    var visibilityDescription: String {
        switch visibility {
        case .private: return "Only you can see and add bookmarks to this list"
        case .public: return "Anyone can view this list, but only you can add bookmarks"
        case .collaborative: return "Selected users can view and add bookmarks to this list"
        }
    }
}

// MARK: - Icons
private extension CreateBookmarkListView {
    var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Icon", systemImage: "square.grid.2x2")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                ForEach([BookmarkListIcon.folder, .list, .star, .tag], id: \.self) { icon in
                    let selected = selectedIcon == icon
                    Button { selectedIcon = icon } label: {
                        VStack {
                            Image(systemName: iconSystemName(for: icon))
                                .font(.title2)
                                .foregroundStyle(selected ? .white : .primary)
                        }
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selected ? Color.orange : Color(.systemGray5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Color.orange : Color(.systemGray3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func iconSystemName(for icon: BookmarkListIcon) -> String {
        switch icon {
        case .folder: return "folder.fill"
        case .list:   return "list.bullet"
        case .star:   return "star.fill"
        case .tag:    return "tag.fill"
        }
    }
}

// MARK: - Color
private extension CreateBookmarkListView {
    var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Color (optional)", systemImage: "paintpalette")
            Button {
                showColorPicker = true
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedColor.map { Color(hex: $0) } ?? Color(.systemGray5))
                        .frame(width: 30, height: 30)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), lineWidth: 1))

                    Text(selectedColor ?? "Select color")
                        .font(selectedColor == nil ? .subheadline : .system(.subheadline, design: .monospaced))
                        .foregroundStyle(.primary)

                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Collaborative
private extension CreateBookmarkListView {
    var collaborativeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Collaborators", systemImage: "person.2.fill")

            if isLoadingUsers {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading collaborative users...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                CollaborativeUsersView(collaborativeUsers: $collaborativeUsers)
            }
        }
    }
}

// MARK: - Error Label
private extension CreateBookmarkListView {
    func errorLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.red)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

// MARK: - Bottom Action Bar
private extension CreateBookmarkListView {
    var bottomActionBar: some View {
        VStack(spacing: 10) {
            Divider()
            HStack(spacing: 12) {
                Button {
                    Task { await primaryAction() }
                } label: {
                    HStack(spacing: 8) {
                        if isCreating { ProgressView() }
                        Text(isCreating ? actionButtonLoadingTitle : actionButtonTitle)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!isValidName || isCreating || listDescription.count > 1000)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .padding(.top, 6)
            .background(.bar)
        }
    }
}

// MARK: - Lifecycle / Actions
private extension CreateBookmarkListView {
    func onAppear() {
        if let editingList = editingList {
            // Pre-populate fields when editing
            loadEditingData(from: editingList)
        } else {
            isNameFieldFocused = true
        }
    }

    func primaryActionIfValid() async {
        guard isValidName && !isCreating else { return }
        await primaryAction()
    }

    func primaryAction() async {
        if isEditMode { await updateList() } else { await createList() }
    }
}

// MARK: - Original Business Logic (unchanged)
private extension CreateBookmarkListView {
    func createList() async {
        let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, trimmedName.count <= 100 else {
            errorMessage = "Please enter a valid list name (1-100 characters)"
            return
        }

        guard trimmedDescription.count <= 1000 else {
            errorMessage = "Description must be less than 1000 characters"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            // Convert collaborative user handles to DIDs if needed
            var permissions: BookmarkListPermissions? = nil
            if visibility == .collaborative && !collaborativeUsers.isEmpty {
                let dids = collaborativeUsers.map { $0.did }
                permissions = BookmarkListPermissions(canAdd: dids)
            }

            try await bookmarkManager.createBookmarkList(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                visibility: visibility,
                color: selectedColor,
                icon: selectedIcon,
                pinned: false,
                permissions: permissions
            )

            DevLogger.shared.log("CreateBookmarkListView.swift - Successfully created bookmark list: \(trimmedName)")
            dismiss()
        } catch {
            errorMessage = "Failed to create bookmark list: \(error.localizedDescription)"
            DevLogger.shared.log("CreateBookmarkListView.swift - Failed to create bookmark list: \(error)")
        }

        isCreating = false
    }

    func loadEditingData(from list: BookmarkListView) {
        listName = list.record.name
        listDescription = list.record.description ?? ""
        visibility = list.record.visibility
        selectedColor = list.record.color
        selectedIcon = list.record.icon ?? .folder

        // Load collaborative users if needed
        if visibility == .collaborative,
           let permissions = list.record.permissions,
           let canAddUsers = permissions.canAdd {
            isLoadingUsers = true
            Task { await loadCollaborativeUsers(from: canAddUsers) }
        }
    }

    func loadCollaborativeUsers(from dids: [String]) async {
        guard let protoClient = client.protoClient else {
            await MainActor.run { self.isLoadingUsers = false }
            return
        }

        var users: [CollaborativeUser] = []

        for did in dids {
            do {
                let actor = try await protoClient.getProfile(for: did)
                users.append(CollaborativeUser(
                    did: did,
                    handle: actor.actorHandle,
                    displayName: actor.displayName,
                    avatarURL: actor.avatarImageURL?.absoluteString
                ))
            } catch {
                users.append(CollaborativeUser(
                    did: did,
                    handle: did,
                    displayName: nil,
                    avatarURL: nil
                ))
            }
        }

        await MainActor.run {
            collaborativeUsers = users
            isLoadingUsers = false
        }
    }

    func updateList() async {
        guard let editingList = editingList else { return }

        let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, trimmedName.count <= 100 else {
            errorMessage = "Please enter a valid list name (1-100 characters)"
            return
        }

        guard trimmedDescription.count <= 1000 else {
            errorMessage = "Description must be less than 1000 characters"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            var permissions: BookmarkListPermissions? = nil
            if visibility == .collaborative && !collaborativeUsers.isEmpty {
                let dids = collaborativeUsers.map { $0.did }
                permissions = BookmarkListPermissions(canAdd: dids)
            } else if visibility != .collaborative {
                permissions = BookmarkListPermissions(canAdd: [])
            }

            let updates = BookmarkListUpdateInput(
                name: trimmedName,
                visibility: visibility,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                color: selectedColor,
                icon: selectedIcon,
                permissions: permissions
            )

            try await bookmarkManager.updateBookmarkList(
                listURI: editingList.uri,
                updates: updates
            )

            DevLogger.shared.log("CreateBookmarkListView.swift - Successfully updated bookmark list: \(trimmedName)")
            dismiss()
        } catch {
            errorMessage = "Failed to update bookmark list: \(error.localizedDescription)"
            DevLogger.shared.log("CreateBookmarkListView.swift - Failed to update bookmark list: \(error)")
        }

        isCreating = false
    }
}