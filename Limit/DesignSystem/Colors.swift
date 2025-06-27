//
//  Colors.swift
//  Limit
//
//  Created by Zdenek Indra on 19.06.2025.
//

import SwiftUI

extension Color {
    static let mintAccent = Color(red: 0.20, green: 0.70, blue: 0.50) // Mint Cream accent
    static let postAction = Color(red: 0.35, green: 0.35, blue: 0.40) // Neutral gray for action bar
    static let mintInactive = Color(red: 0.60, green: 0.80, blue: 0.70) // Soft mint for non-highlighted use
}

public extension ShapeStyle where Self == Color {
    static var mintAccent: Color { .mintAccent }
    static var postAction: Color { .postAction }
    static var mintInactive: Color { .mintInactive }
}
