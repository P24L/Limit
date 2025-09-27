//
//  AppTheme.swift
//  Limit
//
//  Created by Zdenek Indra on 17.01.2025.
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
public class AppTheme {
    // MARK: - Theme Storage
    class Storage {
        @AppStorage("theme_palette_id") public var paletteID: String = ThemePaletteID.mintClassic.rawValue
        @AppStorage("theme_followSystemPalette") public var followSystemPalette: Bool = true
        @AppStorage("theme_cornerRadius") public var cornerRadius: Double = 12.0
        @AppStorage("theme_contentPadding") public var contentPadding: Double = 16.0
        @AppStorage("theme_compactMode") public var compactMode: Bool = false

        init() {}
    }

    // MARK: - Singleton
    public static let shared = AppTheme()
    private let storage = Storage()
    private let themeManager = ThemeManager.shared

    // MARK: - Public Properties

    public var selectedPaletteID: ThemePaletteID {
        didSet {
            storage.paletteID = selectedPaletteID.rawValue
            themeManager.configure(
                paletteID: selectedPaletteID,
                usesSystemPalette: usesSystemPalette
            )
        }
    }

    public var usesSystemPalette: Bool {
        didSet {
            storage.followSystemPalette = usesSystemPalette
            themeManager.configure(
                paletteID: selectedPaletteID,
                usesSystemPalette: usesSystemPalette
            )
        }
    }

    public var cornerRadius: Double {
        didSet {
            storage.cornerRadius = cornerRadius
        }
    }

    public var contentPadding: Double {
        didSet {
            storage.contentPadding = contentPadding
        }
    }

    public var compactMode: Bool {
        didSet {
            storage.compactMode = compactMode
        }
    }

    // MARK: - Computed Properties

    public var colors: ThemeColors { themeManager.colors }

    public var effectiveAccentColor: Color { themeManager.colors.accent }

    public var backgroundCanvas: Color { themeManager.colors.backgroundCanvas }
    public var backgroundListRow: Color { themeManager.colors.backgroundListRow }
    public var chromeBackground: Color { themeManager.colors.chromeBackground }
    public var chromeForeground: Color { themeManager.colors.chromeForeground }

    public var effectivePadding: Double {
        compactMode ? contentPadding * 0.75 : contentPadding
    }

    public var postCardPadding: Double {
        compactMode ? 8 : 12
    }

    public var postCardSpacing: Double {
        compactMode ? 4 : 8
    }

    public var availablePalettes: [ThemePalette] {
        themeManager.availablePalettes
    }

    public var activePalette: ThemePalette {
        themeManager.activePalette()
    }

    // MARK: - Initialization
    private init() {
        // Load from storage
        selectedPaletteID = ThemePaletteID(rawValue: storage.paletteID) ?? .mintClassic
        usesSystemPalette = storage.followSystemPalette
        cornerRadius = storage.cornerRadius
        contentPadding = storage.contentPadding
        compactMode = storage.compactMode

        themeManager.configure(
            paletteID: selectedPaletteID,
            usesSystemPalette: usesSystemPalette
        )
    }

    // MARK: - Public Methods

    public func resetToDefaults() {
        selectedPaletteID = .mintClassic
        usesSystemPalette = true
        cornerRadius = 12.0
        contentPadding = 16.0
        compactMode = false

        DevLogger.shared.log("AppTheme - Reset to defaults")
    }

    public func applyPalette(_ paletteID: ThemePaletteID) {
        usesSystemPalette = false
        selectedPaletteID = paletteID
    }

    public func setFollowSystemPalette(_ isEnabled: Bool) {
        usesSystemPalette = isEnabled
    }

    // MARK: - Color Presets

    public static let colorPresets: [(name: String, color: Color)] = [
        ("Blue", .blue),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Teal", .teal),
        ("Indigo", .indigo)
    ]
}
