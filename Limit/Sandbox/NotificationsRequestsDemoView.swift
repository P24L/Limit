//
//  NotificationsRequestsDemoView.swift
//  Limit
//
//  Created by Zdenek Indra on 01.06.2025.
//

import SwiftUI

// MARK: - Mock Model

struct NotificationsRequest: Identifiable {
    let id: String
    let account: Account
    let notificationsCount: String
}

struct Account {
    let id: String
    let avatar: URL?
    let cachedDisplayName: String
    let acct: String
    let emojis: [Emoji]
}

struct Emoji {
    let shortcode: String
    let url: URL
}

// MARK: - Demo View

struct NotificationsRequestsDemoView: View {
    enum ViewState {
        case loading
        case error
        case requests(_ data: [NotificationsRequest])
    }

    @State private var viewState: ViewState = .loading

    var body: some View {
        NavigationStack {
            List {
                switch viewState {
                case .loading:
                    ProgressView()
                        .listRowSeparator(.hidden)
                case .error:
                    VStack {
                        Text("Error loading")
                            .font(.headline)
                        Button("Try again") {
                            loadMockData()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .listRowSeparator(.hidden)
                case .requests(let data):
                    ForEach(data) { request in
                        NotificationsRequestsRowView(request: request)
                            .swipeActions {
                                Button {
                                    print("Accept \(request.id)")
                                } label: {
                                    Label("Accept", systemImage: "checkmark")
                                }

                                Button(role: .destructive) {
                                    print("Dismiss \(request.id)")
                                } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }
                            }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Requests for following")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadMockData()
            }
            .refreshable {
                loadMockData()
            }
        }
    }

    private func loadMockData() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Simulace úspěšného načtení
            viewState = .requests([
                .init(id: "1", account: .init(
                    id: "u1",
                    avatar: nil,
                    cachedDisplayName: "Jana Novaková",
                    acct: "@jana",
                    emojis: []
                ), notificationsCount: "2"),
                .init(id: "2", account: .init(
                    id: "u2",
                    avatar: nil,
                    cachedDisplayName: "Tomáš Dvořák",
                    acct: "@tom",
                    emojis: []
                ), notificationsCount: "5"),
            ])
        }
    }
}

// MARK: - Row View

struct NotificationsRequestsRowView: View {
    let request: NotificationsRequest

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.gray)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.account.cachedDisplayName)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                Text(request.account.acct)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(request.notificationsCount)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(8)
                .background(.secondary)
                .clipShape(Circle())

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
        .listRowBackground(Color.white)
    }
}

// MARK: - Preview

#Preview {
    NotificationsRequestsDemoView()
}
