//
//  LoadingScreenView.swift
//  Limit
//
//  Created by Zdenek Indra on 06.06.2025.
//

import SwiftUI

struct LoadingScreenView: View {
    @Environment(BlueskyClient.self) private var client
    @State private var showLogin = false
    let onLoginSuccess: () -> Void
    
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .frame(width:200, height: 200)
            Text("Limit")
                .font(.largeTitle)
                .fontWeight(.semibold)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !client.isAuthenticated {
                    showLogin = true
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginTabView {
                showLogin = false
                onLoginSuccess()
            }
        }
    }
}

#Preview {
    LoadingScreenView {
        print("Login success")
    }
}
