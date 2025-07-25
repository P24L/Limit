//
//  Date.swift
//  BeDR
//
//  Created by Zdenek Indra on 14.05.2025.
//
import Foundation

extension Date {
    var relativeFormatted: String {
        let aDate: TimeInterval = 60 * 60 * 24
        let isOlderThanADay = Date().timeIntervalSince(self) >= aDate
        
        if isOlderThanADay {
            return DateFormatterCache.shared.createdAtRelativeFormatter.localizedString(for: self, relativeTo: Date())
        } else {
            return Duration.seconds(-self.timeIntervalSinceNow).formatted(.units(width: .narrow, maximumUnitCount: 1))
        }
    }
}
