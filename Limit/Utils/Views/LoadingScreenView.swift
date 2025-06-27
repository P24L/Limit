//
//  LoadingScreenView.swift
//  Limit
//
//  Created by Zdenek Indra on 06.06.2025.
//

import SwiftUI

struct LoadingScreenView: View {
    var body: some View {
        Image("Logo")
            .resizable()
            .frame(width:200, height: 200)
        Text("Limit")
            .font(.largeTitle)
            .fontWeight(.semibold)
    }
}

#Preview {
    LoadingScreenView()
}
