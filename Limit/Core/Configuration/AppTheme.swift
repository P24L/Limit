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
        @AppStorage("theme_accentColor") public var accentColorHex: String = "#007AFF" // Default iOS blue
        @AppStorage("theme_useSystemAccent") public var useSystemAccent: Bool = true
        @AppStorage("theme_cornerRadius") public var cornerRadius: Double = 12.0
        @AppStorage("theme_contentPadding") public var contentPadding: Double = 16.0
        @AppStorage("theme_compactMode") public var compactMode: Bool = false

        init() {}
    }

    // MARK: - Singleton
    public static let shared = AppTheme()
    private let storage = Storage()

    // MARK: - Public Properties

    public var accentColor: Color {
        didSet {
            storage.accentColorHex = accentColor.toHex() ?? "#007AFF"
        }
    }

    public var useSystemAccent: Bool {
        didSet {
            storage.useSystemAccent = useSystemAccent
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

    public var effectiveAccentColor: Color {
        useSystemAccent ? Color.accentColor : accentColor
    }

    public var effectivePadding: Double {
        compactMode ? contentPadding * 0.75 : contentPadding
    }

    public var postCardPadding: Double {
        compactMode ? 8 : 12
    }

    public var postCardSpacing: Double {
        compactMode ? 4 : 8
    }

    // MARK: - Initialization
    private init() {
        // Load from storage
        accentColor = Color(hex: storage.accentColorHex)
        useSystemAccent = storage.useSystemAccent
        cornerRadius = storage.cornerRadius
        contentPadding = storage.contentPadding
        compactMode = storage.compactMode
    }

    // MARK: - Public Methods

    public func resetToDefaults() {
        accentColor = .blue
        useSystemAccent = true
        cornerRadius = 12.0
        contentPadding = 16.0
        compactMode = false

        DevLogger.shared.log("AppTheme - Reset to defaults")
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

// MARK: - Color Extensions

extension Color {
    func toHex() -> String? {
        let uiColor = UIColor(self)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = Float(components.count >= 4 ? components[3] : 1.0)

        if a < 1 {
            return String(format: "%02lX%02lX%02lX%02lX",
                          lroundf(a * 255),
                          lroundf(r * 255),
                          lroundf(g * 255),
                          lroundf(b * 255))
        } else {
            return String(format: "%02lX%02lX%02lX",
                          lroundf(r * 255),
                          lroundf(g * 255),
                          lroundf(b * 255))
        }
    }
}