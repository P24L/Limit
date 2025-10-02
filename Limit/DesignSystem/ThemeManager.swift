//
//  ThemeManager.swift
//  Limit
//
//  Created by Codex on 05.08.2025.
//

import Observation
import SwiftUI

@MainActor
@Observable
public final class ThemeManager {
    public static let shared = ThemeManager()

    public private(set) var paletteID: ThemePaletteID
    public private(set) var colorScheme: ColorScheme
    public private(set) var tokens: ThemeTokens

    private init(
        paletteID: ThemePaletteID = .midnight,
        colorScheme: ColorScheme = .light
    ) {
        self.paletteID = paletteID
        self.colorScheme = colorScheme
        let palette = ThemePaletteLibrary.palette(for: paletteID)
        self.tokens = ThemeTokens(colors: ThemeColors(set: palette.colors(for: colorScheme)))
    }

    public var colors: ThemeColors { tokens.colors }

    public func selectPalette(_ newPaletteID: ThemePaletteID) {
        paletteID = newPaletteID
        refreshTokens()
    }

    public func updateColorScheme(_ newColorScheme: ColorScheme) {
        guard colorScheme != newColorScheme else { return }
        colorScheme = newColorScheme
        refreshTokens()
    }

    public var availablePalettes: [ThemePalette] {
        ThemePaletteLibrary.allPalettes
    }

    public func palette(for id: ThemePaletteID) -> ThemePalette {
        ThemePaletteLibrary.palette(for: id)
    }

    public func activePalette() -> ThemePalette {
        palette(for: paletteID)
    }

    private func refreshTokens() {
        let palette = activePalette()
        tokens = ThemeTokens(colors: ThemeColors(set: palette.colors(for: colorScheme)))
    }
}
