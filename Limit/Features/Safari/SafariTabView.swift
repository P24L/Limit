//
//  SafariTabView.swift
//  Limit
//
//  Created by Zdenek Indrfa on 03.06.2025.
//  Updated for iOS 26 WebView
//

import SwiftUI
import AppRouter
import WebKit

struct SafariTabView: View {
    @State private var webPage: WebPage?
    @State private var currentURL: URL?
    @State private var hasOpenedExternally = false
    @Environment(AppRouter.self) private var router
    @Environment(MultiAccountClient.self) private var client
    @Environment(BookmarkManager.self) private var bookmarkManager
    @Environment(UserPreferences.self) private var preferences

    var safariURL: URL?

    // Navigation handling
    private let navigationDecider = NavigationDecider()

    var body: some View {
        if let safariURL = safariURL {
            // Check if it's our universal link
            if safariURL.host == "viewer.hyperlimit.app" {
                // Handle universal link internally
                UniversalLinkProcessingView(url: safariURL)
                    .onAppear {
                        handleUniversalLink(safariURL)
                    }
            } else if shouldOpenExternally(for: safariURL) {
                Color.clear
                    .onAppear {
                        openExternallyIfNeeded(url: safariURL)
                    }
            } else {
                // Normal web content with iOS 26 WebView
                if let webPage {
                    WebView(webPage)
                        .navigationTitle(webPage.title.isEmpty ? (safariURL.host ?? "Loading...") : webPage.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            bookmarkAndActionsToolbar
                        }
                        .onAppear {
                            loadURL(safariURL)
                        }
                        .onChange(of: webPage.url) { _, newURL in
                            if let newURL, !webPage.isLoading {
                                currentURL = newURL
                            }
                        }
                } else {
                    Color.clear
                        .onAppear {
                            initWebPage()
                            loadURL(safariURL)
                        }
                }
            }
        } else {
            FavoriteLinksSectionView()
                .toolbar(.automatic, for: .navigationBar)
        }
    }
}

// MARK: - Private Views
private extension SafariTabView {
    struct UniversalLinkProcessingView: View {
        let url: URL

        var body: some View {
            VStack {
                Spacer()
                Text("Processing bookmark link...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                ProgressView()
                    .padding(.top)
                Spacer()
            }
        }
    }

    @ToolbarContentBuilder
    var bookmarkAndActionsToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            // Bookmark button
            if let url = currentURL ?? webPage?.url {
                Button {
                    Task {
                        await bookmarkManager.toggleBookmark(
                            for: url,
                            title: webPage?.title
                        )
                    }
                } label: {
                    Image(systemName: bookmarkManager.isBookmarked(url)
                        ? "star.fill" : "star")
                    .foregroundStyle(bookmarkManager.isBookmarked(url)
                        ? .yellow : .primary)
                }
            }

            // Menu with navigation and additional actions
            Menu {
                // Navigation
                Button {
                    if let last = webPage?.backForwardList.backList.last {
                        webPage?.load(last)
                    }
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .disabled(webPage?.backForwardList.backList.isEmpty ?? true)

                Button {
                    if let first = webPage?.backForwardList.forwardList.first {
                        webPage?.load(first)
                    }
                } label: {
                    Label("Forward", systemImage: "chevron.forward")
                }
                .disabled(webPage?.backForwardList.forwardList.isEmpty ?? true)

                Button {
                    webPage?.reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }

                Divider()

                // Share and external actions
                if let url = currentURL ?? webPage?.url {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - WebPage Management
private extension SafariTabView {
    func shouldOpenExternally(for url: URL) -> Bool {
        guard preferences.openLinksInApp == false else { return false }
        return url.host != "viewer.hyperlimit.app"
    }

    func openExternallyIfNeeded(url: URL) {
        guard !hasOpenedExternally else { return }
        hasOpenedExternally = true

        UIApplication.shared.open(url)

        // Pop this Safari view off the stack after a short delay
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            router.popNavigation(for: router.selectedTab)
        }
    }

    func initWebPage() {
        var config = WebPage.Configuration()

        // Navigation preferences
        config.defaultNavigationPreferences.allowsContentJavaScript = true
        config.defaultNavigationPreferences.preferredContentMode = .mobile

        // App identification
        config.applicationNameForUserAgent = "Limit for Bluesky"

        // Security & privacy
        config.upgradeKnownHostsToHTTPS = true
        config.limitsNavigationsToAppBoundDomains = false

        // Media settings
        config.allowsAirPlayForMediaPlayback = true
        // Note: Inline media playback might be controlled differently in iOS 26
        // or enabled by default

        // Setup navigation decider
        navigationDecider.onUniversalLink = { url in
            handleUniversalLink(url)
        }

        let page = WebPage(
            configuration: config,
            navigationDecider: navigationDecider
        )

        // Custom user agent
        page.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"

        self.webPage = page
    }

    func loadURL(_ url: URL) {
        if webPage == nil {
            initWebPage()
        }
        currentURL = url
        webPage?.load(URLRequest(url: url))
    }

    func handleUniversalLink(_ url: URL) {
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

// MARK: - NavigationDecider
private class NavigationDecider: NSObject, WebPage.NavigationDeciding {
    var onUniversalLink: ((URL) -> Void)?

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {

        guard let url = action.request.url else { return .allow }

        // Check for universal links
        if url.host == "viewer.hyperlimit.app" {
            await MainActor.run {
                onUniversalLink?(url)
            }
            return .cancel
        }

        // Allow all other navigation
        return .allow
    }
}
