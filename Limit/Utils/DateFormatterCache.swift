//
//  DateFormatterCache.swift
//  BeDR
//
//  Created by Zdenek Indra on 15.05.2025.
//

import Foundation

class DateFormatterCache: @unchecked Sendable {
    static let shared = DateFormatterCache()
    
    let createdAtRelativeFormatter: RelativeDateTimeFormatter
    let createdAtShortDateFortmatter: DateFormatter
    let createdAtDateFormatter: DateFormatter
    let logTimestampFormatter: DateFormatter
    
    init() {
        let createdAtRelativeFormatter = RelativeDateTimeFormatter()
        createdAtRelativeFormatter.unitsStyle = .short
        createdAtRelativeFormatter.formattingContext = .listItem
        createdAtRelativeFormatter.dateTimeStyle = .numeric
        self.createdAtRelativeFormatter = createdAtRelativeFormatter
        
        let createdAtShortDateFortmatter = DateFormatter()
        createdAtShortDateFortmatter.dateStyle = .short
        createdAtShortDateFortmatter.timeStyle = .none
        self.createdAtShortDateFortmatter = createdAtShortDateFortmatter
        
        let createdAtDateFormatter = DateFormatter()
        createdAtDateFormatter.calendar = .init(identifier: .iso8601)
        createdAtDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        createdAtDateFormatter.timeZone = .init(abbreviation: "UTC")
        self.createdAtDateFormatter = createdAtDateFormatter
        
        let logTimestampFormatter = DateFormatter()
        logTimestampFormatter.dateStyle = .none
        logTimestampFormatter.timeStyle = .medium
        self.logTimestampFormatter = logTimestampFormatter
    }
}
