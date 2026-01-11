//
//  HorizontalTeleprompterOverlay.swift
//  ReTakeAi
//

import SwiftUI

/// A single-line marquee text that scrolls linearly right→left (or left→right).
/// This view has NO background; the parent is responsible for any container styling.
///
/// Scroll speed is calculated internally:
///   `pointsPerSecond = (textWidth + viewportWidth) / targetDuration`
///
/// This guarantees the full text scrolls in exactly `targetDuration` seconds.
/// Calls `onComplete` when the text has fully exited the viewport.
struct HorizontalTeleprompterOverlay: View {
    let text: String
    let isRunning: Bool
    let direction: TeleprompterScrollDirection
    let targetDuration: TimeInterval
    let fontSize: Double
    let opacity: Double
    let mirror: Bool
    var onComplete: (() -> Void)? = nil

    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var startTime: TimeInterval?
    @State private var didComplete = false

    /// Calculated scroll speed: (textWidth + viewportWidth) / targetDuration
    private var pointsPerSecond: Double {
        let totalDistance = Double(contentWidth + viewportWidth)
        let duration = max(1.0, targetDuration)
        return totalDistance / duration
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isRunning)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let (xOffset, finished) = computeOffset(viewportWidth: viewportWidth, now: now)

            GeometryReader { proxy in
                Text(cleaned(text))
                    .font(.system(size: fontSize, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(opacity))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textProxy in
                            Color.clear
                                .onAppear { contentWidth = textProxy.size.width }
                                .onChange(of: textProxy.size.width) { _, newW in contentWidth = newW }
                        }
                    )
                    .offset(x: xOffset)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                    .scaleEffect(x: mirror ? -1 : 1, y: 1, anchor: .center)
                    .onAppear { viewportWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newW in viewportWidth = newW }
            }
            .clipped()
            .task(id: finished) {
                // Trigger completion when finished becomes true
                if finished {
                    triggerCompletionIfNeeded()
                }
            }
        }
        .onAppear {
            didComplete = false
            if isRunning {
                startTime = Date().timeIntervalSinceReferenceDate
            }
        }
        .onChange(of: isRunning) { _, running in
            if running {
                didComplete = false
                startTime = Date().timeIntervalSinceReferenceDate
            } else {
                startTime = nil
            }
        }
    }

    private func triggerCompletionIfNeeded() {
        guard !didComplete else { return }
        didComplete = true
        onComplete?()
    }

    /// Returns (offset, isFinished)
    private func computeOffset(viewportWidth: CGFloat, now: TimeInterval) -> (CGFloat, Bool) {
        guard isRunning, let start = startTime else {
            // Not running → text starts off-screen
            let offset = direction == .rightToLeft ? viewportWidth : -contentWidth
            return (offset, false)
        }

        let elapsed = now - start
        let traveled = CGFloat(elapsed * pointsPerSecond)
        let totalDistance = contentWidth + viewportWidth

        switch direction {
        case .rightToLeft:
            // Start at right edge, move left linearly
            let offset = viewportWidth - traveled
            // Finished when text has fully exited left edge (offset < -contentWidth)
            let finished = traveled >= totalDistance
            return (offset, finished)
        case .leftToRight:
            // Start off-screen left, move right linearly
            let offset = -contentWidth + traveled
            // Finished when text has fully exited right edge (offset > viewportWidth)
            let finished = traveled >= totalDistance
            return (offset, finished)
        }
    }

    private func cleaned(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


