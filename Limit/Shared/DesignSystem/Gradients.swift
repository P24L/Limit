//
//  Gradients.swift
//  Limit
//
//  Created by Zdenek Indra on 07.06.2025.
//


import SwiftUI

public extension LinearGradient {
  static let indigoPurple = LinearGradient(
    colors: [.indigo, .purple],
    startPoint: .top,
    endPoint: .bottom
  )
  
  static let purpleIndigo = LinearGradient(
    colors: [.purple, .indigo],
    startPoint: .top,
    endPoint: .bottom
  )
    
    static let blueGray = LinearGradient(
        colors: [.blue, .gray],
        startPoint: .top,
        endPoint: .bottom
    )
  
  static let redPurple = LinearGradient(
    colors: [.red, .purple],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
  
  static let indigoPurpleHorizontal = LinearGradient(
    colors: [.indigo, .purple],
    startPoint: .leading,
    endPoint: .trailing
  )
  
  static let indigoPurpleAvatar = LinearGradient(
    colors: [.purple, .indigo],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
  
  static func avatarBorder(hasReply: Bool) -> LinearGradient {
    LinearGradient(
      colors: hasReply
        ? [.purple, .indigo]
        : [.black.opacity(0.5), .indigo.opacity(0.5)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

public extension ShapeStyle where Self == LinearGradient {
    static var indigoPurple: LinearGradient { .indigoPurple }
    static var purpleIndigo: LinearGradient { .purpleIndigo }
    static var blueGray: LinearGradient { .blueGray }
    static var redPurple: LinearGradient { .redPurple }
    static var indigoPurpleHorizontal: LinearGradient { .indigoPurpleHorizontal }
    static var indigoPurpleAvatar: LinearGradient { .indigoPurpleAvatar }
}
