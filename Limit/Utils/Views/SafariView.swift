//
//  SafariView.swift
//  Limit
//
//  Created by Zdenek Indra on 27.05.2025.
//

import SafariServices
import SwiftData
import SwiftUI
import WebKit

class WebViewState: ObservableObject {
    @Published var currentURL: URL?
    @Published var isLoading = false
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct CustomWebView: UIViewRepresentable {
    let initialURL: URL
    let webView: WKWebView
    @Binding var title: String?
    @ObservedObject var webState: WebViewState

    func makeCoordinator() -> Coordinator {
        Coordinator(title: $title, webState: webState)
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: initialURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // intentionally left blank: do not reload on update
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var title: String?
        let webState: WebViewState

        init(title: Binding<String?>, webState: WebViewState) {
            self._title = title
            self.webState = webState
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            webState.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            webState.isLoading = false  // Skryje loading jakmile je stránka použitelná
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            title = webView.title
            webState.currentURL = webView.url
            webState.isLoading = false  // Fallback pro případ že didCommit se nespustí
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webState.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webState.isLoading = false
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Když se má otevřít nové okno, načteme URL v současném WebView
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}

struct CustomWebViewContainer: View {
    // Konfigurace zobrazených tlačítek
    private let showBack = true
    private let showForward = true
    private let showReload = true
    private let showShare = true
    private let showOpenInSafari = true
    private let showDone = false
    private let showHide = true

    // Toolbar nahoře nebo dole
    private let toolbarAtTop = false

    @State private var webView: WKWebView?
    @State private var showToolbar = true
    @State private var isCollapsed = true
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var webState = WebViewState()
    
    @Environment(FavoriteURLManager.self) private var favorites
    
    //URL
    @State var url: URL?
    @State private var title: String? = nil
    @State private var id: UUID = UUID()
    @State private var hideToolbarWorkItem: DispatchWorkItem?
    
    //SwiftData
    @Environment(\.modelContext) var context
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let webView = webView {
                ZStack {
                    CustomWebView(
                        initialURL: url ?? URL(string: "about:blank")!,
                        webView: webView,
                        title: $title,
                        webState: webState
                    )
                    .id(id)
                    
                    if webState.isLoading {
                        Color(.systemBackground)
                            .opacity(0.8)
                            .overlay(
                                ProgressView("Loading...")
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                            )
                    }
                }
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }

            if showToolbar {
                HStack {
                    if let webView = webView, let currentURL = webView.url {
                        Button {
                            Task {
                                if favorites.isFavorited(currentURL) {
                                    await favorites.removeFavorite(url: currentURL)
                                } else {
                                    await favorites.addFavorite(url: currentURL, title: title)
                                }
                            }
                        } label: {
                            Image(systemName: favorites.isFavorited(currentURL) ? "star.fill" : "star")
                                .imageScale(.large)
                                .font(.title2)
                                .padding(2)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    if isCollapsed {
                        Button(action: {
                            withAnimation {
                                isCollapsed = false
                            }
                            restartToolbarHideTimer()
                        }) {
                            Image(systemName: "safari")
                                .imageScale(.large)
                                .font(.title2)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(5)
                        .transition(.move(edge: .trailing))
                    } else {
                        HStack {
                            if showBack, let webView = webView {
                                Button(action: { webView.goBack() }) {
                                    Image(systemName: "chevron.backward")
                                        .imageScale(.large)
                                        .font(.title2)
                                }
                                .disabled(!webView.canGoBack)
                            }
                            
                            if showForward, let webView = webView {
                                Button(action: { webView.goForward() }) {
                                    Image(systemName: "chevron.forward")
                                        .imageScale(.large)
                                        .font(.title2)
                                }
                                .disabled(!webView.canGoForward)
                            }
                            
                            if showReload, let webView = webView {
                                Button(action: { webView.reload() }) {
                                    Image(systemName: "arrow.clockwise")
                                        .imageScale(.large)
                                        .font(.title2)
                                }
                            }
                            
                            if showShare, let webView = webView {
                                Button(action: {
                                    guard let url = webView.url else { return }
                                    let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first,
                                       let rootVC = window.rootViewController {
                                        rootVC.present(av, animated: true)
                                    }
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .imageScale(.large)
                                        .font(.title2)
                                }
                            }
                            
                            if showOpenInSafari, let webView = webView {
                                Button(action: {
                                    guard let url = webView.url else { return }
                                    UIApplication.shared.open(url)
                                }) {
                                    Image(systemName: "safari")
                                        .imageScale(.large)
                                        .font(.title2)
                                }
                            }
                            
                            if showDone {
                                Button("Done") {
                                    dismiss()
                                }
                            }
                            if showHide {
                                Button(action: { isCollapsed.toggle() }) {
                                    Image(systemName: "eye.slash")
                                        .imageScale(.large)
                                        .font(.title2)
                                }
                            }
                        }
                        .padding(5)
                        .background(.ultraThinMaterial)
                        .transition(.move(edge: .trailing))
                    }
                }
                // Apply animation to the entire HStack containing these toolbar elements:
                .animation(.default, value: isCollapsed)
            }
        }
        .onAppear {
            if webView == nil {
                Task { @MainActor in
                    webView = WKWebView()
                }
            }
        }
        .onChange(of: url) { oldValue, newValue in
            guard let newURL = newValue, let webView = webView else { return }
            webView.load(URLRequest(url: newURL))
            id = UUID()
        }
        .onChange(of: webState.currentURL) { oldValue, newValue in
        }
    }

    private func restartToolbarHideTimer() {
        hideToolbarWorkItem?.cancel()
        let task = DispatchWorkItem {
            withAnimation {
                isCollapsed = true
            }
        }
        hideToolbarWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }
}

#Preview {
    TabView {
        CustomWebViewContainer(url: URL(string: "https://seznam.cz")!)
        .modelContainer(SampleData.shared.modelContainer)
        .environment( NavigationState())
        .tabItem {
            Label("", systemImage: "safari.fill")
        }
    }
}
