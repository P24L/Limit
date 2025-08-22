//
//  SafariTabView.swift
//  Limit
//
//  Created by Zdenek Indrfa on 03.06.2025.
//

import SwiftUI
import AppRouter

struct SafariTabView: View {
    @State private var id: UUID = UUID()
    @Environment(AppRouter.self) private var router
    @Environment(MultiAccountClient.self) private var client
    
    var safariURL: URL?

    var body: some View {
        if let safariURL = safariURL {
            // Check if it's our universal link
            if safariURL.host == "viewer.hyperlimit.app" {
                // Handle universal link internally
                VStack {
                    Spacer()
                    Text("Processing bookmark link...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    ProgressView()
                        .padding(.top)
                    Spacer()
                }
                .onAppear {
                    handleUniversalLink(safariURL)
                }
            } else {
                // Normal web content
                CustomWebViewContainer(url: safariURL)
                    .id(id)
                    .onChange(of: safariURL) { oldValue, newValue in
                        guard oldValue != newValue else { return }
                        id = UUID()
                    }
                    .toolbar(.automatic, for: .navigationBar)
            }
        } else {
            FavoriteLinksSectionView()
                .toolbar(.automatic, for: .navigationBar)
        }
    }
    
    private func handleUniversalLink(_ url: URL) {
        DevLogger.shared.log("SafariTabView - Intercepted universal link: \(url)")
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        // Handle bookmark links: https://viewer.hyperlimit.app/at/{did}/{collection}/{rkey}
        if pathComponents.count >= 4 && pathComponents[0] == "at" {
            let did = pathComponents[1]
            let collection = pathComponents[2]
            let rkey = pathComponents[3]
            
            // Reconstruct AT URI
            let atUri = "at://\(did)/\(collection)/\(rkey)"
            
            DevLogger.shared.log("SafariTabView - Parsed bookmark link: did=\(did), collection=\(collection), rkey=\(rkey)")
            
            // Check if it's user's own bookmark
            let isOwner = AccountManager.shared.currentAccount?.did == did || client.currentDID == did
            
            // Navigate based on ownership
            DispatchQueue.main.async {
                // Pop back from Safari first
                router.popToRoot(for: router.selectedTab)
                
                if isOwner {
                    // Navigate to bookmark detail
                    router.selectedTab = .bookmarks
                    router.navigateTo(.bookmarkDetail(id: rkey), for: .bookmarks)
                } else {
                    // Navigate to external bookmark view
                    router.selectedTab = .bookmarks
                    router.navigateTo(.externalBookmark(uri: atUri, isOwner: false), for: .bookmarks)
                }
            }
            
            DevLogger.shared.log("SafariTabView - Redirected to bookmark view: \(atUri), isOwner: \(isOwner)")
        } else {
            DevLogger.shared.log("SafariTabView - Unknown universal link format, opening in web view")
            // If we can't handle it, just show it in the web view
            // But since we're already in the onAppear, we'd need to update state
            // For now, log the error
        }
    }
}