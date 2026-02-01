//
//  SpectralNoiseReductionProcessor.swift
//  ReTakeAi
//
//  Spectral Noise Reduction - Removes constant background noise
//

import Foundation
import AVFoundation
import Accelerate

/// Spectral Noise Reduction processor - removes constant background noise using spectral subtraction
class SpectralNoiseReductionProcessor: AudioProcessorProtocol {
    let id = "spectralNoiseReduction"
    let name = "Spectral Noise Reduction"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            "noiseProfileDuration": 0.5,  // Seconds of initial audio for noise profile
            "reductionAmount": 12.0,       // dB of reduction
            "smoothingFactor": 0.7         // 0-1, prevents musical artifacts
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let noiseProfileDuration = config["noiseProfileDuration"] as? Float ?? 0.5
        let reductionAmount = config["reductionAmount"] as? Float ?? 12.0
        let smoothingFactor = config["smoothingFactor"] as? Float ?? 0.7

        AppLogger.mediaProcessing.info("🎙️ SpectralNoiseReduction: Starting processing")
        AppLogger.mediaProcessing.info("  Noise Profile Duration: \(noiseProfileDuration)s")
        AppLogger.mediaProcessing.info("  Reduction Amount: \(reductionAmount) dB")
        AppLogger.mediaProcessing.info("  Smoothing Factor: \(smoothingFactor)")

        // Load audio file
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)

        AppLogger.mediaProcessing.info("  Sample Rate: \(format.sampleRate)")
        AppLogger.mediaProcessing.info("  Channels: \(format.channelCount)")

        // Read entire file into buffer
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SpectralNoiseReductionProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        AppLogger.mediaProcessing.info("✅ Read \(frameCount) frames")

        // Apply noise reduction
        AppLogger.mediaProcessing.info("🎛️ Analyzing noise profile...")
        try applyNoiseReduction(
            to: buffer,
            sampleRate: sampleRate,
            noiseProfileDuration: noiseProfileDuration,
            reductionAmount: reductionAmount,
            smoothingFactor: smoothingFactor
        )
        AppLogger.mediaProcessing.info("✅ Noise reduction applied")

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

        AppLogger.mediaProcessing.info("✅ SpectralNoiseReduction completed")
    }

    private func applyNoiseReduction(
        to buffer: AVAudioPCMBuffer,
        sampleRate: Float,
        noiseProfileDuration: Float,
        reductionAmount: Float,
        smoothingFactor: Float
    ) throws {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let totalFrames = Int(buffer.frameLength)

        // FFT parameters
        let fftSize = 2048
        let hopSize = fftSize / 4
        let log2n = vDSP_Length(round(log2(Double(fftSize))))

        // Create FFT setup
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw NSError(domain: "SpectralNoiseReductionProcessor", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create FFT setup"
            ])
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Process each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            // Calculate noise profile from initial audio
            let noiseProfileFrames = Int(noiseProfileDuration * sampleRate)
            let noiseProfile = calculateNoiseProfile(
                samples: samples,
                frameCount: min(noiseProfileFrames, totalFrames),
                fftSize: fftSize,
                hopSize: hopSize,
                fftSetup: fftSetup,
                log2n: log2n
            )

            // Apply noise reduction to entire audio
            processWithNoiseProfile(
                samples: samples,
                totalFrames: totalFrames,
                fftSize: fftSize,
                hopSize: hopSize,
                fftSetup: fftSetup,
                log2n: log2n,
                noiseProfile: noiseProfile,
                reductionAmount: reductionAmount,
                smoothingFactor: smoothingFactor
            )
        }
    }

    private func calculateNoiseProfile(
        samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        fftSize: Int,
        hopSize: Int,
        fftSetup: FFTSetup,
        log2n: vDSP_Length
    ) -> [Float] {
        let binCount = fftSize / 2
        var noiseProfile = [Float](repeating: 0.0, count: binCount)
        var profileCount = 0

        var window = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var realp = [Float](repeating: 0.0, count: binCount)
        var imagp = [Float](repeating: 0.0, count: binCount)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

        var frame = [Float](repeating: 0.0, count: fftSize)
        var magnitude = [Float](repeating: 0.0, count: binCount)

        var position = 0
        while position + fftSize <= frameCount {
            // Copy frame
            memcpy(&frame, samples + position, fftSize * MemoryLayout<Float>.size)

            // Apply window
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))

            // Perform FFT
            frame.withUnsafeBytes { ptr in
                ptr.baseAddress!.assumingMemoryBound(to: DSPComplex.self).withMemoryRebound(to: Float.self, capacity: fftSize) { floatPtr in
                    vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(floatPtr)), 2, &splitComplex, 1, vDSP_Length(binCount))
                }
            }
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            // Calculate magnitude
            vDSP_zvmags(&splitComplex, 1, &magnitude, 1, vDSP_Length(binCount))

            // Accumulate to noise profile
            vDSP_vadd(noiseProfile, 1, magnitude, 1, &noiseProfile, 1, vDSP_Length(binCount))
            profileCount += 1

            position += hopSize
        }

        // Average the noise profile
        if profileCount > 0 {
            var divisor = Float(profileCount)
            vDSP_vsdiv(noiseProfile, 1, &divisor, &noiseProfile, 1, vDSP_Length(binCount))
        }

        return noiseProfile
    }

    private func processWithNoiseProfile(
        samples: UnsafeMutablePointer<Float>,
        totalFrames: Int,
        fftSize: Int,
        hopSize: Int,
        fftSetup: FFTSetup,
        log2n: vDSP_Length,
        noiseProfile: [Float],
        reductionAmount: Float,
        smoothingFactor: Float
    ) {
        let binCount = fftSize / 2

        var window = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var realp = [Float](repeating: 0.0, count: binCount)
        var imagp = [Float](repeating: 0.0, count: binCount)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

        var frame = [Float](repeating: 0.0, count: fftSize)
        var magnitude = [Float](repeating: 0.0, count: binCount)
        var phase = [Float](repeating: 0.0, count: binCount)
        var gain = [Float](repeating: 0.0, count: binCount)
        var smoothedGain = [Float](repeating: 1.0, count: binCount)

        var output = [Float](repeating: 0.0, count: totalFrames)

        let reductionFactor = powf(10.0, -reductionAmount / 20.0)

        var position = 0
        while position + fftSize <= totalFrames {
            // Copy frame
            memcpy(&frame, samples + position, fftSize * MemoryLayout<Float>.size)

            // Apply window
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))

            // Perform FFT
            frame.withUnsafeBytes { ptr in
                ptr.baseAddress!.assumingMemoryBound(to: DSPComplex.self).withMemoryRebound(to: Float.self, capacity: fftSize) { floatPtr in
                    vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(floatPtr)), 2, &splitComplex, 1, vDSP_Length(binCount))
                }
            }
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            // Calculate magnitude and phase
            vDSP_zvmags(&splitComplex, 1, &magnitude, 1, vDSP_Length(binCount))
            vDSP_zvphas(&splitComplex, 1, &phase, 1, vDSP_Length(binCount))

            // Calculate gain per bin (spectral subtraction)
            for i in 0..<binCount {
                let signalPower = magnitude[i]
                let noisePower = noiseProfile[i] * reductionFactor
                let cleanPower = max(signalPower - noisePower, 0.0)
                gain[i] = signalPower > 0 ? sqrtf(cleanPower / signalPower) : 0.0

                // Apply smoothing to prevent musical noise
                smoothedGain[i] = smoothingFactor * smoothedGain[i] + (1.0 - smoothingFactor) * gain[i]
            }

            // Apply gain
            vDSP_vmul(realp, 1, smoothedGain, 1, &realp, 1, vDSP_Length(binCount))
            vDSP_vmul(imagp, 1, smoothedGain, 1, &imagp, 1, vDSP_Length(binCount))

            // Inverse FFT
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))

            // Convert back to real
            var result = [Float](repeating: 0.0, count: fftSize)
            result.withUnsafeMutableBytes { ptr in
                ptr.baseAddress!.assumingMemoryBound(to: DSPComplex.self).withMemoryRebound(to: Float.self, capacity: fftSize) { floatPtr in
                    vDSP_ztoc(&splitComplex, 1, UnsafeMutablePointer<DSPComplex>(OpaquePointer(floatPtr)), 2, vDSP_Length(binCount))
                }
            }

            // Scale by FFT size
            var scale = Float(1.0) / Float(fftSize * 2)
            vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(fftSize))

            // Overlap-add
            var outputSlice = Array(output[position..<min(position + fftSize, output.count)])
            vDSP_vadd(outputSlice, 1, result, 1, &outputSlice, 1, vDSP_Length(min(fftSize, output.count - position)))
            for i in 0..<outputSlice.count {
                output[position + i] = outputSlice[i]
            }

            position += hopSize
        }

        // Copy processed audio back
        output.withUnsafeBufferPointer { bufferPtr in
            memcpy(samples, bufferPtr.baseAddress!, totalFrames * MemoryLayout<Float>.size)
        }
    }

    private func convertToM4A(from inputURL: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "SpectralNoiseReductionProcessor", code: -3, userInfo: [
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
            throw writer.error ?? NSError(domain: "SpectralNoiseReductionProcessor", code: -4, userInfo: [
                NSLocalizedDescriptionKey: "Conversion failed"
            ])
        }
    }
}
