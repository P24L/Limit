//
//  SafariTabView.swift
//  Limit
//
//  Created by Zdenek Indrfa on 03.06.2025.
//

import SwiftUI

struct SafariTabView: View {
    @State private var id: UUID = UUID()
    
    var safariURL: URL?

    var body: some View {
        if let safariURL = safariURL {
            CustomWebViewContainer(url: safariURL)
                .id(id)
                .toolbar(.hidden, for: .navigationBar)
                .onChange(of: safariURL) { oldValue, newValue in
                    guard oldValue != newValue else { return }
                    id = UUID()
                }
        } else {
            //FavoritesViews(selectedCategories: [.links])
            FavoriteLinksSectionView()
        }
    }
}

#Preview {
    struct SafariTabPreviewContainer: View {
        @State private var safariURL: URL? = URL(string: "https://www.example.com")
        @State private var navigation = NavigationState()

        var body: some View {
            TabView(selection: $navigation.selectedTab) {
                SafariTabView(safariURL: safariURL)
                    .environment(navigation)
                    .modelContainer(SampleData.shared.modelContainer)
                    .tabItem {
                        Label("Safari", systemImage: "safari.fill")
                    }
                    .tag(1)
            }
        }
    }

    return SafariTabPreviewContainer()
}
