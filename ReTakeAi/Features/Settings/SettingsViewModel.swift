//
//  SettingsViewModel.swift
//  ReTakeAi
//

import SwiftUI
import Observation

@Observable
final class SettingsViewModel {
    var preferences: TeleprompterPreferences
    
    /// Tracks if preview should restart (toggles on setting change)
    var previewRestartTrigger: Bool = false
    
    init() {
        self.preferences = TeleprompterPreferencesStore.load()
    }
    
    // MARK: - Speed
    
    var speed: TeleprompterSpeedPreset {
        get { preferences.defaultSpeed }
        set {
            preferences.defaultSpeed = newValue
            save()
            triggerPreviewRestart()
        }
    }
    
    // MARK: - Text Size
    
    var textSize: Double {
        get { preferences.textSize }
        set {
            preferences.textSize = newValue
            save()
        }
    }
    
    var textSizeDisplay: String {
        "\(Int(textSize))pt"
    }
    
    // MARK: - Text Color
    
    var textColor: TeleprompterTextColor {
        get { preferences.textColor }
        set {
            preferences.textColor = newValue
            save()
        }
    }
    
    // MARK: - Text Alignment
    
    var textAlignment: TeleprompterTextAlignment {
        get { preferences.textAlignment }
        set {
            preferences.textAlignment = newValue
            save()
        }
    }
    
    // MARK: - Scroll Direction
    
    var scrollDirection: TeleprompterScrollDirection {
        get { preferences.scrollDirection }
        set {
            preferences.scrollDirection = newValue
            save()
            triggerPreviewRestart()
        }
    }
    
    // MARK: - Countdown Duration
    
    var setupCountdown: SetupCountdownDuration {
        get { preferences.setupCountdown }
        set {
            preferences.setupCountdown = newValue
            save()
        }
    }
    
    // MARK: - Toggles
    
    var mirrorText: Bool {
        get { preferences.mirrorTextForFrontCamera }
        set {
            preferences.mirrorTextForFrontCamera = newValue
            save()
        }
    }
    
    var startBeepEnabled: Bool {
        get { preferences.startBeepEnabled }
        set {
            preferences.startBeepEnabled = newValue
            save()
        }
    }
    
    var autoStopEnabled: Bool {
        get { preferences.autoStopEnabled }
        set {
            preferences.autoStopEnabled = newValue
            save()
        }
    }
    
    // MARK: - Persistence
    
    private func save() {
        TeleprompterPreferencesStore.save(preferences)
    }
    
    private func triggerPreviewRestart() {
        previewRestartTrigger.toggle()
    }
}
