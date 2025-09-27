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
    public private(set) var usesSystemPalette: Bool
    public private(set) var colorScheme: ColorScheme
    public private(set) var tokens: ThemeTokens

    private init(
        paletteID: ThemePaletteID = .midnight,
        usesSystemPalette: Bool = true,
        colorScheme: ColorScheme = .light
    ) {
        self.paletteID = paletteID
        self.usesSystemPalette = usesSystemPalette
        self.colorScheme = colorScheme
        let palette = ThemePaletteLibrary.defaultPalette(for: colorScheme)
        self.tokens = ThemeTokens(colors: ThemeColors(set: palette.colors(for: colorScheme)))
    }

    public var colors: ThemeColors { tokens.colors }

    public func configure(
        paletteID: ThemePaletteID,
        usesSystemPalette: Bool
    ) {
        self.paletteID = paletteID
        self.usesSystemPalette = usesSystemPalette
        refreshTokens()
    }

    public func selectPalette(_ newPaletteID: ThemePaletteID) {
        paletteID = newPaletteID
        refreshTokens()
    }

    public func setUsesSystemPalette(_ flag: Bool) {
        usesSystemPalette = flag
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
        palette(for: resolvedPaletteID(for: colorScheme))
    }

    private func refreshTokens() {
        let palette = activePalette()
        tokens = ThemeTokens(colors: ThemeColors(set: palette.colors(for: colorScheme)))
    }

    private func resolvedPaletteID(for scheme: ColorScheme) -> ThemePaletteID {
        if usesSystemPalette {
            return ThemePaletteLibrary.defaultPalette(for: scheme).id
        }
        return paletteID
    }
}
