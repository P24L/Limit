//
//  MutedRepliesSettingsView.swift
//  Limit
//
//  Created by Assistant on 19.07.2025.
//

import SwiftUI

struct MutedRepliesSettingsView: View {
    @Environment(UserPreferences.self) private var userPreferences
    @State private var actorPendingRemoval: MutedReplyActor? = nil
    @State private var showRemovalConfirmation = false

    var body: some View {
        @Bindable var preferences = userPreferences

        List {
            if preferences.mutedReplyActors.isEmpty {
                Section {
                    Text("You haven't muted any users yet.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            } else {
                Section {
                    ForEach(preferences.mutedReplyActors) { actor in
                        HStack(spacing: 12) {
                            AvatarView(url: actor.avatarURL, size: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(actor.displayName?.isEmpty == false ? actor.displayName! : actor.handle)
                                    .font(.headline)
                                Text(actor.handle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Remove") {
                                actorPendingRemoval = actor
                                showRemovalConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                remove(actor)
                            } label: {
                                Label("Unmute", systemImage: "speaker.wave.2")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Muted users")
        .listStyle(.insetGrouped)
        .confirmationDialog(
            "Remove muted user?",
            isPresented: $showRemovalConfirmation,
            presenting: actorPendingRemoval
        ) { actor in
            Button("Remove", role: .destructive) {
                remove(actor)
            }
            Button("Cancel", role: .cancel) {
                actorPendingRemoval = nil
            }
        }
    }

    private func remove(_ actor: MutedReplyActor) {
        userPreferences.unmuteReplies(forDid: actor.did)
        actorPendingRemoval = nil
        showRemovalConfirmation = false
    }
}
