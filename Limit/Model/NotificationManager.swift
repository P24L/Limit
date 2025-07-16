//
//  NotificationManager.swift
//  Limit
//
//  Created by assistant on 2025-07-15.
//

import Foundation
import SwiftUI
import ATProtoKit

@Observable
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    
    private var notifications: [String: NotificationWrapper] = [:]
    private var lastFetchTime: Date?
    private var refreshTimer: Timer?
    
    @ObservationIgnored
    private var client: BlueskyClient?
    
    var unreadCount: Int = 0
    var allNotifications: [NotificationWrapper] {
        Array(notifications.values).sorted { $0.indexedAt > $1.indexedAt }
    }
    
    private init() {}
    
    func setClient(_ client: BlueskyClient) {
        self.client = client
    }
    
    func startPeriodicRefresh() {
        DevLogger.shared.log("NotificationManager.swift - starting periodic refresh")
        
        // Okamžitě načíst počet nepřečtených
        Task {
            await updateUnreadCount()
        }
        
        // Zrušit existující timer
        refreshTimer?.invalidate()
        
        // Nastavit nový timer na 20 minut
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1200, repeats: true) { _ in
            Task { @MainActor in
                await self.updateUnreadCount()
            }
        }
    }
    
    func stopPeriodicRefresh() {
        DevLogger.shared.log("NotificationManager.swift - stopping periodic refresh")
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func loadNotifications(cursor: String? = nil) async {
        guard let client = client else {
            DevLogger.shared.log("NotificationManager.swift - loadNotifications - no client available")
            return
        }
        
        let result = await client.fetchNotifications(limit: 50, cursor: cursor)
        
        // Přidat nové notifikace do dictionary
        for notification in result.notifications {
            notifications[notification.uri] = notification
        }
        
        // Aktualizovat počet nepřečtených
        await updateUnreadCount()
        
        DevLogger.shared.log("NotificationManager.swift - loaded \(result.notifications.count) notifications")
    }
    
    func markAllAsRead() async {
        guard let client = client else { 
            DevLogger.shared.log("NotificationManager.swift - markAllAsRead - no client available")
            return 
        }
        
        DevLogger.shared.log("NotificationManager.swift - markAllAsRead called")
        
        // Call updateSeen API to mark notifications as read on server
        let result: Void? = await client.performAuthenticatedRequest {
            try await client.protoClient?.updateSeen(seenAt: Date())
        }
        
        if result != nil {
            DevLogger.shared.log("NotificationManager.swift - successfully updated seen timestamp on server")
        } else {
            DevLogger.shared.log("NotificationManager.swift - failed to update seen timestamp on server")
        }
        
        // Update local state regardless of API result
        for (_, notification) in notifications {
            notification.isRead = true
        }
        
        // Reset unread count
        unreadCount = 0
    }
    
    private func updateUnreadCount() async {
        guard let client = client else { return }
        
        let count = await client.getUnreadNotificationCount()
        unreadCount = count
        DevLogger.shared.log("NotificationManager.swift - unread count updated to \(count)")
    }
    
    func clearNotifications() {
        notifications.removeAll()
        lastFetchTime = nil
    }
}