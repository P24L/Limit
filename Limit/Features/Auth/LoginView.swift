//
//  LoginView.swift
//  Limit
//
//  Created by Zdenek Indra on 20.01.2025.
//

import SwiftUI

struct LoginView: View {
    let prefilledHandle: String
    let onComplete: (Bool) -> Void
    
    init(prefilledHandle: String = "", onComplete: @escaping (Bool) -> Void) {
        self.prefilledHandle = prefilledHandle
        self.onComplete = onComplete
    }
    
    var body: some View {
        LoginTabView(prefilledHandle: prefilledHandle, onDismiss: {
            onComplete(true)
        })
    }
}