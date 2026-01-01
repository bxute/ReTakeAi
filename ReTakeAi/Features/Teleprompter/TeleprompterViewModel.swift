//
//  TeleprompterViewModel.swift
//  SceneFlow
//

import Foundation
import SwiftUI

@MainActor
@Observable
class TeleprompterViewModel {
    var settings: TeleprompterSettings
    var currentText: String
    var scrollOffset: CGFloat = 0
    var isPaused = false
    
    private var scrollTimer: Timer?
    
    init(text: String, settings: TeleprompterSettings = TeleprompterSettings()) {
        self.currentText = text
        self.settings = settings
    }
    
    func startScrolling() {
        guard settings.isEnabled && !isPaused else { return }
        
        let pixelsPerSecond = settings.scrollSpeed / 60.0 * 20
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.scrollOffset += pixelsPerSecond * 0.016
            }
        }
        
        AppLogger.ui.info("Teleprompter scrolling started")
    }
    
    func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        AppLogger.ui.info("Teleprompter scrolling stopped")
    }
    
    func pauseScrolling() {
        isPaused = true
        stopScrolling()
    }
    
    func resumeScrolling() {
        isPaused = false
        startScrolling()
    }
    
    func resetScroll() {
        scrollOffset = 0
        isPaused = false
    }
    
    func updateSettings(_ newSettings: TeleprompterSettings) {
        let wasScrolling = scrollTimer != nil
        stopScrolling()
        
        settings = newSettings
        
        if wasScrolling && settings.isEnabled {
            startScrolling()
        }
    }
    
    func updateScrollSpeed(_ speed: Double) {
        settings.scrollSpeed = speed
    }
    
    func updateFontSize(_ size: CGFloat) {
        settings.fontSize = size
    }
    
    func cleanup() {
        stopScrolling()
    }
}
