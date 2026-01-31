//
//  WaveformView.swift
//  ReTakeAi
//
//  Visual waveform display for audio comparison
//

import SwiftUI
import AVFoundation

struct WaveformView: View {
    let samples: [Float]
    let color: Color
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let midY = height / 2

                    guard samples.count > 0 else { return }

                    // Downsample if needed
                    let samplesPerPoint = max(1, samples.count / Int(width))
                    var points: [CGPoint] = []

                    for x in 0..<Int(width) {
                        let startIndex = x * samplesPerPoint
                        let endIndex = min(startIndex + samplesPerPoint, samples.count)

                        if startIndex < samples.count {
                            // Get RMS of this slice
                            var sum: Float = 0
                            for i in startIndex..<endIndex {
                                sum += samples[i] * samples[i]
                            }
                            let rms = sqrt(sum / Float(endIndex - startIndex))

                            let y = midY - (CGFloat(rms) * height * 0.8)
                            points.append(CGPoint(x: CGFloat(x), y: y))
                        }
                    }

                    // Draw waveform
                    if let first = points.first {
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }

                        // Mirror bottom half
                        for point in points.reversed() {
                            path.addLine(to: CGPoint(x: point.x, y: height - point.y))
                        }

                        path.closeSubpath()
                    }
                }
                .fill(color.opacity(0.6))
                .overlay(
                    Path { path in
                        let midY = geometry.size.height / 2
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .frame(height: 80)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

// MARK: - Waveform Data Extractor

class WaveformExtractor {
    static func extractSamples(from url: URL, targetSampleCount: Int = 500) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "WaveformExtractor", code: 1, userInfo: nil)
        }

        try file.read(into: buffer)

        guard let floatData = buffer.floatChannelData else {
            throw NSError(domain: "WaveformExtractor", code: 2, userInfo: nil)
        }

        let channelCount = Int(format.channelCount)
        let totalFrames = Int(buffer.frameLength)

        // Calculate absolute values (mono mix if stereo)
        var monoSamples: [Float] = []
        for frame in 0..<totalFrames {
            var sum: Float = 0
            for channel in 0..<channelCount {
                sum += abs(floatData[channel][frame])
            }
            monoSamples.append(sum / Float(channelCount))
        }

        // Downsample to target count
        let samplesPerBucket = max(1, monoSamples.count / targetSampleCount)
        var downsampled: [Float] = []

        for i in stride(from: 0, to: monoSamples.count, by: samplesPerBucket) {
            let endIndex = min(i + samplesPerBucket, monoSamples.count)
            let slice = monoSamples[i..<endIndex]

            // Get max value in this bucket
            let maxValue = slice.max() ?? 0
            downsampled.append(maxValue)
        }

        return downsampled
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(
            samples: (0..<100).map { _ in Float.random(in: 0...1) },
            color: .gray,
            label: "Original"
        )

        WaveformView(
            samples: (0..<100).map { _ in Float.random(in: 0...0.8) },
            color: .green,
            label: "Processed"
        )
    }
    .padding()
}
