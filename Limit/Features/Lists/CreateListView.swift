//
//  CreateListView.swift
//  Limit
//
//  Created by Claude Code on 11.07.2025.
//

import SwiftUI

struct CreateListView: View {
    @Environment(MultiAccountClient.self) private var client
    @Environment(CurrentUser.self) private var currentUser
    @Environment(\.dismiss) private var dismiss
    
    @State private var listName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    @FocusState private var isNameFieldFocused: Bool
    
    private var isValidName: Bool {
        !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && listName.count <= 64
    }
    
    var body: some View {
        NavigationView {
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
                                    await createList()
                                }
                            }
                        }
                    
                    HStack {
                        Text("\(listName.count)/64")
                            .font(.caption)
                            .foregroundColor(listName.count > 64 ? .red : .secondary)
                        
                        Spacer()
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Create button
                Button(action: {
                    Task {
                        await createList()
                    }
                }) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isCreating ? "Creating..." : "Create List")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isValidName && !isCreating ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!isValidName || isCreating)
            }
            .padding()
            .navigationTitle("Create List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
    }
    
    private func createList() async {
        let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 64 else {
            errorMessage = "Please enter a valid list name (1-64 characters)"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        let listURI = await client.createList(name: trimmedName)
        
        if listURI != nil {
            DevLogger.shared.log("CreateListView.swift - Successfully created list: \(trimmedName)")
            await currentUser.refreshLists(client: client)
            dismiss()
        } else {
            errorMessage = "Failed to create list. Please try again."
        }
        
        isCreating = false
    }
}