//
//  Colors.swift
//  Limit
//
//  Created by Zdenek Indra on 19.06.2025.
//

import SwiftUI
import UIKit

extension Color {
    // MARK: - Mint Colors
    static let mintAccent = Color(red: 0.18, green: 0.68, blue: 0.48) // Slightly deeper mint for better contrast

    static let mintInactive = Color(red: 0.65, green: 0.82, blue: 0.72) // Lighter mint for inactive states
    
    // MARK: - Background Colors
    static let warmBackground = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)  // Dark warm background
            : UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0) // Light warm background
    })
    
    static let cardBackground = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)  // Dark card background
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0) // Pure white for cards
    })
    
    static let subtleGray = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)  // Dark subtle borders
            : UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1.0) // Light subtle borders
    })
    
    // MARK: - Text & Action Colors
    static let postAction = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)  // Lighter in dark mode
            : UIColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 1.0) // Neutral gray for action bar
    })
    
    static let secondaryText = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)  // Lighter in dark mode
            : UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0) // Better secondary text
    })
    
    static let tertiaryText = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)  // Lighter in dark mode
            : UIColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0) // Lighter text for timestamps
    })
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
