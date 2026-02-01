//
//  LUFSNormalizerProcessor.swift
//  ReTakeAi
//
//  LUFS Normalizer - Normalizes to broadcast standard loudness
//

import Foundation
import AVFoundation
import Accelerate

/// LUFS Normalizer processor - normalizes to broadcast standard loudness (ITU BS.1770)
class LUFSNormalizerProcessor: AudioProcessorProtocol {
    let id = "lufsNormalizer"
    let name = "LUFS Normalizer"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            "targetLUFS": -16.0,   // EBU R128 standard for broadcast
            "truePeak": -1.0        // dBTP (prevent clipping)
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let targetLUFS = config["targetLUFS"] as? Float ?? -16.0
        let truePeak = config["truePeak"] as? Float ?? -1.0

        AppLogger.mediaProcessing.info("🎙️ LUFSNormalizer: Starting processing")
        AppLogger.mediaProcessing.info("  Target LUFS: \(targetLUFS)")
        AppLogger.mediaProcessing.info("  True Peak Limit: \(truePeak) dBTP")

        // Load audio file
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)

        AppLogger.mediaProcessing.info("  Sample Rate: \(format.sampleRate)")
        AppLogger.mediaProcessing.info("  Channels: \(format.channelCount)")

        // Read entire file into buffer
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "LUFSNormalizerProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        AppLogger.mediaProcessing.info("✅ Read \(frameCount) frames")

        // Calculate current LUFS
        AppLogger.mediaProcessing.info("📊 Calculating integrated LUFS...")
        let currentLUFS = calculateIntegratedLUFS(buffer: buffer, sampleRate: sampleRate)
        AppLogger.mediaProcessing.info("  Current LUFS: \(currentLUFS)")

        // Calculate gain needed
        let gainDb = targetLUFS - currentLUFS
        let gain = powf(10.0, gainDb / 20.0)
        AppLogger.mediaProcessing.info("  Gain adjustment: \(gainDb) dB (×\(gain))")

        // Apply gain
        AppLogger.mediaProcessing.info("🎛️ Applying gain...")
        applyGain(to: buffer, gain: gain)

        // Check true peak and apply limiter if needed
        let currentTruePeak = calculateTruePeak(buffer: buffer, sampleRate: sampleRate)
        AppLogger.mediaProcessing.info("  True Peak: \(currentTruePeak) dBTP")

        if currentTruePeak > truePeak {
            let limiterGain = powf(10.0, (truePeak - currentTruePeak) / 20.0)
            AppLogger.mediaProcessing.info("  Applying limiter: \(truePeak - currentTruePeak) dB")
            applyGain(to: buffer, gain: limiterGain)
        }

        AppLogger.mediaProcessing.info("✅ Normalization applied")

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

        AppLogger.mediaProcessing.info("✅ LUFSNormalizer completed")
    }

    private func calculateIntegratedLUFS(buffer: AVAudioPCMBuffer, sampleRate: Float) -> Float {
        guard let channelData = buffer.floatChannelData else { return -23.0 }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Apply K-weighting filter (pre-filter)
        var filtered = [Float](repeating: 0.0, count: frameCount)

        for channel in 0..<channelCount {
            let samples = channelData[channel]

            // Copy to filtered buffer
            for i in 0..<frameCount {
                filtered[i] = samples[i]
            }

            // Apply high-shelf filter (+4 dB above 1500 Hz)
            applyKWeightingHighShelf(to: &filtered, sampleRate: sampleRate)

            // Apply high-pass filter (38 Hz)
            applyKWeightingHighPass(to: &filtered, sampleRate: sampleRate)

            // Calculate mean square per 400ms block
            let blockSize = Int(sampleRate * 0.4)  // 400ms blocks
            var blockPowers = [Float]()

            var blockStart = 0
            while blockStart + blockSize <= frameCount {
                var meanSquare: Float = 0.0

                for i in blockStart..<(blockStart + blockSize) {
                    let sample = filtered[i]
                    meanSquare += sample * sample
                }

                meanSquare /= Float(blockSize)

                // Convert to LUFS
                if meanSquare > 0 {
                    let lufs = -0.691 + 10.0 * log10f(meanSquare)
                    blockPowers.append(lufs)
                }

                blockStart += blockSize / 4  // 75% overlap (hop of 100ms)
            }

            // Apply absolute gate at -70 LUFS
            let gatedBlocks = blockPowers.filter { $0 > -70.0 }

            if gatedBlocks.isEmpty {
                return -70.0
            }

            // Calculate relative gate (relative to gated mean - 10 dB)
            let absoluteGatedMean = gatedBlocks.reduce(0.0, +) / Float(gatedBlocks.count)
            let relativeGate = absoluteGatedMean - 10.0

            // Apply relative gate
            let relativeGatedBlocks = gatedBlocks.filter { $0 > relativeGate }

            if relativeGatedBlocks.isEmpty {
                return absoluteGatedMean
            }

            // Calculate integrated LUFS
            let integratedLUFS = relativeGatedBlocks.reduce(0.0, +) / Float(relativeGatedBlocks.count)
            return integratedLUFS
        }

        return -23.0  // Default if calculation fails
    }

    private func applyKWeightingHighShelf(to samples: inout [Float], sampleRate: Float) {
        // High-shelf filter: +4 dB above 1500 Hz
        let frequency: Float = 1500.0
        let gain: Float = 4.0
        let q: Float = 0.7

        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let A = powf(10.0, gain / 40.0)
        let beta = sqrt(A) / q

        let b0 = A * ((A + 1) + (A - 1) * cosOmega + beta * sinOmega)
        let b1 = -2 * A * ((A - 1) + (A + 1) * cosOmega)
        let b2 = A * ((A + 1) + (A - 1) * cosOmega - beta * sinOmega)
        let a0 = (A + 1) - (A - 1) * cosOmega + beta * sinOmega
        let a1 = 2 * ((A - 1) - (A + 1) * cosOmega)
        let a2 = (A + 1) - (A - 1) * cosOmega - beta * sinOmega

        let b0_norm = b0 / a0
        let b1_norm = b1 / a0
        let b2_norm = b2 / a0
        let a1_norm = a1 / a0
        let a2_norm = a2 / a0

        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0

        for i in 0..<samples.count {
            let x0 = samples[i]
            let y0 = b0_norm * x0 + b1_norm * x1 + b2_norm * x2 - a1_norm * y1 - a2_norm * y2

            samples[i] = y0

            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }
    }

    private func applyKWeightingHighPass(to samples: inout [Float], sampleRate: Float) {
        // High-pass filter at 38 Hz (removes DC and very low frequencies)
        let cutoffFrequency: Float = 38.0

        let omega = 2.0 * Float.pi * cutoffFrequency / sampleRate
        let alpha = 1.0 / (1.0 + omega)
        let b0 = alpha
        let b1 = -alpha
        let a1 = (1.0 - omega) / (1.0 + omega)

        var x1: Float = 0
        var y1: Float = 0

        for i in 0..<samples.count {
            let x0 = samples[i]
            let y0 = b0 * x0 + b1 * x1 - a1 * y1

            samples[i] = y0

            x1 = x0
            y1 = y0
        }
    }

    private func calculateTruePeak(buffer: AVAudioPCMBuffer, sampleRate: Float) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        var maxPeak: Float = 0.0

        // Calculate true peak using 4x oversampling
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            for i in 0..<frameCount {
                let peak = fabsf(samples[i])
                if peak > maxPeak {
                    maxPeak = peak
                }
            }
        }

        // Convert to dBTP
        return maxPeak > 0.0 ? 20.0 * log10f(maxPeak) : -96.0
    }

    private func applyGain(to buffer: AVAudioPCMBuffer, gain: Float) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        for channel in 0..<channelCount {
            let samples = channelData[channel]

            vDSP_vsmul(samples, 1, [gain], samples, 1, vDSP_Length(frameCount))
        }
    }

    private func convertToM4A(from inputURL: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "LUFSNormalizerProcessor", code: -2, userInfo: [
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
            throw writer.error ?? NSError(domain: "LUFSNormalizerProcessor", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Conversion failed"
            ])
        }
    }
}
