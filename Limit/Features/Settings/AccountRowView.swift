//
//  AccountRowView.swift
//  Limit
//
//  Created by Zdenek Indra on 20.01.2025.
//

import SwiftUI
import SDWebImageSwiftUI

struct AccountRowView: View {
    let account: UserAccount
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            AvatarView(url: account.avatarURL, size: 48)
            
            // Account info
            VStack(alignment: .leading, spacing: 2) {
                if !account.displayName.isEmpty {
                    Text(account.displayName)
                        .font(.headline)
                }
                Text("@\(account.handle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Current account indicator
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 22))
            }
        }
        .contentShape(Rectangle())
    }
}