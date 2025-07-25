//
//  CreateBookmarkListView.swift
//  Limit
//
//  Created by Assistant on 22.07.2025.
//

import SwiftUI

struct CreateBookmarkListView: View {
    @Environment(BlueskyClient.self) private var client
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
    
    // Edit mode helpers
    private var isEditMode: Bool { editingList != nil }
    private var navigationTitle: String { isEditMode ? "Edit Bookmark List" : "Create Bookmark List" }
    private var actionButtonTitle: String { isEditMode ? "Save Changes" : "Create Bookmark List" }
    private var actionButtonLoadingTitle: String { isEditMode ? "Saving..." : "Creating..." }
    
    @FocusState private var isNameFieldFocused: Bool
    
    private var isValidName: Bool {
        !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && listName.count <= 100
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.headline)
                    
                    TextField("Enter list name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if isValidName && !isCreating {
                                Task {
                                    if isEditMode {
                                        await updateList()
                                    } else {
                                        await createList()
                                    }
                                }
                            }
                        }
                    
                    HStack {
                        Text("\(listName.count)/100")
                            .font(.caption)
                            .foregroundColor(listName.count > 100 ? .red : .secondary)
                        
                        Spacer()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (optional)")
                        .font(.headline)
                    
                    TextEditor(text: $listDescription)
                        .frame(height: 80)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    
                    HStack {
                        Text("\(listDescription.count)/1000")
                            .font(.caption)
                            .foregroundColor(listDescription.count > 1000 ? .red : .secondary)
                        
                        Spacer()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Visibility")
                        .font(.headline)
                    
                    Picker("Visibility", selection: $visibility) {
                        Label("Private", systemImage: "lock.fill")
                            .tag(BookmarkListVisibility.private)
                        Label("Public", systemImage: "globe")
                            .tag(BookmarkListVisibility.public)
                        Label("Collaborative", systemImage: "person.2.fill")
                            .tag(BookmarkListVisibility.collaborative)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text(visibilityDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                // Icon selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        ForEach([BookmarkListIcon.folder, .list, .star, .tag], id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: iconSystemName(for: icon))
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon ? Color.orange : Color(.systemGray5))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedIcon == icon ? Color.orange : Color(.systemGray3), lineWidth: 1)
                                    )
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Color selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color (optional)")
                        .font(.headline)
                    
                    Button(action: {
                        showColorPicker = true
                    }) {
                        HStack {
                            if let color = selectedColor {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: color))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Text(color)
                                    .font(.system(.subheadline, design: .monospaced))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray3), lineWidth: 1)
                                    )
                                
                                Text("Select color")
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                
                // Collaborative users (only show for collaborative visibility)
                if visibility == .collaborative {
                    if isLoadingUsers {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading collaborative users...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        CollaborativeUsersView(collaborativeUsers: $collaborativeUsers)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Create button
                Button(action: {
                    Task {
                        if isEditMode {
                            await updateList()
                        } else {
                            await createList()
                        }
                    }
                }) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isCreating ? actionButtonLoadingTitle : actionButtonTitle)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isValidName && !isCreating ? Color.orange : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!isValidName || isCreating || listDescription.count > 1000)
                .padding(.top, 20)
            }
            .padding()
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let editingList = editingList {
                    // Pre-populate fields when editing
                    loadEditingData(from: editingList)
                } else {
                    isNameFieldFocused = true
                }
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedColor: $selectedColor)
                    .presentationDetents([.height(500)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var visibilityDescription: String {
        switch visibility {
        case .private:
            return "Only you can see and add bookmarks to this list"
        case .public:
            return "Anyone can view this list, but only you can add bookmarks"
        case .collaborative:
            return "Selected users can view and add bookmarks to this list"
        }
    }
    
    private func iconSystemName(for icon: BookmarkListIcon) -> String {
        switch icon {
        case .folder:
            return "folder.fill"
        case .list:
            return "list.bullet"
        case .star:
            return "star.fill"
        case .tag:
            return "tag.fill"
        }
    }
    
    private func createList() async {
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
    
    private func loadEditingData(from list: BookmarkListView) {
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
            Task {
                await loadCollaborativeUsers(from: canAddUsers)
            }
        }
    }
    
    private func loadCollaborativeUsers(from dids: [String]) async {
        guard let protoClient = client.protoClient else { return }
        
        var users: [CollaborativeUser] = []
        
        // Try to resolve DIDs to handles and display names
        for did in dids {
            do {
                // Try to get actor profile
                let actor = try await protoClient.getProfile(for: did)
                users.append(CollaborativeUser(
                    did: did,
                    handle: actor.actorHandle,
                    displayName: actor.displayName,
                    avatarURL: actor.avatarImageURL?.absoluteString
                ))
            } catch {
                // If profile fetch fails, add with minimal info
                users.append(CollaborativeUser(
                    did: did,
                    handle: did,  // Use DID as fallback
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
    
    private func updateList() async {
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
            // Prepare permissions if visibility is collaborative
            var permissions: BookmarkListPermissions? = nil
            if visibility == .collaborative && !collaborativeUsers.isEmpty {
                let dids = collaborativeUsers.map { $0.did }
                permissions = BookmarkListPermissions(canAdd: dids)
            } else if visibility != .collaborative {
                // Clear permissions if visibility changed from collaborative
                permissions = BookmarkListPermissions(canAdd: [])
            }
            
            // Create update input with all fields (backend will handle what changed)
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

#Preview {
    CreateBookmarkListView()
        .environment(BlueskyClient.preview())
}