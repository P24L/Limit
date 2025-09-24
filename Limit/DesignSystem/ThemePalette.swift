//
//  ThemePalette.swift
//  Limit
//
//  Created by Codex on 05.08.2025.
//

import SwiftUI

public enum ThemePaletteID: String, CaseIterable, Identifiable {
    case mintClassic
    case midnight

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mintClassic:
            return "Mint Classic"
        case .midnight:
            return "Midnight"
        }
    }
}

public struct ThemeColorSet {
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

    public init(
        accent: Color,
        accentMuted: Color,
        backgroundPrimary: Color,
        backgroundSecondary: Color,
        surfacePrimary: Color,
        surfaceSecondary: Color,
        textPrimary: Color,
        textSecondary: Color,
        textTertiary: Color,
        border: Color,
        success: Color,
        warning: Color,
        destructive: Color
    ) {
        self.accent = accent
        self.accentMuted = accentMuted
        self.backgroundPrimary = backgroundPrimary
        self.backgroundSecondary = backgroundSecondary
        self.surfacePrimary = surfacePrimary
        self.surfaceSecondary = surfaceSecondary
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.border = border
        self.success = success
        self.warning = warning
        self.destructive = destructive
    }
}

public struct ThemePalette {
    public let id: ThemePaletteID
    public let displayName: String
    public let description: String
    public let light: ThemeColorSet
    public let dark: ThemeColorSet

    public init(
        id: ThemePaletteID,
        displayName: String,
        description: String,
        light: ThemeColorSet,
        dark: ThemeColorSet
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.light = light
        self.dark = dark
    }

    public func colors(for colorScheme: ColorScheme) -> ThemeColorSet {
        switch colorScheme {
        case .dark:
            return dark
        default:
            return light
        }
    }
}

public enum ThemePaletteLibrary {
    private static let mintClassic = ThemePalette(
        id: .mintClassic,
        displayName: "Mint Classic",
        description: "Fresh mint accent with warm neutral surfaces.",
        light: ThemeColorSet(
            accent: Color(red: 0.18, green: 0.68, blue: 0.48),
            accentMuted: Color(red: 0.65, green: 0.82, blue: 0.72),
            backgroundPrimary: Color.white,
            backgroundSecondary: Color(red: 0.90, green: 0.90, blue: 0.92),
            surfacePrimary: Color(red: 1.00, green: 1.00, blue: 1.00),
            surfaceSecondary: Color(red: 0.92, green: 0.92, blue: 0.93),
            textPrimary: Color(red: 0.14, green: 0.14, blue: 0.14),
            textSecondary: Color(red: 0.35, green: 0.35, blue: 0.40),
            textTertiary: Color(red: 0.65, green: 0.65, blue: 0.65),
            border: Color(red: 0.85, green: 0.85, blue: 0.87),
            success: Color(red: 0.20, green: 0.60, blue: 0.30),
            warning: Color(red: 0.92, green: 0.62, blue: 0.05),
            destructive: Color(red: 0.82, green: 0.23, blue: 0.21)
        ),
        dark: ThemeColorSet(
            accent: Color(red: 0.34, green: 0.81, blue: 0.61),
            accentMuted: Color(red: 0.29, green: 0.53, blue: 0.42),
            backgroundPrimary: Color(red: 0.10, green: 0.10, blue: 0.10),
            backgroundSecondary: Color(red: 0.15, green: 0.15, blue: 0.17),
            surfacePrimary: Color(red: 0.15, green: 0.15, blue: 0.15),
            surfaceSecondary: Color(red: 0.20, green: 0.20, blue: 0.22),
            textPrimary: Color(red: 0.92, green: 0.92, blue: 0.93),
            textSecondary: Color(red: 0.70, green: 0.70, blue: 0.72),
            textTertiary: Color(red: 0.58, green: 0.58, blue: 0.60),
            border: Color(red: 0.24, green: 0.24, blue: 0.26),
            success: Color(red: 0.33, green: 0.76, blue: 0.44),
            warning: Color(red: 0.95, green: 0.74, blue: 0.32),
            destructive: Color(red: 0.93, green: 0.38, blue: 0.38)
        )
    )

    private static let midnight = ThemePalette(
        id: .midnight,
        displayName: "Midnight",
        description: "Deep blues with high-contrast highlights.",
        light: ThemeColorSet(
            accent: Color(red: 0.22, green: 0.42, blue: 0.88),
            accentMuted: Color(red: 0.68, green: 0.77, blue: 0.96),
            backgroundPrimary: Color(red: 0.95, green: 0.97, blue: 1.00),
            backgroundSecondary: Color(red: 0.85, green: 0.90, blue: 1.00),
            surfacePrimary: Color(red: 0.99, green: 1.00, blue: 1.00),
            surfaceSecondary: Color(red: 0.90, green: 0.93, blue: 0.98),
            textPrimary: Color(red: 0.12, green: 0.15, blue: 0.28),
            textSecondary: Color(red: 0.32, green: 0.38, blue: 0.62),
            textTertiary: Color(red: 0.53, green: 0.58, blue: 0.78),
            border: Color(red: 0.75, green: 0.80, blue: 0.92),
            success: Color(red: 0.17, green: 0.55, blue: 0.33),
            warning: Color(red: 0.93, green: 0.59, blue: 0.20),
            destructive: Color(red: 0.82, green: 0.25, blue: 0.35)
        ),
        dark: ThemeColorSet(
            accent: Color(red: 0.40, green: 0.60, blue: 1.00),
            accentMuted: Color(red: 0.26, green: 0.36, blue: 0.62),
            backgroundPrimary: Color(red: 0.08, green: 0.12, blue: 0.20),
            backgroundSecondary: Color(red: 0.12, green: 0.16, blue: 0.26),
            surfacePrimary: Color(red: 0.15, green: 0.20, blue: 0.32),
            surfaceSecondary: Color(red: 0.20, green: 0.26, blue: 0.38),
            textPrimary: Color(red: 0.90, green: 0.93, blue: 1.00),
            textSecondary: Color(red: 0.72, green: 0.78, blue: 0.96),
            textTertiary: Color(red: 0.58, green: 0.64, blue: 0.86),
            border: Color(red: 0.24, green: 0.28, blue: 0.42),
            success: Color(red: 0.29, green: 0.71, blue: 0.46),
            warning: Color(red: 0.94, green: 0.72, blue: 0.26),
            destructive: Color(red: 0.93, green: 0.38, blue: 0.50)
        )
    )

    public static let allPalettes: [ThemePalette] = [
        mintClassic,
        midnight
    ]

    public static func palette(for id: ThemePaletteID) -> ThemePalette {
        allPalettes.first(where: { $0.id == id }) ?? mintClassic
    }

    public static func defaultPalette(for colorScheme: ColorScheme) -> ThemePalette {
        switch colorScheme {
        case .dark:
            return midnight
        default:
            return mintClassic
        }
    }
}
