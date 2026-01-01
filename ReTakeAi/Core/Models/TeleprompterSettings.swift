//
//  TeleprompterSettings.swift
//  SceneFlow
//

import SwiftUI

struct TeleprompterSettings: Codable {
    var isEnabled: Bool
    var scrollSpeed: Double
    var fontSize: CGFloat
    var textColorHex: String
    var backgroundColorHex: String
    var opacity: Double
    var position: TeleprompterPosition
    
    init(
        isEnabled: Bool = true,
        scrollSpeed: Double = 120,
        fontSize: CGFloat = 24,
        textColorHex: String = "#FFFFFF",
        backgroundColorHex: String = "#000000",
        opacity: Double = 0.7,
        position: TeleprompterPosition = .bottom
    ) {
        self.isEnabled = isEnabled
        self.scrollSpeed = scrollSpeed
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.opacity = opacity
        self.position = position
    }
    
    var textColor: Color {
        Color(hex: textColorHex) ?? .white
    }
    
    var backgroundColor: Color {
        Color(hex: backgroundColorHex) ?? .black
    }
}

enum TeleprompterPosition: String, Codable {
    case top
    case bottom
    case center
}
