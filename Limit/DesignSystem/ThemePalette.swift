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
    case sunsetDunes
    case plain
    case forestCanopy
    case disco

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mintClassic:
            return "Mint Classic"
        case .midnight:
            return "Midnight"
        case .sunsetDunes:
            return "Sunset Dunes"
        case .plain:
            return "Plain"
        case .forestCanopy:
            return "Forest Canopy"
        case .disco:
            return "Disco"
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
    public let backgroundCanvas: Color
    public let backgroundListRow: Color
    public let chromeBackground: Color
    public let chromeForeground: Color
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
        backgroundCanvas: Color,
        backgroundListRow: Color,
        chromeBackground: Color,
        chromeForeground: Color,
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
        self.backgroundCanvas = backgroundCanvas
        self.backgroundListRow = backgroundListRow
        self.chromeBackground = chromeBackground
        self.chromeForeground = chromeForeground
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
            backgroundCanvas: Color(red: 0.96, green: 0.97, blue: 0.98),
            backgroundListRow: Color.white,
            chromeBackground: Color.white,
            chromeForeground: Color(red: 0.14, green: 0.14, blue: 0.14),
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
            backgroundCanvas: Color(red: 0.07, green: 0.07, blue: 0.08),
            backgroundListRow: Color(red: 0.12, green: 0.12, blue: 0.13),
            chromeBackground: Color(red: 0.14, green: 0.14, blue: 0.15),
            chromeForeground: Color(red: 0.88, green: 0.88, blue: 0.90),
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
            backgroundCanvas: Color(red: 0.94, green: 0.96, blue: 1.00),
            backgroundListRow: Color.white,
            chromeBackground: Color.white,
            chromeForeground: Color(red: 0.12, green: 0.14, blue: 0.27),
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
            backgroundCanvas: Color(red: 0.06, green: 0.10, blue: 0.18),
            backgroundListRow: Color(red: 0.11, green: 0.16, blue: 0.25),
            chromeBackground: Color(red: 0.13, green: 0.18, blue: 0.30),
            chromeForeground: Color(red: 0.86, green: 0.92, blue: 1.00),
            textPrimary: Color(red: 0.90, green: 0.93, blue: 1.00),
            textSecondary: Color(red: 0.72, green: 0.78, blue: 0.96),
            textTertiary: Color(red: 0.58, green: 0.64, blue: 0.86),
            border: Color(red: 0.24, green: 0.28, blue: 0.42),
            success: Color(red: 0.29, green: 0.71, blue: 0.46),
            warning: Color(red: 0.94, green: 0.72, blue: 0.26),
            destructive: Color(red: 0.93, green: 0.38, blue: 0.50)
        )
    )

    private static let sunsetDunes = ThemePalette(
        id: .sunsetDunes,
        displayName: "Sunset Dunes",
        description: "Warm desert neutrals with coral highlights.",
        light: ThemeColorSet(
            accent: Color(red: 1.00, green: 0.48, blue: 0.36),
            accentMuted: Color(red: 1.00, green: 0.76, blue: 0.63),
            backgroundPrimary: Color(red: 1.00, green: 0.97, blue: 0.94),
            backgroundSecondary: Color(red: 0.96, green: 0.90, blue: 0.84),
            surfacePrimary: Color(red: 1.00, green: 1.00, blue: 1.00),
            surfaceSecondary: Color(red: 0.98, green: 0.94, blue: 0.90),
            backgroundCanvas: Color(red: 0.99, green: 0.96, blue: 0.92),
            backgroundListRow: Color(red: 1.00, green: 1.00, blue: 1.00),
            chromeBackground: Color(red: 1.00, green: 1.00, blue: 1.00),
            chromeForeground: Color(red: 0.48, green: 0.29, blue: 0.15),
            textPrimary: Color(red: 0.29, green: 0.18, blue: 0.11),
            textSecondary: Color(red: 0.48, green: 0.36, blue: 0.26),
            textTertiary: Color(red: 0.69, green: 0.56, blue: 0.45),
            border: Color(red: 0.89, green: 0.80, blue: 0.72),
            success: Color(red: 0.25, green: 0.56, blue: 0.37),
            warning: Color(red: 0.88, green: 0.55, blue: 0.16),
            destructive: Color(red: 0.82, green: 0.34, blue: 0.29)
        ),
        dark: ThemeColorSet(
            accent: Color(red: 1.00, green: 0.60, blue: 0.46),
            accentMuted: Color(red: 0.79, green: 0.42, blue: 0.30),
            backgroundPrimary: Color(red: 0.12, green: 0.09, blue: 0.07),
            backgroundSecondary: Color(red: 0.16, green: 0.12, blue: 0.11),
            surfacePrimary: Color(red: 0.18, green: 0.14, blue: 0.13),
            surfaceSecondary: Color(red: 0.22, green: 0.17, blue: 0.16),
            backgroundCanvas: Color(red: 0.09, green: 0.06, blue: 0.05),
            backgroundListRow: Color(red: 0.14, green: 0.10, blue: 0.09),
            chromeBackground: Color(red: 0.17, green: 0.12, blue: 0.11),
            chromeForeground: Color(red: 0.96, green: 0.85, blue: 0.78),
            textPrimary: Color(red: 0.97, green: 0.88, blue: 0.82),
            textSecondary: Color(red: 0.84, green: 0.71, blue: 0.61),
            textTertiary: Color(red: 0.66, green: 0.51, blue: 0.43),
            border: Color(red: 0.32, green: 0.22, blue: 0.19),
            success: Color(red: 0.31, green: 0.69, blue: 0.48),
            warning: Color(red: 0.94, green: 0.64, blue: 0.34),
            destructive: Color(red: 0.89, green: 0.45, blue: 0.39)
        )
    )

    private static let plain = ThemePalette(
        id: .plain,
        displayName: "Plain",
        description: "Minimal Threads-inspired neutrals with bold blue accents.",
        light: ThemeColorSet(
            accent: Color(red: 0.00, green: 0.58, blue: 0.96),
            accentMuted: Color(red: 0.48, green: 0.79, blue: 1.00),
            backgroundPrimary: Color(red: 1.00, green: 1.00, blue: 1.00),
            backgroundSecondary: Color(red: 0.96, green: 0.96, blue: 0.96),
            surfacePrimary: Color(red: 1.00, green: 1.00, blue: 1.00),
            surfaceSecondary: Color(red: 0.95, green: 0.95, blue: 0.95),
            backgroundCanvas: Color(red: 0.97, green: 0.97, blue: 0.97),
            backgroundListRow: Color(red: 1.00, green: 1.00, blue: 1.00),
            chromeBackground: Color(red: 1.00, green: 1.00, blue: 1.00),
            chromeForeground: Color(red: 0.07, green: 0.07, blue: 0.07),
            textPrimary: Color(red: 0.07, green: 0.07, blue: 0.07),
            textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),
            textTertiary: Color(red: 0.56, green: 0.56, blue: 0.56),
            border: Color(red: 0.88, green: 0.88, blue: 0.88),
            success: Color(red: 0.12, green: 0.54, blue: 0.32),
            warning: Color(red: 0.91, green: 0.64, blue: 0.23),
            destructive: Color(red: 0.89, green: 0.31, blue: 0.31)
        ),
        dark: ThemeColorSet(
            accent: Color(red: 0.18, green: 0.67, blue: 1.00),
            accentMuted: Color(red: 0.04, green: 0.43, blue: 0.77),
            backgroundPrimary: Color(red: 0.06, green: 0.06, blue: 0.06),
            backgroundSecondary: Color(red: 0.09, green: 0.09, blue: 0.09),
            surfacePrimary: Color(red: 0.12, green: 0.12, blue: 0.12),
            surfaceSecondary: Color(red: 0.15, green: 0.15, blue: 0.15),
            backgroundCanvas: Color(red: 0.03, green: 0.03, blue: 0.03),
            backgroundListRow: Color(red: 0.09, green: 0.09, blue: 0.09),
            chromeBackground: Color(red: 0.07, green: 0.07, blue: 0.07),
            chromeForeground: Color(red: 0.95, green: 0.95, blue: 0.95),
            textPrimary: Color(red: 0.95, green: 0.95, blue: 0.95),
            textSecondary: Color(red: 0.71, green: 0.71, blue: 0.71),
            textTertiary: Color(red: 0.48, green: 0.48, blue: 0.48),
            border: Color(red: 0.17, green: 0.17, blue: 0.17),
            success: Color(red: 0.18, green: 0.73, blue: 0.45),
            warning: Color(red: 0.95, green: 0.72, blue: 0.29),
            destructive: Color(red: 1.00, green: 0.36, blue: 0.42)
        )
    )

    private static let forestCanopy = ThemePalette(
        id: .forestCanopy,
        displayName: "Forest Canopy",
        description: "Natural greens and soft sages for focused reading.",
        light: ThemeColorSet(
            accent: Color(red: 0.25, green: 0.64, blue: 0.45),
            accentMuted: Color(red: 0.53, green: 0.79, blue: 0.65),
            backgroundPrimary: Color(red: 0.96, green: 0.98, blue: 0.96),
            backgroundSecondary: Color(red: 0.89, green: 0.95, blue: 0.89),
            surfacePrimary: Color(red: 1.00, green: 1.00, blue: 1.00),
            surfaceSecondary: Color(red: 0.92, green: 0.96, blue: 0.91),
            backgroundCanvas: Color(red: 0.95, green: 0.97, blue: 0.94),
            backgroundListRow: Color(red: 1.00, green: 1.00, blue: 1.00),
            chromeBackground: Color(red: 1.00, green: 1.00, blue: 1.00),
            chromeForeground: Color(red: 0.11, green: 0.25, blue: 0.18),
            textPrimary: Color(red: 0.11, green: 0.23, blue: 0.16),
            textSecondary: Color(red: 0.27, green: 0.40, blue: 0.32),
            textTertiary: Color(red: 0.46, green: 0.58, blue: 0.52),
            border: Color(red: 0.76, green: 0.85, blue: 0.78),
            success: Color(red: 0.18, green: 0.56, blue: 0.35),
            warning: Color(red: 0.86, green: 0.61, blue: 0.17),
            destructive: Color(red: 0.78, green: 0.33, blue: 0.29)
        ),
        dark: ThemeColorSet(
            accent: Color(red: 0.38, green: 0.78, blue: 0.57),
            accentMuted: Color(red: 0.18, green: 0.49, blue: 0.35),
            backgroundPrimary: Color(red: 0.05, green: 0.09, blue: 0.07),
            backgroundSecondary: Color(red: 0.08, green: 0.13, blue: 0.10),
            surfacePrimary: Color(red: 0.09, green: 0.14, blue: 0.11),
            surfaceSecondary: Color(red: 0.12, green: 0.18, blue: 0.15),
            backgroundCanvas: Color(red: 0.04, green: 0.07, blue: 0.05),
            backgroundListRow: Color(red: 0.07, green: 0.11, blue: 0.08),
            chromeBackground: Color(red: 0.09, green: 0.14, blue: 0.11),
            chromeForeground: Color(red: 0.80, green: 0.90, blue: 0.84),
            textPrimary: Color(red: 0.85, green: 0.95, blue: 0.88),
            textSecondary: Color(red: 0.62, green: 0.75, blue: 0.66),
            textTertiary: Color(red: 0.41, green: 0.53, blue: 0.45),
            border: Color(red: 0.16, green: 0.26, blue: 0.20),
            success: Color(red: 0.28, green: 0.77, blue: 0.50),
            warning: Color(red: 0.88, green: 0.70, blue: 0.33),
            destructive: Color(red: 0.85, green: 0.44, blue: 0.39)
        )
    )

    private static let disco = ThemePalette(
        id: .disco,
        displayName: "Disco",
        description: "Vibrant Ice Cube gradients with electric purple accents.",
        light: ThemeColorSet(
            accent: Color(red: 0.73, green: 0.23, blue: 0.89),
            accentMuted: Color(red: 0.85, green: 0.61, blue: 0.97),
            backgroundPrimary: Color(red: 1.00, green: 1.00, blue: 1.00),
            backgroundSecondary: Color(red: 0.94, green: 0.95, blue: 0.95),
            surfacePrimary: Color(red: 1.00, green: 1.00, blue: 1.00),
            surfaceSecondary: Color(red: 0.97, green: 0.96, blue: 0.98),
            backgroundCanvas: Color(red: 0.96, green: 0.96, blue: 0.98),
            backgroundListRow: Color(red: 1.00, green: 1.00, blue: 1.00),
            chromeBackground: Color(red: 1.00, green: 1.00, blue: 1.00),
            chromeForeground: Color(red: 0.15, green: 0.11, blue: 0.25),
            textPrimary: Color(red: 0.13, green: 0.09, blue: 0.20),
            textSecondary: Color(red: 0.29, green: 0.24, blue: 0.40),
            textTertiary: Color(red: 0.48, green: 0.43, blue: 0.59),
            border: Color(red: 0.84, green: 0.82, blue: 0.89),
            success: Color(red: 0.22, green: 0.72, blue: 0.48),
            warning: Color(red: 0.90, green: 0.60, blue: 0.24),
            destructive: Color(red: 0.88, green: 0.29, blue: 0.43)
        ),
        dark: ThemeColorSet(
            accent: Color(red: 0.84, green: 0.45, blue: 1.00),
            accentMuted: Color(red: 0.48, green: 0.23, blue: 0.77),
            backgroundPrimary: Color(red: 0.06, green: 0.08, blue: 0.14),
            backgroundSecondary: Color(red: 0.12, green: 0.14, blue: 0.24),
            surfacePrimary: Color(red: 0.09, green: 0.11, blue: 0.20),
            surfaceSecondary: Color(red: 0.14, green: 0.16, blue: 0.29),
            backgroundCanvas: Color(red: 0.05, green: 0.07, blue: 0.12),
            backgroundListRow: Color(red: 0.08, green: 0.10, blue: 0.20),
            chromeBackground: Color(red: 0.09, green: 0.11, blue: 0.20),
            chromeForeground: Color(red: 0.90, green: 0.91, blue: 1.00),
            textPrimary: Color(red: 0.91, green: 0.92, blue: 1.00),
            textSecondary: Color(red: 0.70, green: 0.73, blue: 0.85),
            textTertiary: Color(red: 0.49, green: 0.51, blue: 0.64),
            border: Color(red: 0.17, green: 0.19, blue: 0.33),
            success: Color(red: 0.27, green: 0.84, blue: 0.60),
            warning: Color(red: 1.00, green: 0.78, blue: 0.41),
            destructive: Color(red: 1.00, green: 0.43, blue: 0.57)
        )
    )

    public static let allPalettes: [ThemePalette] = [
        mintClassic,
        midnight,
        sunsetDunes,
        plain,
        forestCanopy,
        disco
    ]

    public static func palette(for id: ThemePaletteID) -> ThemePalette {
        allPalettes.first(where: { $0.id == id }) ?? mintClassic
    }

    public static func defaultPalette(for _: ColorScheme) -> ThemePalette {
        midnight
    }
}
