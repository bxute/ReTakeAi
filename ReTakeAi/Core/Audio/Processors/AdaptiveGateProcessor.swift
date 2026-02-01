//
//  AdaptiveGateProcessor.swift
//  ReTakeAi
//
//  Adaptive Gate - Suppresses background noise during speech pauses
//

import Foundation
import AVFoundation
import Accelerate

/// Adaptive Gate processor - suppresses background noise during pauses in speech
class AdaptiveGateProcessor: AudioProcessorProtocol {
    let id = "adaptiveGate"
    let name = "Adaptive Gate"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            "threshold": -40.0,     // dBFS
            "ratio": 10.0,          // 10:1 compression below threshold
            "attack": 5.0,          // ms
            "release": 50.0,        // ms
            "kneeWidth": 6.0        // dB
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let threshold = config["threshold"] as? Float ?? -40.0
        let ratio = config["ratio"] as? Float ?? 10.0
        let attackMs = config["attack"] as? Float ?? 5.0
        let releaseMs = config["release"] as? Float ?? 50.0
        let kneeWidth = config["kneeWidth"] as? Float ?? 6.0

        AppLogger.mediaProcessing.info("🎙️ AdaptiveGate: Starting processing")
        AppLogger.mediaProcessing.info("  Threshold: \(threshold) dBFS")
        AppLogger.mediaProcessing.info("  Ratio: \(ratio):1")
        AppLogger.mediaProcessing.info("  Attack: \(attackMs) ms")
        AppLogger.mediaProcessing.info("  Release: \(releaseMs) ms")
        AppLogger.mediaProcessing.info("  Knee Width: \(kneeWidth) dB")

        // Load audio file
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)

        AppLogger.mediaProcessing.info("  Sample Rate: \(format.sampleRate)")
        AppLogger.mediaProcessing.info("  Channels: \(format.channelCount)")

        // Read entire file into buffer
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AdaptiveGateProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        AppLogger.mediaProcessing.info("✅ Read \(frameCount) frames")

        // Apply gate
        AppLogger.mediaProcessing.info("🎛️ Applying adaptive gate...")
        applyGate(
            to: buffer,
            sampleRate: sampleRate,
            threshold: threshold,
            ratio: ratio,
            attackMs: attackMs,
            releaseMs: releaseMs,
            kneeWidth: kneeWidth
        )
        AppLogger.mediaProcessing.info("✅ Gate applied")

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

        AppLogger.mediaProcessing.info("✅ AdaptiveGate completed")
    }

    private func applyGate(
        to buffer: AVAudioPCMBuffer,
        sampleRate: Float,
        threshold: Float,
        ratio: Float,
        attackMs: Float,
        releaseMs: Float,
        kneeWidth: Float
    ) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Calculate envelope coefficients
        let attackCoeff = exp(-1.0 / (sampleRate * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseMs / 1000.0))

        // Convert threshold from dB to linear
        let thresholdLinear = powf(10.0, threshold / 20.0)
        let kneeStart = threshold - kneeWidth / 2.0
        let kneeEnd = threshold + kneeWidth / 2.0

        // Process each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            var envelope: Float = 0.0

            for frame in 0..<frameCount {
                let sample = samples[frame]
                let level = fabsf(sample)

                // Update envelope (RMS-like)
                let coeff = level > envelope ? attackCoeff : releaseCoeff
                envelope = coeff * envelope + (1.0 - coeff) * level

                // Convert envelope to dB
                let envelopeDb = envelope > 0.0 ? 20.0 * log10f(envelope) : -96.0

                // Calculate gain reduction
                var gainReduction: Float = 1.0

                if envelopeDb < kneeStart {
                    // Below knee - apply full ratio
                    let diff = envelopeDb - threshold
                    let reductionDb = diff * (1.0 - 1.0 / ratio)
                    gainReduction = powf(10.0, reductionDb / 20.0)
                } else if envelopeDb < kneeEnd {
                    // In knee - apply soft curve
                    let kneePosition = (envelopeDb - kneeStart) / kneeWidth
                    let diff = envelopeDb - threshold
                    let reductionDb = diff * (1.0 - 1.0 / ratio) * (1.0 - kneePosition)
                    gainReduction = powf(10.0, reductionDb / 20.0)
                }
                // Above knee - no reduction (gainReduction = 1.0)

                // Apply gain reduction
                samples[frame] = sample * gainReduction
            }
        }
    }

    private func convertToM4A(from inputURL: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "AdaptiveGateProcessor", code: -2, userInfo: [
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
            throw writer.error ?? NSError(domain: "AdaptiveGateProcessor", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Conversion failed"
            ])
        }
    }
}
