//
//  TeleprompterPreferences.swift
//  ReTakeAi
//

import Foundation

enum TeleprompterScrollDirection: String, Codable, CaseIterable, Hashable, Identifiable {
    case rightToLeft
    case leftToRight

    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .rightToLeft: return "→ Left"
        case .leftToRight: return "← Right"
        }
    }
}

enum TeleprompterTextAlignment: String, Codable, CaseIterable, Hashable, Identifiable {
    case left
    case center
    case right
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        }
    }
    
    var systemImage: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
}

enum TeleprompterSpeedPreset: String, Codable, CaseIterable, Hashable, Identifiable {
    case slow
    case normal
    case fast

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .slow: return 0.6
        case .normal: return 0.8
        case .fast: return 1.0
        }
    }
}

enum SetupCountdownDuration: Int, Codable, CaseIterable, Hashable, Identifiable {
    case s0 = 0
    case s5 = 5
    case s10 = 10

    var id: Int { rawValue }
}

enum TeleprompterTextColor: String, Codable, CaseIterable, Hashable, Identifiable {
    case white
    case yellow
    case cyan
    case green
    case orange
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .orange: return "Orange"
        }
    }
    
    var hexValue: String {
        switch self {
        case .white: return "#FFFFFF"
        case .yellow: return "#FFEB3B"
        case .cyan: return "#00BCD4"
        case .green: return "#4CAF50"
        case .orange: return "#FF9800"
        }
    }
}

struct TeleprompterPreferences: Codable, Hashable {
    var scrollDirection: TeleprompterScrollDirection
    var defaultSpeed: TeleprompterSpeedPreset
    var textSize: Double
    var textOpacity: Double
    var textColor: TeleprompterTextColor
    var textAlignment: TeleprompterTextAlignment
    var mirrorTextForFrontCamera: Bool
    var setupCountdown: SetupCountdownDuration
    var startBeepEnabled: Bool
    var autoStopEnabled: Bool

    init(
        scrollDirection: TeleprompterScrollDirection = .rightToLeft,
        defaultSpeed: TeleprompterSpeedPreset = .normal,
        textSize: Double = 28,
        textOpacity: Double = 0.75,
        textColor: TeleprompterTextColor = .white,
        textAlignment: TeleprompterTextAlignment = .center,
        mirrorTextForFrontCamera: Bool = false,
        setupCountdown: SetupCountdownDuration = .s10,
        startBeepEnabled: Bool = true,
        autoStopEnabled: Bool = true
    ) {
        self.scrollDirection = scrollDirection
        self.defaultSpeed = defaultSpeed
        self.textSize = textSize
        self.textOpacity = textOpacity
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.mirrorTextForFrontCamera = mirrorTextForFrontCamera
        self.setupCountdown = setupCountdown
        self.startBeepEnabled = startBeepEnabled
        self.autoStopEnabled = autoStopEnabled
    }
}


