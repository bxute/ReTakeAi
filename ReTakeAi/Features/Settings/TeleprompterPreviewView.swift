//
//  TeleprompterPreviewView.swift
//  ReTakeAi
//

import SwiftUI

/// A looping preview of the teleprompter with current settings
struct TeleprompterPreviewView: View {
    let preferences: TeleprompterPreferences
    let restartTrigger: Bool
    
    private static let sampleText = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs."
    
    @State private var isRunning = false
    @State private var loopID = UUID()
    
    private var scrollDuration: TimeInterval {
        let baseRate = TeleprompterTimingCalculator.defaultCharsPerSecond
        let adjustedRate = baseRate * preferences.defaultSpeed.multiplier
        return TeleprompterTimingCalculator.duration(
            for: Self.sampleText,
            charsPerSecond: adjustedRate
        )
    }
    
    var body: some View {
        ZStack {
            AppTheme.Colors.surface
            
            HorizontalTeleprompterOverlay(
                text: Self.sampleText,
                isRunning: isRunning,
                direction: preferences.scrollDirection,
                scrollDuration: scrollDuration,
                fontSize: preferences.textSize,
                opacity: 1.0,
                mirror: preferences.mirrorTextForFrontCamera,
                onComplete: {
                    // Loop: restart after a brief pause
                    restartPreview()
                }
            )
            .id(loopID)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .onAppear {
            startPreview()
        }
        .onDisappear {
            isRunning = false
        }
        .onChange(of: restartTrigger) { _, _ in
            restartPreview()
        }
        .onChange(of: preferences.textSize) { _, _ in
            restartPreview()
        }
        .onChange(of: preferences.mirrorTextForFrontCamera) { _, _ in
            restartPreview()
        }
    }
    
    private func startPreview() {
        loopID = UUID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isRunning = true
        }
    }
    
    private func restartPreview() {
        isRunning = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startPreview()
        }
    }
}
