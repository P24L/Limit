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
        
        // Load the Analytics configuration file
        guard let analyticsConfigPath = Bundle.main.path(forResource: "GoogleService-Info-Analytics", ofType: "plist") else {
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Analytics config file not found")
            return
        }
        
        guard let analyticsOptions = FirebaseOptions(contentsOfFile: analyticsConfigPath) else {
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Failed to load Analytics config")
            return
        }
        
        // Check if analytics app already exists
        if FirebaseApp.app(name: "analytics") == nil {
            // Configure Firebase Analytics as a secondary app
            FirebaseApp.configure(name: "analytics", options: analyticsOptions)
            DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Analytics Firebase app configured")
        }
        
        analyticsApp = FirebaseApp.app(name: "analytics")
        isInitialized = true
        
        // Log the first event to confirm initialization
        logEvent("analytics_initialized", parameters: [
            "initialization_delay": 15,
            "bundle_id": Bundle.main.bundleIdentifier ?? "unknown"
        ])
        
        DevLogger.shared.log("AnalyticsService.swift - configureAnalytics - Analytics successfully initialized")
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