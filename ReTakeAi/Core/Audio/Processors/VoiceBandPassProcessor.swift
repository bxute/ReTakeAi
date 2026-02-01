//
//  VoiceBandPassProcessor.swift
//  ReTakeAi
//
//  Voice Band-Pass Filter - Isolates voice frequency range
//

import Foundation
import AVFoundation

/// Voice Band-Pass Filter processor - isolates voice frequencies (85-4000 Hz)
class VoiceBandPassProcessor: AudioProcessorProtocol {
    let id = "voiceBandPass"
    let name = "Voice Band-Pass"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            "lowCutoff": 85.0,     // Male voice fundamentals start here
            "highCutoff": 4000.0,  // Voice harmonics up to here
            "order": 2             // Filter order (1-4) - higher = steeper roll-off
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let lowCutoff = config["lowCutoff"] as? Float ?? 85.0
        let highCutoff = config["highCutoff"] as? Float ?? 4000.0
        let order = config["order"] as? Int ?? 2

        AppLogger.mediaProcessing.info("🎙️ VoiceBandPass: Starting processing")
        AppLogger.mediaProcessing.info("  Low Cutoff: \(lowCutoff) Hz")
        AppLogger.mediaProcessing.info("  High Cutoff: \(highCutoff) Hz")
        AppLogger.mediaProcessing.info("  Order: \(order)")

        // Load audio file
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)

        AppLogger.mediaProcessing.info("  Sample Rate: \(format.sampleRate)")
        AppLogger.mediaProcessing.info("  Channels: \(format.channelCount)")

        // Read entire file into buffer
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "VoiceBandPassProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        AppLogger.mediaProcessing.info("✅ Read \(frameCount) frames")

        // Apply cascaded high-pass filters (removes frequencies below lowCutoff)
        AppLogger.mediaProcessing.info("🎛️ Applying high-pass filter at \(lowCutoff) Hz...")
        for _ in 0..<order {
            applyHighPassFilter(to: buffer, sampleRate: sampleRate, cutoffFrequency: lowCutoff)
        }

        // Apply cascaded low-pass filters (removes frequencies above highCutoff)
        AppLogger.mediaProcessing.info("🎛️ Applying low-pass filter at \(highCutoff) Hz...")
        for _ in 0..<order {
            applyLowPassFilter(to: buffer, sampleRate: sampleRate, cutoffFrequency: highCutoff)
        }

        AppLogger.mediaProcessing.info("✅ Band-pass filter applied")

        // Write to CAF file (supports PCM float directly)
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

        AppLogger.mediaProcessing.info("✅ VoiceBandPass completed: \(lowCutoff)-\(highCutoff) Hz")
    }

    private func applyHighPassFilter(to buffer: AVAudioPCMBuffer, sampleRate: Float, cutoffFrequency: Float) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Calculate 1st order Butterworth HPF coefficients
        let omega = 2.0 * Float.pi * cutoffFrequency / sampleRate
        let alpha = 1.0 / (1.0 + omega)
        let b0 = alpha
        let b1 = -alpha
        let a1 = (1.0 - omega) / (1.0 + omega)

        // Apply filter to each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            var x1: Float = 0  // Previous input
            var y1: Float = 0  // Previous output

            for frame in 0..<frameCount {
                let x0 = samples[frame]
                let y0 = b0 * x0 + b1 * x1 - a1 * y1

                samples[frame] = y0

                x1 = x0
                y1 = y0
            }
        }
    }

    private func applyLowPassFilter(to buffer: AVAudioPCMBuffer, sampleRate: Float, cutoffFrequency: Float) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Calculate 1st order Butterworth LPF coefficients
        let omega = 2.0 * Float.pi * cutoffFrequency / sampleRate
        let alpha = omega / (1.0 + omega)
        let b0 = alpha
        let b1 = alpha
        let a1 = (1.0 - omega) / (1.0 + omega)

        // Apply filter to each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            var x1: Float = 0  // Previous input
            var y1: Float = 0  // Previous output

            for frame in 0..<frameCount {
                let x0 = samples[frame]
                let y0 = b0 * x0 + b1 * x1 - a1 * y1

                samples[frame] = y0

                x1 = x0
                y1 = y0
            }
        }
    }

    private func convertToM4A(from inputURL: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "VoiceBandPassProcessor", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "No audio track found"
            ])
        }

        // Remove existing output file
        try? FileManager.default.removeItem(at: outputURL)

        // Create asset writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)

        // Configure AAC output
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 192000
        ]

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // Create asset reader
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

        // Start reading and writing
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
            throw writer.error ?? NSError(domain: "VoiceBandPassProcessor", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Conversion failed"
            ])
        }
    }
}
