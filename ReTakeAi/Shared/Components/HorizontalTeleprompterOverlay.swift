//
//  HorizontalTeleprompterOverlay.swift
//  ReTakeAi
//

import SwiftUI
import UIKit
import Combine

/// A single-line marquee text that scrolls linearly right→left (or left→right).
/// This view has NO background; the parent is responsible for any container styling.
///
/// **Linked Timing Model:**
/// - `scrollDuration` is the single source of truth for timing
/// - Scroll speed is derived: `(textWidth + viewportWidth) / scrollDuration`
/// - `onComplete` fires when text has fully exited the viewport
/// - Recording should stop based on `onComplete`, not a fixed timer
struct HorizontalTeleprompterOverlay: View {
    let text: String
    let isRunning: Bool
    let direction: TeleprompterScrollDirection
    let scrollDuration: TimeInterval
    let fontSize: Double
    let opacity: Double
    let mirror: Bool
    var onComplete: (() -> Void)? = nil

    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var startTime: TimeInterval?
    @State private var completionTimer: AnyCancellable?
    @State private var didComplete = false

    /// Total distance text must travel to fully exit the viewport
    private var totalScrollDistance: CGFloat {
        contentWidth + viewportWidth
    }

    /// Scroll speed in points per second, derived from duration
    private var pointsPerSecond: Double {
        let distance = Double(totalScrollDistance)
        let duration = max(1.0, scrollDuration)
        return distance / duration
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isRunning)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let xOffset = computeOffset(now: now)

            GeometryReader { proxy in
                Text(styledText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textProxy in
                            Color.clear
                                .onAppear { 
                                    contentWidth = textProxy.size.width
                                    scheduleCompletionIfNeeded()
                                }
                                .onChange(of: textProxy.size.width) { _, newW in 
                                    contentWidth = newW
                                    scheduleCompletionIfNeeded()
                                }
                        }
                    )
                    .offset(x: xOffset)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                    .scaleEffect(x: mirror ? -1 : 1, y: 1, anchor: .center)
                    .onAppear { 
                        viewportWidth = proxy.size.width
                        scheduleCompletionIfNeeded()
                    }
                    .onChange(of: proxy.size.width) { _, newW in 
                        viewportWidth = newW
                        scheduleCompletionIfNeeded()
                    }
            }
            .clipped()
        }
        .onAppear {
            didComplete = false
            if isRunning {
                startTime = Date().timeIntervalSinceReferenceDate
                scheduleCompletionIfNeeded()
            }
        }
        .onChange(of: isRunning) { _, running in
            if running {
                didComplete = false
                startTime = Date().timeIntervalSinceReferenceDate
                scheduleCompletionIfNeeded()
            } else {
                startTime = nil
                completionTimer?.cancel()
                completionTimer = nil
            }
        }
        .onDisappear {
            completionTimer?.cancel()
            completionTimer = nil
        }
    }

    /// Schedule a timer to fire when scrolling completes
    private func scheduleCompletionIfNeeded() {
        guard isRunning, !didComplete, contentWidth > 0, viewportWidth > 0 else { return }
        
        // Cancel any existing timer
        completionTimer?.cancel()
        
        // Calculate remaining time until text exits viewport
        let elapsed = startTime.map { Date().timeIntervalSinceReferenceDate - $0 } ?? 0
        let totalTime = Double(totalScrollDistance) / pointsPerSecond
        let remaining = max(0, totalTime - elapsed)
        
        guard remaining > 0 else {
            // Already finished
            triggerCompletion()
            return
        }
        
        // Schedule timer to fire when scrolling completes
        completionTimer = Timer.publish(every: remaining, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [self] _ in
                triggerCompletion()
            }
    }

    private func triggerCompletion() {
        guard !didComplete else { return }
        didComplete = true
        onComplete?()
    }

    private func computeOffset(now: TimeInterval) -> CGFloat {
        guard isRunning, let start = startTime else {
            // Not running → text starts off-screen
            return direction == .rightToLeft ? viewportWidth : -contentWidth
        }

        let elapsed = now - start
        let traveled = CGFloat(elapsed * pointsPerSecond)

        switch direction {
        case .rightToLeft:
            // Start at right edge, move left linearly
            return viewportWidth - traveled
        case .leftToRight:
            // Start off-screen left, move right linearly
            return -contentWidth + traveled
        }
    }

    /// Styled text with sentence spacing for improved readability
    /// Adds extra horizontal space after sentence-ending punctuation (. ? !)
    private var styledText: AttributedString {
        let cleanedText = cleaned(text)
        var result = AttributedString()
        
        // Sentence spacing multiplier (proportional to font size)
        let sentenceSpacing = fontSize * 1.4
        
        // Base attributes for all text
        let baseAttributes = AttributeContainer([
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(opacity)
        ])
        
        // Process text character by character to add spacing after sentence endings
        var i = cleanedText.startIndex
        while i < cleanedText.endIndex {
            let char = cleanedText[i]
            var charStr = AttributedString(String(char))
            charStr.mergeAttributes(baseAttributes)
            
            // Check if this is sentence-ending punctuation followed by a space
            let nextIndex = cleanedText.index(after: i)
            let isSentenceEnd = (char == "." || char == "?" || char == "!")
            let isFollowedBySpace = nextIndex < cleanedText.endIndex && cleanedText[nextIndex] == " "
            
            if isSentenceEnd && isFollowedBySpace {
                // Add extra kerning after sentence-ending punctuation
                charStr.kern = sentenceSpacing
            }
            
            result.append(charStr)
            i = nextIndex
        }
        
        return result
    }

    private func cleaned(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Scroll Duration Calculator

/// Helper to calculate scroll duration from script and speaking rate
enum TeleprompterTimingCalculator {
    
    /// Average characters per second for comfortable reading
    /// ~150 words/min ≈ 12.5 chars/sec (assuming avg 5 chars/word)
    static let defaultCharsPerSecond: Double = 12.5
    
    /// Calculate scroll duration based on script length and speaking rate
    /// - Parameters:
    ///   - script: The script text
    ///   - charsPerSecond: Reading speed in characters per second
    /// - Returns: Duration in seconds
    static func duration(for script: String, charsPerSecond: Double = defaultCharsPerSecond) -> TimeInterval {
        let cleaned = script
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let charCount = Double(cleaned.count)
        let rate = max(1.0, charsPerSecond)
        return max(3.0, charCount / rate) // Minimum 3 seconds
    }
    
    /// Calculate scroll duration using target duration (user-specified)
    /// This is for when user specifies "I want to speak for X seconds"
    static func duration(targetSeconds: Int) -> TimeInterval {
        return max(3.0, TimeInterval(targetSeconds))
    }
}
