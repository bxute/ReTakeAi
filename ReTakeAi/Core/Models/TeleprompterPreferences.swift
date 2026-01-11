//
//  TeleprompterPreferences.swift
//  ReTakeAi
//

import Foundation

enum TeleprompterScrollDirection: String, Codable, CaseIterable, Hashable, Identifiable {
    case rightToLeft
    case leftToRight

    var id: String { rawValue }
}

enum TeleprompterSpeedPreset: String, Codable, CaseIterable, Hashable, Identifiable {
    case slow
    case normal
    case fast

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .slow: return 0.8
        case .normal: return 1.0
        case .fast: return 1.25
        }
    }
}

enum SetupCountdownDuration: Int, Codable, CaseIterable, Hashable, Identifiable {
    case s0 = 0
    case s5 = 5
    case s10 = 10

    var id: Int { rawValue }
}

struct TeleprompterPreferences: Codable, Hashable {
    var scrollDirection: TeleprompterScrollDirection
    var defaultSpeed: TeleprompterSpeedPreset
    var textSize: Double
    var textOpacity: Double
    var mirrorTextForFrontCamera: Bool
    var setupCountdown: SetupCountdownDuration
    var startBeepEnabled: Bool
    var autoStopEnabled: Bool

    init(
        scrollDirection: TeleprompterScrollDirection = .rightToLeft,
        defaultSpeed: TeleprompterSpeedPreset = .slow,
        textSize: Double = 28,
        textOpacity: Double = 0.75,
        mirrorTextForFrontCamera: Bool = false,
        setupCountdown: SetupCountdownDuration = .s10,
        startBeepEnabled: Bool = true,
        autoStopEnabled: Bool = true
    ) {
        self.scrollDirection = scrollDirection
        self.defaultSpeed = defaultSpeed
        self.textSize = textSize
        self.textOpacity = textOpacity
        self.mirrorTextForFrontCamera = mirrorTextForFrontCamera
        self.setupCountdown = setupCountdown
        self.startBeepEnabled = startBeepEnabled
        self.autoStopEnabled = autoStopEnabled
    }
}


