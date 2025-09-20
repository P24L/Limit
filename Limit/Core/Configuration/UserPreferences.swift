//
//  UserPreferences.swift
//  Limit
//
//  Created by Zdenek Indra on 17.01.2025.
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
public class UserPreferences {
    // MARK: - Storage Class
    class Storage {
        // Visual Preferences
        @AppStorage("isDarkMode") public var isDarkMode: Bool = false

        // Timeline Preferences
        @AppStorage("showRepliesToOthers") public var showRepliesToOthers: Bool = true
        @AppStorage("showDirectReplyContext") public var showDirectReplyContext: Bool = true

        // Debug Settings
        @AppStorage("debugMode") public var debugMode: Bool = false

        // Computed Timeline
        @AppStorage("computedTimelineCacheTimeout") public var computedTimelineCacheTimeout: TimeInterval = 600 // 10 minutes

        // Bookmarks
        @AppStorage("bookmarksSyncEnabled") public var bookmarksSyncEnabled: Bool = true

        // General App Behavior
        @AppStorage("hasSeenOnboarding") public var hasSeenOnboarding: Bool = false
        @AppStorage("lastAppVersion") public var lastAppVersion: String = ""

        init() {
            // Perform any migration if needed
            migrateSettingsIfNeeded()
        }

        private func migrateSettingsIfNeeded() {
            // Check if this is first launch with new preferences system
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            if lastAppVersion.isEmpty {
                lastAppVersion = currentVersion
                DevLogger.shared.log("UserPreferences - First launch with preferences system, version: \(currentVersion)")
            } else if lastAppVersion != currentVersion {
                DevLogger.shared.log("UserPreferences - App updated from \(lastAppVersion) to \(currentVersion)")
                lastAppVersion = currentVersion
            }
        }
    }

    // MARK: - Singleton
    public static let shared = UserPreferences()
    private let storage = Storage()

    // MARK: - Public Properties with Observers

    // Visual Preferences
    public var isDarkMode: Bool {
        didSet {
            storage.isDarkMode = isDarkMode
            applyThemeChange()
        }
    }

    // Timeline Preferences
    public var showRepliesToOthers: Bool {
        didSet {
            storage.showRepliesToOthers = showRepliesToOthers
        }
    }

    public var showDirectReplyContext: Bool {
        didSet {
            storage.showDirectReplyContext = showDirectReplyContext
        }
    }

    // Debug Settings
    public var debugMode: Bool {
        didSet {
            storage.debugMode = debugMode
        }
    }

    // Computed Timeline
    public var computedTimelineCacheTimeout: TimeInterval {
        didSet {
            storage.computedTimelineCacheTimeout = computedTimelineCacheTimeout
        }
    }

    // Bookmarks
    public var bookmarksSyncEnabled: Bool {
        didSet {
            storage.bookmarksSyncEnabled = bookmarksSyncEnabled
        }
    }

    // General App Behavior
    public var hasSeenOnboarding: Bool {
        didSet {
            storage.hasSeenOnboarding = hasSeenOnboarding
        }
    }

    public var lastAppVersion: String {
        didSet {
            storage.lastAppVersion = lastAppVersion
        }
    }

    // MARK: - Initialization
    private init() {
        // Load from storage
        isDarkMode = storage.isDarkMode
        showRepliesToOthers = storage.showRepliesToOthers
        showDirectReplyContext = storage.showDirectReplyContext
        debugMode = storage.debugMode
        computedTimelineCacheTimeout = storage.computedTimelineCacheTimeout
        bookmarksSyncEnabled = storage.bookmarksSyncEnabled
        hasSeenOnboarding = storage.hasSeenOnboarding
        lastAppVersion = storage.lastAppVersion

        // Apply initial theme
        applyThemeChange()
    }

    // MARK: - Helper Methods

    private func applyThemeChange() {
        Task { @MainActor in
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first?
                .overrideUserInterfaceStyle = isDarkMode ? .dark : .light
        }
    }

    // MARK: - Public Methods

    public func resetToDefaults() {
        isDarkMode = false
        showRepliesToOthers = true
        showDirectReplyContext = true
        debugMode = false
        computedTimelineCacheTimeout = 600
        bookmarksSyncEnabled = true

        DevLogger.shared.log("UserPreferences - Reset to defaults")
    }

    public func exportSettings() -> [String: Any] {
        return [
            "isDarkMode": isDarkMode,
            "showRepliesToOthers": showRepliesToOthers,
            "showDirectReplyContext": showDirectReplyContext,
            "debugMode": debugMode,
            "computedTimelineCacheTimeout": computedTimelineCacheTimeout,
            "bookmarksSyncEnabled": bookmarksSyncEnabled,
            "hasSeenOnboarding": hasSeenOnboarding,
            "lastAppVersion": lastAppVersion
        ]
    }

    public func importSettings(_ settings: [String: Any]) {
        if let value = settings["isDarkMode"] as? Bool {
            isDarkMode = value
        }
        if let value = settings["showRepliesToOthers"] as? Bool {
            showRepliesToOthers = value
        }
        if let value = settings["showDirectReplyContext"] as? Bool {
            showDirectReplyContext = value
        }
        if let value = settings["debugMode"] as? Bool {
            debugMode = value
        }
        if let value = settings["computedTimelineCacheTimeout"] as? TimeInterval {
            computedTimelineCacheTimeout = value
        }
        if let value = settings["bookmarksSyncEnabled"] as? Bool {
            bookmarksSyncEnabled = value
        }

        DevLogger.shared.log("UserPreferences - Settings imported")
    }
}