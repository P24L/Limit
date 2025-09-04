//
//  NewsView.swift
//  Limit
//
//  Created by Zdenek Indra
//

import SwiftUI

struct NewsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(.mintAccent)
                .padding(.top, 50)
            
            Text("Trending Articles")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Coming soon...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.warmBackground)
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
    }
}