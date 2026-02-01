//
//  MultiBandCompressorProcessor.swift
//  ReTakeAi
//
//  Multi-Band Compressor - Controls dynamics independently across frequency bands
//

import Foundation
import AVFoundation
import Accelerate

/// Multi-Band Compressor processor - controls dynamics independently across 3 frequency bands
class MultiBandCompressorProcessor: AudioProcessorProtocol {
    let id = "multiBandCompressor"
    let name = "Multi-Band Compressor"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            // Low band (20-200 Hz): Light compression
            "lowThreshold": -20.0,
            "lowRatio": 2.0,

            // Mid band (200-2000 Hz): Moderate compression (voice fundamentals)
            "midThreshold": -15.0,
            "midRatio": 3.0,

            // High band (2000-20000 Hz): Aggressive compression (sibilance control)
            "highThreshold": -12.0,
            "highRatio": 4.0,

            "attack": 5.0,    // ms
            "release": 100.0  // ms
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let lowThreshold = config["lowThreshold"] as? Float ?? -20.0
        let lowRatio = config["lowRatio"] as? Float ?? 2.0
        let midThreshold = config["midThreshold"] as? Float ?? -15.0
        let midRatio = config["midRatio"] as? Float ?? 3.0
        let highThreshold = config["highThreshold"] as? Float ?? -12.0
        let highRatio = config["highRatio"] as? Float ?? 4.0
        let attackMs = config["attack"] as? Float ?? 5.0
        let releaseMs = config["release"] as? Float ?? 100.0

        AppLogger.mediaProcessing.info("🎙️ MultiBandCompressor: Starting processing")
        AppLogger.mediaProcessing.info("  Low Band: \(lowThreshold) dB, \(lowRatio):1")
        AppLogger.mediaProcessing.info("  Mid Band: \(midThreshold) dB, \(midRatio):1")
        AppLogger.mediaProcessing.info("  High Band: \(highThreshold) dB, \(highRatio):1")

        // Load audio file
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)

        AppLogger.mediaProcessing.info("  Sample Rate: \(format.sampleRate)")
        AppLogger.mediaProcessing.info("  Channels: \(format.channelCount)")

        // Read entire file into buffer
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "MultiBandCompressorProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        AppLogger.mediaProcessing.info("✅ Read \(frameCount) frames")

        // Apply multi-band compression
        AppLogger.mediaProcessing.info("🎛️ Applying multi-band compression...")
        applyMultiBandCompression(
            to: buffer,
            sampleRate: sampleRate,
            lowThreshold: lowThreshold,
            lowRatio: lowRatio,
            midThreshold: midThreshold,
            midRatio: midRatio,
            highThreshold: highThreshold,
            highRatio: highRatio,
            attackMs: attackMs,
            releaseMs: releaseMs
        )
        AppLogger.mediaProcessing.info("✅ Multi-band compression applied")

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

        AppLogger.mediaProcessing.info("✅ MultiBandCompressor completed")
    }

    private func applyMultiBandCompression(
        to buffer: AVAudioPCMBuffer,
        sampleRate: Float,
        lowThreshold: Float,
        lowRatio: Float,
        midThreshold: Float,
        midRatio: Float,
        highThreshold: Float,
        highRatio: Float,
        attackMs: Float,
        releaseMs: Float
    ) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Create buffers for each band
        var lowBand = [Float](repeating: 0.0, count: frameCount)
        var midBand = [Float](repeating: 0.0, count: frameCount)
        var highBand = [Float](repeating: 0.0, count: frameCount)

        // Process each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            // Split into 3 bands using Linkwitz-Riley crossovers at 200 Hz and 2000 Hz
            splitIntoBands(
                input: samples,
                frameCount: frameCount,
                sampleRate: sampleRate,
                lowCrossover: 200.0,
                highCrossover: 2000.0,
                lowBand: &lowBand,
                midBand: &midBand,
                highBand: &highBand
            )

            // Apply compression to each band
            compressBand(
                band: &lowBand,
                frameCount: frameCount,
                threshold: lowThreshold,
                ratio: lowRatio,
                attackMs: attackMs,
                releaseMs: releaseMs,
                sampleRate: sampleRate
            )

            compressBand(
                band: &midBand,
                frameCount: frameCount,
                threshold: midThreshold,
                ratio: midRatio,
                attackMs: attackMs,
                releaseMs: releaseMs,
                sampleRate: sampleRate
            )

            compressBand(
                band: &highBand,
                frameCount: frameCount,
                threshold: highThreshold,
                ratio: highRatio,
                attackMs: attackMs,
                releaseMs: releaseMs,
                sampleRate: sampleRate
            )

            // Sum bands back together
            for i in 0..<frameCount {
                samples[i] = lowBand[i] + midBand[i] + highBand[i]
            }
        }
    }

    private func splitIntoBands(
        input: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Float,
        lowCrossover: Float,
        highCrossover: Float,
        lowBand: inout [Float],
        midBand: inout [Float],
        highBand: inout [Float]
    ) {
        // Copy input to all bands initially
        for i in 0..<frameCount {
            lowBand[i] = input[i]
            midBand[i] = input[i]
            highBand[i] = input[i]
        }

        // Apply low-pass filter at lowCrossover to lowBand (keeps frequencies below 200 Hz)
        applyLowPassFilter(to: &lowBand, sampleRate: sampleRate, cutoffFrequency: lowCrossover, order: 2)

        // Apply band-pass filter to midBand (keeps 200-2000 Hz)
        applyHighPassFilter(to: &midBand, sampleRate: sampleRate, cutoffFrequency: lowCrossover, order: 2)
        applyLowPassFilter(to: &midBand, sampleRate: sampleRate, cutoffFrequency: highCrossover, order: 2)

        // Apply high-pass filter at highCrossover to highBand (keeps frequencies above 2000 Hz)
        applyHighPassFilter(to: &highBand, sampleRate: sampleRate, cutoffFrequency: highCrossover, order: 2)
    }

    private func applyLowPassFilter(to samples: inout [Float], sampleRate: Float, cutoffFrequency: Float, order: Int) {
        let frameCount = samples.count

        // Calculate 1st order Butterworth LPF coefficients
        let omega = 2.0 * Float.pi * cutoffFrequency / sampleRate
        let alpha = omega / (1.0 + omega)
        let b0 = alpha
        let b1 = alpha
        let a1 = (1.0 - omega) / (1.0 + omega)

        // Apply filter multiple times for higher order
        for _ in 0..<order {
            var x1: Float = 0
            var y1: Float = 0

            for i in 0..<frameCount {
                let x0 = samples[i]
                let y0 = b0 * x0 + b1 * x1 - a1 * y1

                samples[i] = y0

                x1 = x0
                y1 = y0
            }
        }
    }

    private func applyHighPassFilter(to samples: inout [Float], sampleRate: Float, cutoffFrequency: Float, order: Int) {
        let frameCount = samples.count

        // Calculate 1st order Butterworth HPF coefficients
        let omega = 2.0 * Float.pi * cutoffFrequency / sampleRate
        let alpha = 1.0 / (1.0 + omega)
        let b0 = alpha
        let b1 = -alpha
        let a1 = (1.0 - omega) / (1.0 + omega)

        // Apply filter multiple times for higher order
        for _ in 0..<order {
            var x1: Float = 0
            var y1: Float = 0

            for i in 0..<frameCount {
                let x0 = samples[i]
                let y0 = b0 * x0 + b1 * x1 - a1 * y1

                samples[i] = y0

                x1 = x0
                y1 = y0
            }
        }
    }

    private func compressBand(
        band: inout [Float],
        frameCount: Int,
        threshold: Float,
        ratio: Float,
        attackMs: Float,
        releaseMs: Float,
        sampleRate: Float
    ) {
        // Calculate envelope coefficients
        let attackCoeff = exp(-1.0 / (sampleRate * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseMs / 1000.0))

        // Convert threshold from dB to linear
        let thresholdLinear = powf(10.0, threshold / 20.0)

        var envelope: Float = 0.0

        for i in 0..<frameCount {
            let level = fabsf(band[i])

            // Update envelope
            let coeff = level > envelope ? attackCoeff : releaseCoeff
            envelope = coeff * envelope + (1.0 - coeff) * level

            // Calculate gain reduction
            var gain: Float = 1.0
            if envelope > thresholdLinear {
                let envelopeDb = 20.0 * log10f(envelope)
                let diff = envelopeDb - threshold
                let reductionDb = diff * (1.0 - 1.0 / ratio)
                gain = powf(10.0, -reductionDb / 20.0)
            }

            // Apply compression
            band[i] *= gain
        }
    }

    private func convertToM4A(from inputURL: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "MultiBandCompressorProcessor", code: -2, userInfo: [
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
            throw writer.error ?? NSError(domain: "MultiBandCompressorProcessor", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Conversion failed"
            ])
        }
    }
}
