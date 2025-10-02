//
//  UserPreferences.swift
//  Limit
//
//  Created by Zdenek Indra on 17.01.2025.
//

import Foundation
import SwiftUI
import Observation

public enum AppearanceMode: String, Codable {
    case system
    case light
    case dark
}

public struct MutedReplyActor: Codable, Identifiable, Equatable {
    public let did: String
    public let handle: String
    public let displayName: String?
    public let avatarURLString: String?

    public var id: String { did }

    public var avatarURL: URL? {
        guard let avatarURLString else { return nil }
        return URL(string: avatarURLString)
    }

    public init(did: String, handle: String, displayName: String? = nil, avatarURLString: String? = nil) {
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.avatarURLString = avatarURLString
    }

    init?(dictionary: [String: Any]) {
        guard let did = dictionary["did"] as? String,
              let handle = dictionary["handle"] as? String else { return nil }

        self.init(
            did: did,
            handle: handle,
            displayName: dictionary["displayName"] as? String,
            avatarURLString: dictionary["avatarURLString"] as? String
        )
    }

    var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "did": did,
            "handle": handle
        ]

        if let displayName { dict["displayName"] = displayName }
        if let avatarURLString { dict["avatarURLString"] = avatarURLString }

        return dict
    }
}

@MainActor
@Observable
public class UserPreferences {
    // MARK: - Storage Class
    class Storage {
        // Visual Preferences
        @AppStorage("appearanceMode") public var appearanceModeRaw: String = AppearanceMode.system.rawValue

        public var appearanceMode: AppearanceMode {
            get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
            set { appearanceModeRaw = newValue.rawValue }
        }

        // Timeline Preferences
        @AppStorage("showRepliesToOthers") public var showRepliesToOthers: Bool = true
        @AppStorage("showDirectReplyContext") public var showDirectReplyContext: Bool = true
        @AppStorage("mutedReplyActors") public var mutedReplyActorsData: Data = Data()

        // Debug Settings
        @AppStorage("debugMode") public var debugMode: Bool = false

        // Computed Timeline
        @AppStorage("computedTimelineCacheTimeout") public var computedTimelineCacheTimeout: TimeInterval = 600 // 10 minutes

        // Bookmarks
        @AppStorage("bookmarksSyncEnabled") public var bookmarksSyncEnabled: Bool = true

        // General App Behavior
        @AppStorage("hasSeenOnboarding") public var hasSeenOnboarding: Bool = false
        @AppStorage("lastAppVersion") public var lastAppVersion: String = ""
        @AppStorage("openLinksInApp") public var openLinksInApp: Bool = true

        init() {
            // Perform any migration if needed
            migrateSettingsIfNeeded()
        }

        func saveMutedReplyActors(_ actors: [MutedReplyActor]) {
            if let data = try? JSONEncoder().encode(actors) {
                mutedReplyActorsData = data
            }
        }

        func loadMutedReplyActors() -> [MutedReplyActor] {
            guard !mutedReplyActorsData.isEmpty,
                  let actors = try? JSONDecoder().decode([MutedReplyActor].self, from: mutedReplyActorsData) else {
                return []
            }
            return actors
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
    public var appearanceMode: AppearanceMode {
        didSet {
            storage.appearanceMode = appearanceMode
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

    public private(set) var mutedReplyActors: [MutedReplyActor] = [] {
        didSet {
            storage.saveMutedReplyActors(mutedReplyActors)
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

    public var openLinksInApp: Bool {
        didSet {
            storage.openLinksInApp = openLinksInApp
        }
    }

    // MARK: - Initialization
    private init() {
        // Load from storage
        appearanceMode = storage.appearanceMode
        showRepliesToOthers = storage.showRepliesToOthers
        showDirectReplyContext = storage.showDirectReplyContext
        debugMode = storage.debugMode
        computedTimelineCacheTimeout = storage.computedTimelineCacheTimeout
        bookmarksSyncEnabled = storage.bookmarksSyncEnabled
        hasSeenOnboarding = storage.hasSeenOnboarding
        lastAppVersion = storage.lastAppVersion
        mutedReplyActors = storage.loadMutedReplyActors()
        openLinksInApp = storage.openLinksInApp

        // Apply initial theme
        applyThemeChange()
    }

    // MARK: - Helper Methods

    private func applyThemeChange() {
        Task { @MainActor in
            let interfaceStyle: UIUserInterfaceStyle
            switch appearanceMode {
            case .system:
                interfaceStyle = .unspecified
            case .light:
                interfaceStyle = .light
            case .dark:
                interfaceStyle = .dark
            }

            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first?
                .overrideUserInterfaceStyle = interfaceStyle
        }
    }

    // MARK: - Public Methods

    public func resetToDefaults() {
        appearanceMode = .system
        showRepliesToOthers = true
        showDirectReplyContext = true
        debugMode = false
        computedTimelineCacheTimeout = 600
        bookmarksSyncEnabled = true
        mutedReplyActors = []

        DevLogger.shared.log("UserPreferences - Reset to defaults")
    }

    public func exportSettings() -> [String: Any] {
        var settings: [String: Any] = [
            "appearanceMode": appearanceMode.rawValue,
            "showRepliesToOthers": showRepliesToOthers,
            "showDirectReplyContext": showDirectReplyContext,
            "debugMode": debugMode,
            "computedTimelineCacheTimeout": computedTimelineCacheTimeout,
            "bookmarksSyncEnabled": bookmarksSyncEnabled,
            "hasSeenOnboarding": hasSeenOnboarding,
            "lastAppVersion": lastAppVersion
        ]

        settings["mutedReplyActors"] = mutedReplyActors.map { $0.dictionaryRepresentation }

        return settings
    }

    public func importSettings(_ settings: [String: Any]) {
        if let value = settings["appearanceMode"] as? String,
           let mode = AppearanceMode(rawValue: value) {
            appearanceMode = mode
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

        if let muted = settings["mutedReplyActors"] as? [[String: Any]] {
            let actors = muted.compactMap { MutedReplyActor(dictionary: $0) }
            mutedReplyActors = actors
        }

        DevLogger.shared.log("UserPreferences - Settings imported")
    }

    // MARK: - Muted Replies Management

    public func muteReplies(for actor: MutedReplyActor) {
        guard !actor.did.isEmpty else { return }
        if mutedReplyActors.contains(where: { $0.did == actor.did }) { return }
        mutedReplyActors.append(actor)
    }

    public func unmuteReplies(forDid did: String) {
        mutedReplyActors.removeAll { $0.did == did }
    }

    public func isRepliesMuted(forDid did: String) -> Bool {
        mutedReplyActors.contains { $0.did == did }
    }
}
