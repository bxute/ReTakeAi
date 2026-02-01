//
//  DeEsserProcessor.swift
//  ReTakeAi
//
//  De-Esser - Reduces harsh sibilance (S, T, Ch sounds)
//

import Foundation
import AVFoundation
import Accelerate

/// De-Esser processor - reduces harsh sibilance using split-band compression
class DeEsserProcessor: AudioProcessorProtocol {
    let id = "deEsser"
    let name = "De-Esser"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            "frequency": 7000.0,    // Center frequency for sibilance detection
            "threshold": -15.0,     // dBFS
            "ratio": 4.0,           // Compression ratio
            "bandwidth": 4000.0     // Hz (5000-9000 Hz range)
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let frequency = config["frequency"] as? Float ?? 7000.0
        let threshold = config["threshold"] as? Float ?? -15.0
        let ratio = config["ratio"] as? Float ?? 4.0
        let bandwidth = config["bandwidth"] as? Float ?? 4000.0

        let lowFreq = frequency - bandwidth / 2
        let highFreq = frequency + bandwidth / 2

        AppLogger.mediaProcessing.info("🎙️ DeEsser: Starting processing")
        AppLogger.mediaProcessing.info("  Sibilance Range: \(lowFreq)-\(highFreq) Hz")
        AppLogger.mediaProcessing.info("  Threshold: \(threshold) dBFS")
        AppLogger.mediaProcessing.info("  Ratio: \(ratio):1")

        // Load audio file
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)

        AppLogger.mediaProcessing.info("  Sample Rate: \(format.sampleRate)")
        AppLogger.mediaProcessing.info("  Channels: \(format.channelCount)")

        // Read entire file into buffer
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "DeEsserProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        AppLogger.mediaProcessing.info("✅ Read \(frameCount) frames")

        // Apply de-esser
        AppLogger.mediaProcessing.info("🎛️ Applying de-esser...")
        applyDeEsser(
            to: buffer,
            sampleRate: sampleRate,
            lowFreq: lowFreq,
            highFreq: highFreq,
            threshold: threshold,
            ratio: ratio
        )
        AppLogger.mediaProcessing.info("✅ De-esser applied")

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

        AppLogger.mediaProcessing.info("✅ DeEsser completed")
    }

    private func applyDeEsser(
        to buffer: AVAudioPCMBuffer,
        sampleRate: Float,
        lowFreq: Float,
        highFreq: Float,
        threshold: Float,
        ratio: Float
    ) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Create buffers for split bands
        var sibilanceBand = [Float](repeating: 0.0, count: frameCount)
        var mainBand = [Float](repeating: 0.0, count: frameCount)

        // Process each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            // Split into sibilance band (5-9 kHz) and main band
            splitBands(
                input: samples,
                frameCount: frameCount,
                sampleRate: sampleRate,
                lowFreq: lowFreq,
                highFreq: highFreq,
                sibilanceBand: &sibilanceBand,
                mainBand: &mainBand
            )

            // Apply compression to sibilance band only
            compressSibilance(
                band: &sibilanceBand,
                frameCount: frameCount,
                threshold: threshold,
                ratio: ratio,
                sampleRate: sampleRate
            )

            // Sum bands back together
            for i in 0..<frameCount {
                samples[i] = mainBand[i] + sibilanceBand[i]
            }
        }
    }

    private func splitBands(
        input: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Float,
        lowFreq: Float,
        highFreq: Float,
        sibilanceBand: inout [Float],
        mainBand: inout [Float]
    ) {
        // Copy input to both bands
        for i in 0..<frameCount {
            sibilanceBand[i] = input[i]
            mainBand[i] = input[i]
        }

        // Apply band-pass filter to sibilanceBand (keeps only sibilant frequencies)
        applyHighPassFilter(to: &sibilanceBand, sampleRate: sampleRate, cutoffFrequency: lowFreq, order: 2)
        applyLowPassFilter(to: &sibilanceBand, sampleRate: sampleRate, cutoffFrequency: highFreq, order: 2)

        // Subtract sibilance band from main band to get everything else
        for i in 0..<frameCount {
            mainBand[i] -= sibilanceBand[i]
        }
    }

    private func applyLowPassFilter(to samples: inout [Float], sampleRate: Float, cutoffFrequency: Float, order: Int) {
        let frameCount = samples.count

        let omega = 2.0 * Float.pi * cutoffFrequency / sampleRate
        let alpha = omega / (1.0 + omega)
        let b0 = alpha
        let b1 = alpha
        let a1 = (1.0 - omega) / (1.0 + omega)

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

        let omega = 2.0 * Float.pi * cutoffFrequency / sampleRate
        let alpha = 1.0 / (1.0 + omega)
        let b0 = alpha
        let b1 = -alpha
        let a1 = (1.0 - omega) / (1.0 + omega)

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

    private func compressSibilance(
        band: inout [Float],
        frameCount: Int,
        threshold: Float,
        ratio: Float,
        sampleRate: Float
    ) {
        // Fast attack, slow release for de-essing
        let attackMs: Float = 1.0
        let releaseMs: Float = 50.0

        let attackCoeff = exp(-1.0 / (sampleRate * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseMs / 1000.0))
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
            throw NSError(domain: "DeEsserProcessor", code: -2, userInfo: [
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
            throw writer.error ?? NSError(domain: "DeEsserProcessor", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Conversion failed"
            ])
        }
    }
}
