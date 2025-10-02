//
//  ColorThemeView.swift
//  Limit
//
//  Created by Codex on 05.08.2025.
//

import SwiftUI
import UIKit

struct ColorThemeView: View {
    @Environment(AppTheme.self) private var appTheme
    @Environment(ThemeManager.self) private var themeManager
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(\.colorScheme) private var systemColorScheme

    private var resolvedColorScheme: ColorScheme {
        switch userPreferences.appearanceMode {
        case .system:
            return systemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        Form {
            appearanceSection
            palettesSection
            previewSection
        }
        .navigationTitle("Color Theme")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { synchronizeColorScheme() }
        .onChange(of: userPreferences.appearanceMode) { _, _ in synchronizeColorScheme() }
        .onChange(of: systemColorScheme) { _, _ in synchronizeColorScheme() }
    }

    private var appearanceSection: some View {
        Section("Appearance Mode") {
            Picker("Mode", selection: Binding(
                get: { userPreferences.appearanceMode },
                set: { newValue in
                    userPreferences.appearanceMode = newValue
                    synchronizeColorScheme()
                }
            )) {
                Text("System").tag(AppearanceMode.system)
                Text("Light").tag(AppearanceMode.light)
                Text("Dark").tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)
        }
    }

    private var palettesSection: some View {
        Section("Color Palettes") {
            let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(appTheme.availablePalettes, id: \.id) { palette in
                    let isActive = appTheme.activePalette.id == palette.id
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        appTheme.applyPalette(palette.id)
                        synchronizeColorScheme()
                    } label: {
                        ColorPaletteCard(
                            palette: palette,
                            isActive: isActive,
                            displayScheme: resolvedColorScheme
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            ThemePreviewTile(colors: themeManager.colors)
                .padding(.vertical, 4)
        }
    }

    private func synchronizeColorScheme() {
        themeManager.updateColorScheme(resolvedColorScheme)
    }
}

private struct ColorPaletteCard: View {
    let palette: ThemePalette
    let isActive: Bool
    let displayScheme: ColorScheme

    private var currentSet: ThemeColorSet {
        palette.colors(for: displayScheme)
    }

    private var lightSet: ThemeColorSet {
        palette.colors(for: .light)
    }

    private var darkSet: ThemeColorSet {
        palette.colors(for: .dark)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(palette.displayName)
                    .font(.headline)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(currentSet.accent)
                }
            }

            Text(palette.description)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                paletteSwatch(color: lightSet.backgroundPrimary)
                paletteSwatch(color: darkSet.backgroundPrimary)
                paletteSwatch(color: currentSet.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(currentSet.backgroundPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? currentSet.accent : Color.secondary.opacity(0.2), lineWidth: isActive ? 2 : 1)
        )
    }

    private func paletteSwatch(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 36, height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}

private struct ThemePreviewTile: View {
    let colors: ThemeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline Card")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(colors.textSecondary)

            RoundedRectangle(cornerRadius: 12)
                .fill(colors.surfaceSecondary)
                .frame(height: 120)
                .overlay(
                    VStack(alignment: .leading, spacing: 10) {
                        Capsule()
                            .fill(colors.accent)
                            .frame(width: 90, height: 10)
                        Capsule()
                            .fill(colors.textSecondary.opacity(0.4))
                            .frame(width: 140, height: 8)
                        Capsule()
                            .fill(colors.textSecondary.opacity(0.2))
                            .frame(width: 110, height: 8)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                )

            HStack {
                Capsule()
                    .fill(colors.accent)
                    .frame(width: 120, height: 34)
                    .overlay(
                        Text("Accent Action")
                            .font(.footnote.bold())
                            .foregroundColor(colors.backgroundPrimary)
                    )
                Spacer()
                Circle()
                    .fill(colors.accentMuted)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colors.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colors.border.opacity(0.6), lineWidth: 1)
        )
    }
}
