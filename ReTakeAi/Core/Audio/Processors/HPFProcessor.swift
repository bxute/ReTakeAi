//
//  HPFProcessor.swift
//  ReTakeAi
//
//  High-Pass Filter at 90 Hz to remove low-frequency rumble
//

import Foundation
import AVFoundation
import Accelerate

/// High-Pass Filter processor - removes frequencies below cutoff
class HPFProcessor: AudioProcessorProtocol {
    let id = "hpf"
    let name = "High-Pass Filter"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            "cutoffFrequency": 70.0,  // Default 70 Hz - safe for all voices
            "makeupGain": 4.5         // +4.5 dB makeup gain to compensate for filter loss
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let cutoffFrequency = config["cutoffFrequency"] as? Float ?? 90.0
        let makeupGain = config["makeupGain"] as? Float ?? 4.5

        AppLogger.mediaProcessing.info("🎙️ HPF: Starting processing")
        AppLogger.mediaProcessing.info("  Input: \(inputURL.lastPathComponent)")
        AppLogger.mediaProcessing.info("  Input Full Path: \(inputURL.path)")
        AppLogger.mediaProcessing.info("  Output: \(outputURL.lastPathComponent)")
        AppLogger.mediaProcessing.info("  Output Full Path: \(outputURL.path)")
        AppLogger.mediaProcessing.info("  Cutoff: \(cutoffFrequency) Hz")
        AppLogger.mediaProcessing.info("  Makeup Gain: +\(makeupGain) dB")

        // Check if input file exists
        let fileExists = FileManager.default.fileExists(atPath: inputURL.path)
        AppLogger.mediaProcessing.info("  File exists: \(fileExists)")

        if fileExists {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: inputURL.path)
                let fileSize = (attributes[.size] as? NSNumber)?.stringValue ?? "unknown"
                let fileType = (attributes[.type] as? String) ?? "unknown"
                AppLogger.mediaProcessing.info("  File size: \(fileSize)")
                AppLogger.mediaProcessing.info("  File type: \(fileType)")
            } catch {
                AppLogger.mediaProcessing.error("  Could not read file attributes: \(error)")
            }
        }

        // Load audio file
        AppLogger.mediaProcessing.info("📂 HPF: Loading audio file...")
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)

        AppLogger.mediaProcessing.info("  Sample Rate: \(format.sampleRate)")
        AppLogger.mediaProcessing.info("  Channels: \(format.channelCount)")
        AppLogger.mediaProcessing.info("  Common Format: \(format.commonFormat.rawValue)")
        AppLogger.mediaProcessing.info("  Length: \(audioFile.length) frames")

        // Read entire file into buffer
        AppLogger.mediaProcessing.info("📥 HPF: Reading audio into buffer...")
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "HPFProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        AppLogger.mediaProcessing.info("✅ HPF: Read \(frameCount) frames")

        // Apply HPF
        AppLogger.mediaProcessing.info("🎛️ HPF: Applying filter...")
        applyFilter(to: buffer, sampleRate: sampleRate, cutoffFrequency: cutoffFrequency)
        AppLogger.mediaProcessing.info("✅ HPF: Filter applied")

        // Apply makeup gain to compensate for filter loss
        if makeupGain != 0.0 {
            AppLogger.mediaProcessing.info("🔊 HPF: Applying makeup gain (+\(makeupGain) dB)...")
            applyMakeupGain(to: buffer, gainDb: makeupGain)
            AppLogger.mediaProcessing.info("✅ HPF: Makeup gain applied")
        }

        // Create output settings for PCM (CAF format)
        AppLogger.mediaProcessing.info("💾 HPF: Creating output file...")
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        // Write to CAF file (supports PCM float directly)
        let cafURL = outputURL.deletingPathExtension().appendingPathExtension("caf")
        AppLogger.mediaProcessing.info("  CAF URL: \(cafURL.path)")
        AppLogger.mediaProcessing.info("  Settings: \(outputSettings)")

        // Remove if exists
        try? FileManager.default.removeItem(at: cafURL)

        AppLogger.mediaProcessing.info("📝 HPF: Creating AVAudioFile for writing...")
        let outputFile = try AVAudioFile(
            forWriting: cafURL,
            settings: outputSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        AppLogger.mediaProcessing.info("✅ HPF: AVAudioFile created")

        AppLogger.mediaProcessing.info("💾 HPF: Writing buffer to file...")
        try outputFile.write(from: buffer)
        AppLogger.mediaProcessing.info("✅ HPF: Buffer written (\(buffer.frameLength) frames)")

        // Convert CAF to M4A if needed
        if outputURL.pathExtension.lowercased() == "m4a" {
            AppLogger.mediaProcessing.info("🔄 HPF: Converting CAF to M4A...")
            try await convertToM4A(from: cafURL, to: outputURL)
            AppLogger.mediaProcessing.info("✅ HPF: Conversion complete")
            try? FileManager.default.removeItem(at: cafURL)
        } else {
            // If output is already CAF, just rename
            AppLogger.mediaProcessing.info("📦 HPF: Moving CAF to output location...")
            try? FileManager.default.removeItem(at: outputURL)
            try FileManager.default.moveItem(at: cafURL, to: outputURL)
        }

        AppLogger.mediaProcessing.info("✅ HPF completed: \(cutoffFrequency) Hz")
    }

    private func convertToM4A(from inputURL: URL, to outputURL: URL) async throws {
        AppLogger.mediaProcessing.info("  📥 Loading asset from CAF...")
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "HPFProcessor", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "No audio track found"
            ])
        }
        AppLogger.mediaProcessing.info("  ✅ Asset track loaded")

        // Remove existing output file
        try? FileManager.default.removeItem(at: outputURL)

        // Create asset writer
        AppLogger.mediaProcessing.info("  📝 Creating AVAssetWriter...")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        AppLogger.mediaProcessing.info("  ✅ AVAssetWriter created")

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
        AppLogger.mediaProcessing.info("  ✅ Writer input added")

        // Create asset reader
        AppLogger.mediaProcessing.info("  📖 Creating AVAssetReader...")
        let reader = try AVAssetReader(asset: asset)
        AppLogger.mediaProcessing.info("  ✅ AVAssetReader created")
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
        AppLogger.mediaProcessing.info("  ✅ Reader output added")

        // Start reading and writing
        AppLogger.mediaProcessing.info("  ▶️ Starting writer...")
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        AppLogger.mediaProcessing.info("  ▶️ Starting reader...")
        reader.startReading()
        AppLogger.mediaProcessing.info("  🔄 Transcoding samples...")

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

        AppLogger.mediaProcessing.info("  🛑 Cancelling reader...")
        reader.cancelReading()
        AppLogger.mediaProcessing.info("  ⏹️ Finishing writer...")
        await writer.finishWriting()

        if writer.status == .failed {
            AppLogger.mediaProcessing.error("  ❌ Writer failed: \(writer.error?.localizedDescription ?? "Unknown error")")
            throw writer.error ?? NSError(domain: "HPFProcessor", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Conversion failed"
            ])
        }
        AppLogger.mediaProcessing.info("  ✅ Transcoding complete")
    }

    private func applyFilter(to buffer: AVAudioPCMBuffer, sampleRate: Float, cutoffFrequency: Float) {
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

    private func applyMakeupGain(to buffer: AVAudioPCMBuffer, gainDb: Float) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Convert dB to linear gain
        let linearGain = powf(10.0, gainDb / 20.0)

        // Apply gain to each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            vDSP_vsmul(samples, 1, [linearGain], samples, 1, vDSP_Length(frameCount))
        }
    }
}
