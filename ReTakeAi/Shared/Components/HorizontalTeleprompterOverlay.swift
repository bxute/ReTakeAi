//
//  HorizontalTeleprompterOverlay.swift
//  ReTakeAi
//

import SwiftUI

struct HorizontalTeleprompterOverlay: View {
    let text: String
    let isRunning: Bool
    let direction: TeleprompterScrollDirection
    let pointsPerSecond: Double
    let fontSize: Double
    let opacity: Double
    let mirror: Bool

    @State private var contentWidth: CGFloat = 1
    @State private var viewportWidth: CGFloat = 1
    @State private var elapsed: TimeInterval = 0
    @State private var lastTick: TimeInterval?

    private let spacing: CGFloat = 80

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let xOffset = marqueeOffset(at: t)

            ZStack {
                // Readable, calm pill container
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.black.opacity(0.35))

                GeometryReader { proxy in
                    let w = proxy.size.width
                    HStack(spacing: spacing) {
                        marqueeText
                        marqueeText
                    }
                    .offset(x: xOffset)
                    .onAppear { viewportWidth = max(1, w) }
                    .onChange(of: w) { _, newValue in viewportWidth = max(1, newValue) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .frame(height: 120)
            .padding(.horizontal, 16)
            .opacity(opacity)
            .scaleEffect(x: mirror ? -1 : 1, y: 1, anchor: .center)
            .accessibilityLabel("Teleprompter")
        }
    }

    private var marqueeText: some View {
        Text(cleaned(text))
            .font(.system(size: fontSize, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .lineLimit(2)
            .lineSpacing(10)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contentWidth = max(1, proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, newValue in contentWidth = max(1, newValue) }
                }
            )
    }

    private func marqueeOffset(at t: TimeInterval) -> CGFloat {
        if isRunning {
            if let lastTick {
                elapsed += (t - lastTick)
            }
            lastTick = t
        } else {
            lastTick = nil
        }

        let cycle = contentWidth + spacing
        guard cycle > 1 else { return 0 }

        let base = CGFloat((elapsed * pointsPerSecond).truncatingRemainder(dividingBy: Double(cycle)))
        let signed = (direction == .rightToLeft) ? -base : base

        // Start from slightly outside the viewport so it's centered-ish above eye-line.
        return signed
    }

    private func cleaned(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


