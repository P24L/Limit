//
//  Colors.swift
//  Limit
//
//  Created by Zdenek Indra on 19.06.2025.
//

import SwiftUI

extension Color {
    // MARK: - Mint Colors
    static let mintAccent = Color(red: 0.18, green: 0.68, blue: 0.48) // Slightly deeper mint for better contrast

    static let mintInactive = Color(red: 0.65, green: 0.82, blue: 0.72) // Lighter mint for inactive states
    
    // MARK: - Background Colors
    static let warmBackground = Color(red: 0.96, green: 0.96, blue: 0.96) // #F5F5F5 - warm main background with better contrast
    static let cardBackground = Color(red: 1.0, green: 1.0, blue: 1.0) // Pure white for cards
    static let subtleGray = Color(red: 0.94, green: 0.94, blue: 0.94) // #F0F0F0 - subtle borders
    
    // MARK: - Text & Action Colors
    static let postAction = Color(red: 0.35, green: 0.35, blue: 0.40) // Neutral gray for action bar
    static let secondaryText = Color(red: 0.45, green: 0.45, blue: 0.45) // Better secondary text
    static let tertiaryText = Color(red: 0.65, green: 0.65, blue: 0.65) // Lighter text for timestamps
}

public extension ShapeStyle where Self == Color {
    // MARK: - Mint Colors
    static var mintAccent: Color { .mintAccent }
    static var mintInactive: Color { .mintInactive }
    
    // MARK: - Background Colors
    static var warmBackground: Color { .warmBackground }
    static var cardBackground: Color { .cardBackground }
    static var subtleGray: Color { .subtleGray }
    
    // MARK: - Text & Action Colors
    static var postAction: Color { .postAction }
    static var secondaryText: Color { .secondaryText }
    static var tertiaryText: Color { .tertiaryText }
}
