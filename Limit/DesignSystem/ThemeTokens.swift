//
//  ThemeTokens.swift
//  Limit
//
//  Created by Codex on 05.08.2025.
//

import SwiftUI

public struct ThemeColors {
    public let accent: Color
    public let accentMuted: Color
    public let backgroundPrimary: Color
    public let backgroundSecondary: Color
    public let surfacePrimary: Color
    public let surfaceSecondary: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let border: Color
    public let success: Color
    public let warning: Color
    public let destructive: Color

    public init(set: ThemeColorSet) {
        accent = set.accent
        accentMuted = set.accentMuted
        backgroundPrimary = set.backgroundPrimary
        backgroundSecondary = set.backgroundSecondary
        surfacePrimary = set.surfacePrimary
        surfaceSecondary = set.surfaceSecondary
        textPrimary = set.textPrimary
        textSecondary = set.textSecondary
        textTertiary = set.textTertiary
        border = set.border
        success = set.success
        warning = set.warning
        destructive = set.destructive
    }
}

public struct ThemeTokens {
    public let colors: ThemeColors

    public init(colors: ThemeColors) {
        self.colors = colors
    }
}
