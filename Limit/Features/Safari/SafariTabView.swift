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
                //.toolbar(.automatic, for: .navigationBar)
                .onChange(of: safariURL) { oldValue, newValue in
                    guard oldValue != newValue else { return }
                    id = UUID()
                }
                .toolbar(.automatic, for: .navigationBar)
        } else {
            FavoriteLinksSectionView()
            .toolbar(.automatic, for: .navigationBar)
        }
    }
}