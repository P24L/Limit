//
//  LoadingScreenView.swift
//  Limit
//
//  Created by Zdenek Indra on 06.06.2025.
//

import SwiftUI

struct LoadingScreenView: View {
    @Environment(MultiAccountClient.self) private var client
    @Environment(AppState.self) private var appState
    @Environment(TimelineFeed.self) private var feed
    @Environment(CurrentUser.self) private var currentUser
    @Environment(ComputedTimelineFeed.self) private var computedFeed
    @State private var showLogin = false
    
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .frame(width:200, height: 200)
            Text("Limit")
                .font(.largeTitle)
                .fontWeight(.semibold)
        }
        .onChange(of: appState.value) { _, newValue in
            if newValue == .unauthenticated {
                showLogin = true
            }
        }
        .onAppear {
            if appState.value == .unauthenticated {
                showLogin = true
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginTabView {
                showLogin = false
                Task {
                    await handleLoginSuccess()
                }
            }
        }
    }
    
    private func handleLoginSuccess() async {
        if client.isAuthenticated {
            feed.updateClient(client)
            await currentUser.refreshProfile(client: client)
            appState.setAuthenticated()
            
            // Start preparing ComputedTimeline cache with 4s delay to allow main timeline to load first
            Task.detached { [weak computedFeed, weak client] in
                guard let computedFeed = computedFeed, let client = client else { return }
                try? await Task.sleep(for: .seconds(4))
                await computedFeed.prepareSessionCacheInBackground(client: client)
            }
        }
    }
}

