//
//  VoiceEQProcessor.swift
//  ReTakeAi
//
//  Voice EQ - Shapes frequency response for optimal voice clarity
//

import Foundation
import AVFoundation
import Accelerate

/// Voice EQ processor - shapes frequency response to optimize voice clarity
class VoiceEQProcessor: AudioProcessorProtocol {
    let id = "voiceEQ"
    let name = "Voice EQ"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            "preset": "clarity"  // clarity, warmth, broadcast, podcast
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let preset = config["preset"] as? String ?? "clarity"

        AppLogger.mediaProcessing.info("🎙️ VoiceEQ: Starting processing")
        AppLogger.mediaProcessing.info("  Preset: \(preset)")

        // Load audio file
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)

        AppLogger.mediaProcessing.info("  Sample Rate: \(format.sampleRate)")
        AppLogger.mediaProcessing.info("  Channels: \(format.channelCount)")

        // Read entire file into buffer
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "VoiceEQProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        AppLogger.mediaProcessing.info("✅ Read \(frameCount) frames")

        // Get EQ bands for preset
        let eqBands = getEQBands(for: preset)

        // Apply EQ
        AppLogger.mediaProcessing.info("🎛️ Applying EQ preset: \(preset)...")
        for band in eqBands {
            AppLogger.mediaProcessing.info("  \(band.type) @ \(band.frequency) Hz: \(band.gain) dB, Q=\(band.q)")
            applyEQBand(to: buffer, sampleRate: sampleRate, band: band)
        }
        AppLogger.mediaProcessing.info("✅ EQ applied")

        // Write to CAF file
        let cafURL = outputURL.deletingPathExtension().appendingPathExtension("caf")
        try? FileManager.default.removeItem(at: cafURL)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let outputFile = try AVAudioFile(
            forWriting: cafURL,
            settings: outputSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        try outputFile.write(from: buffer)
        AppLogger.mediaProcessing.info("✅ Wrote to CAF file")

        // Convert CAF to M4A if needed
        if outputURL.pathExtension.lowercased() == "m4a" {
            AppLogger.mediaProcessing.info("🔄 Converting CAF to M4A...")
            try await convertToM4A(from: cafURL, to: outputURL)
            try? FileManager.default.removeItem(at: cafURL)
        } else {
            try? FileManager.default.removeItem(at: outputURL)
            try FileManager.default.moveItem(at: cafURL, to: outputURL)
        }

        AppLogger.mediaProcessing.info("✅ VoiceEQ completed")
    }

    struct EQBand {
        enum FilterType: CustomStringConvertible {
            case lowShelf
            case highShelf
            case bell

            var description: String {
                switch self {
                case .lowShelf: return "Low Shelf"
                case .highShelf: return "High Shelf"
                case .bell: return "Bell"
                }
            }
        }

        let type: FilterType
        let frequency: Float  // Hz
        let gain: Float       // dB
        let q: Float          // Q factor
    }

    private func getEQBands(for preset: String) -> [EQBand] {
        switch preset.lowercased() {
        case "clarity":
            return [
                EQBand(type: .lowShelf, frequency: 120, gain: -3, q: 0.7),
                EQBand(type: .bell, frequency: 500, gain: -2, q: 2.0),
                EQBand(type: .bell, frequency: 3000, gain: 5, q: 1.5),
                EQBand(type: .highShelf, frequency: 8000, gain: 2, q: 0.7)
            ]
        case "warmth":
            return [
                EQBand(type: .lowShelf, frequency: 100, gain: 1, q: 0.7),
                EQBand(type: .bell, frequency: 250, gain: 4, q: 1.5),
                EQBand(type: .bell, frequency: 500, gain: -1, q: 2.0),
                EQBand(type: .bell, frequency: 2500, gain: 3, q: 1.5)
            ]
        case "broadcast":
            return [
                EQBand(type: .lowShelf, frequency: 80, gain: -6, q: 0.7),
                EQBand(type: .bell, frequency: 200, gain: -3, q: 1.5),
                EQBand(type: .bell, frequency: 3500, gain: 6, q: 1.2),
                EQBand(type: .highShelf, frequency: 10000, gain: 3, q: 0.7)
            ]
        case "podcast":
            return [
                EQBand(type: .lowShelf, frequency: 100, gain: -2, q: 0.7),
                EQBand(type: .bell, frequency: 250, gain: 2, q: 1.5),
                EQBand(type: .bell, frequency: 3000, gain: 4, q: 1.5),
                EQBand(type: .highShelf, frequency: 8000, gain: 1, q: 0.7)
            ]
        default:
            // Default to clarity
            return getEQBands(for: "clarity")
        }
    }

    private func applyEQBand(to buffer: AVAudioPCMBuffer, sampleRate: Float, band: EQBand) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Calculate biquad coefficients based on filter type
        let coeffs = calculateBiquadCoefficients(
            type: band.type,
            frequency: band.frequency,
            gain: band.gain,
            q: band.q,
            sampleRate: sampleRate
        )

        // Apply filter to each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            var x1: Float = 0, x2: Float = 0  // Input history
            var y1: Float = 0, y2: Float = 0  // Output history

            for frame in 0..<frameCount {
                let x0 = samples[frame]

                // Biquad difference equation
                let y0 = coeffs.b0 * x0 + coeffs.b1 * x1 + coeffs.b2 * x2
                           - coeffs.a1 * y1 - coeffs.a2 * y2

                samples[frame] = y0

                // Update history
                x2 = x1
                x1 = x0
                y2 = y1
                y1 = y0
            }
        }
    }

    struct BiquadCoefficients {
        let b0, b1, b2: Float
        let a1, a2: Float
    }

    private func calculateBiquadCoefficients(
        type: EQBand.FilterType,
        frequency: Float,
        gain: Float,
        q: Float,
        sampleRate: Float
    ) -> BiquadCoefficients {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)
        let A = powf(10.0, gain / 40.0)

        switch type {
        case .lowShelf:
            let beta = sqrt(A) / q
            let b0 = A * ((A + 1) - (A - 1) * cosOmega + beta * sinOmega)
            let b1 = 2 * A * ((A - 1) - (A + 1) * cosOmega)
            let b2 = A * ((A + 1) - (A - 1) * cosOmega - beta * sinOmega)
            let a0 = (A + 1) + (A - 1) * cosOmega + beta * sinOmega
            let a1 = -2 * ((A - 1) + (A + 1) * cosOmega)
            let a2 = (A + 1) + (A - 1) * cosOmega - beta * sinOmega

            return BiquadCoefficients(
                b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
                a1: a1 / a0, a2: a2 / a0
            )

        case .highShelf:
            let beta = sqrt(A) / q
            let b0 = A * ((A + 1) + (A - 1) * cosOmega + beta * sinOmega)
            let b1 = -2 * A * ((A - 1) + (A + 1) * cosOmega)
            let b2 = A * ((A + 1) + (A - 1) * cosOmega - beta * sinOmega)
            let a0 = (A + 1) - (A - 1) * cosOmega + beta * sinOmega
            let a1 = 2 * ((A - 1) - (A + 1) * cosOmega)
            let a2 = (A + 1) - (A - 1) * cosOmega - beta * sinOmega

            return BiquadCoefficients(
                b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
                a1: a1 / a0, a2: a2 / a0
            )

        case .bell:
            let b0 = 1 + alpha * A
            let b1 = -2 * cosOmega
            let b2 = 1 - alpha * A
            let a0 = 1 + alpha / A
            let a1 = -2 * cosOmega
            let a2 = 1 - alpha / A

            return BiquadCoefficients(
                b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
                a1: a1 / a0, a2: a2 / a0
            )
        }
    }

    private func convertToM4A(from inputURL: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "VoiceEQProcessor", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "No audio track found"
            ])
        }

        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 192000
        ]

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(
            track: assetTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        reader.add(readerOutput)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        reader.startReading()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audio.conversion")) {
                while writerInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                        writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                    writerInput.append(sampleBuffer)
                }
            }
        }

        reader.cancelReading()
        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "VoiceEQProcessor", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Conversion failed"
            ])
        }
    }
}
