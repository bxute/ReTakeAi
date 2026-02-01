//
//  ComparisonCard.swift
//  ReTakeAi
//
//  Reusable comparison card for audio debug views
//

import SwiftUI

struct ComparisonCard: View {
    let title: String
    let duration: TimeInterval
    let rms: Float
    let waveform: [Float]
    let isPlaying: Bool
    let onPlay: () -> Void
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Spacer()
                Text(String(format: "%.1fs", duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Waveform
            if !waveform.isEmpty {
                WaveformView(samples: waveform, color: color, label: "Waveform")
                    .frame(height: 80)
            }

            // Metrics
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("RMS:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.4f", rms))
                        .font(.caption)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("dBFS:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    let dbfs = 20.0 * log10(max(Double(rms), 1e-10))
                    Text(String(format: "%.1f dB", dbfs))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Play Button
            Button(action: onPlay) {
                HStack {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    Text(isPlaying ? "Stop" : "Play")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ComparisonCard(
            title: "Original",
            duration: 5.2,
            rms: 0.05,
            waveform: Array(repeating: 0.0, count: 100).enumerated().map { Float(sin(Double($0.offset) * 0.1)) * 0.5 },
            isPlaying: false,
            onPlay: {},
            color: .gray
        )

        ComparisonCard(
            title: "Processed",
            duration: 5.2,
            rms: 0.03,
            waveform: Array(repeating: 0.0, count: 100).enumerated().map { Float(sin(Double($0.offset) * 0.1)) * 0.3 },
            isPlaying: true,
            onPlay: {},
            color: .blue
        )
    }
    .padding()
}
