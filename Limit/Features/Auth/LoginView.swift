//
//  LoginView.swift
//  Limit
//
//  Created by Zdenek Indra on 20.01.2025.
//

import SwiftUI

struct LoginView: View {
    let onComplete: (Bool) -> Void
    
    var body: some View {
        LoginTabView(onDismiss: {
            onComplete(true)
        })
    }
}