//
//  AnalyticsService.swift
//  Limit
//
//  Created by Zdenek Indra on 13.08.2025.
//

import Foundation
import FirebaseCore
import FirebaseAnalytics

@Observable
@MainActor
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private var analyticsApp: FirebaseApp?
    private var isInitialized = false
    
    private init() {}
    
    func initializeDelayed() {
        DevLogger.shared.log("AnalyticsService.swift - initializeDelayed - scheduling analytics initialization in 15 seconds")
        
        Task {
            // Wait 15 seconds after app start for performance optimization
            try await Task.sleep(for: .seconds(15))
            
            await MainActor.run {
                configureAnalytics()
            }
        }
    }
    
    private func configureAnalytics() {
        guard !isInitialized else {
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - already initialized")
            return
        }
        
        // Determine which config file to use based on bundle ID
        let currentBundleID = Bundle.main.bundleIdentifier ?? "P24L.Limit"
        let configFileName: String
        
        if currentBundleID.hasSuffix(".dev") {
            // Try to load dev-specific config first
            if Bundle.main.path(forResource: "GoogleService-Info-Analytics-Dev", ofType: "plist") != nil {
                configFileName = "GoogleService-Info-Analytics-Dev"
                DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Using dev config file")
            } else {
                // Fallback to production config with bundle ID override
                configFileName = "GoogleService-Info-Analytics"
                DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Dev config not found, using production config with override")
            }
        } else {
            configFileName = "GoogleService-Info-Analytics"
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Using production config file")
        }
        
        // Load the Analytics configuration file
        guard let analyticsConfigPath = Bundle.main.path(forResource: configFileName, ofType: "plist") else {
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Analytics config file not found: \(configFileName)")
            return
        }
        
        guard var analyticsOptions = FirebaseOptions(contentsOfFile: analyticsConfigPath) else {
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Failed to load Analytics config from: \(configFileName)")
            return
        }
        
        // Override Bundle ID if needed (for dev builds using production config)
        if configFileName == "GoogleService-Info-Analytics" && currentBundleID.hasSuffix(".dev") {
            analyticsOptions.bundleID = currentBundleID
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Overriding bundle ID to: \(currentBundleID)")
        }
        
        DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Using bundle ID: \(analyticsOptions.bundleID ?? "unknown")")
        
        // Check if default Firebase app already exists
        if FirebaseApp.app() == nil {
            // Configure Firebase as default app for Analytics to work properly
            FirebaseApp.configure(options: analyticsOptions)
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Default Firebase app configured for Analytics")
        } else {
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Default Firebase app already exists")
        }
        
        analyticsApp = FirebaseApp.app()
        isInitialized = true
        
        // Enable Analytics collection explicitly
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Log the first event to confirm initialization
        logEvent("analytics_initialized", parameters: [
            "initialization_delay": 15,
            "bundle_id": currentBundleID,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "config_type": configFileName.contains("Dev") ? "development" : "production"
        ])
        
        DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Analytics successfully initialized with collection enabled")
    }
    
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard isInitialized else {
            DevLogger.shared.log("AnalyticsService.swift - logEvent - Analytics not initialized yet, skipping event: \(name)")
            return
        }
        
        Analytics.logEvent(name, parameters: parameters)
        DevLogger.shared.log("AnalyticsService.swift - logEvent - Logged event: \(name)")
    }
    
    func logAppOpen() {
        logEvent("app_open_custom", parameters: [
            "timestamp": Date().timeIntervalSince1970,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
    }
    
    func logSessionStart() {
        logEvent("session_start_custom", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func setUserProperty(_ value: String?, forName name: String) {
        guard isInitialized else {
            DevLogger.shared.log("AnalyticsService.swift - setUserProperty - Analytics not initialized yet")
            return
        }
        
        Analytics.setUserProperty(value, forName: name)
        DevLogger.shared.log("AnalyticsService.swift - setUserProperty - Set property: \(name)")
    }
    
    func setUserId(_ userId: String?) {
        guard isInitialized else {
            DevLogger.shared.log("AnalyticsService.swift - setUserId - Analytics not initialized yet")
            return
        }
        
        Analytics.setUserID(userId)
        DevLogger.shared.log("AnalyticsService.swift - setUserId - User ID set")
    }
}