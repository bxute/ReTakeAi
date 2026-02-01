//
//  AdvancedProcessorTests.swift
//  ReTakeAiTests
//
//  Unit tests for advanced audio processors (Phase 3)
//

import XCTest
import AVFoundation
@testable import ReTakeAi

final class AdvancedProcessorTests: XCTestCase {

    // MARK: - Helper Methods

    func createTestBuffer(
        frequency: Float = 440.0,
        amplitude: Float = 0.5,
        duration: TimeInterval = 1.0,
        sampleRate: Double = 44100.0
    ) -> AVAudioPCMBuffer {

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!

        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let floatData = buffer.floatChannelData else {
            fatalError("Could not access float channel data")
        }

        let samples = floatData[0]
        let omega = 2.0 * Float.pi * frequency / Float(sampleRate)

        for frame in 0..<Int(frameCount) {
            samples[frame] = amplitude * sin(omega * Float(frame))
        }

        return buffer
    }

    func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let floatData = buffer.floatChannelData else { return 0 }

        let samples = floatData[0]
        let frameLength = Int(buffer.frameLength)

        var sumSquares: Float = 0
        for frame in 0..<frameLength {
            let sample = samples[frame]
            sumSquares += sample * sample
        }

        return sqrtf(sumSquares / Float(frameLength))
    }

    func calculateSpectralCentroid(buffer: AVAudioPCMBuffer) -> Float {
        // Simplified spectral centroid (zero crossing rate)
        guard let floatData = buffer.floatChannelData else { return 0 }

        let samples = floatData[0]
        let frameLength = Int(buffer.frameLength)

        var zeroCrossings = 0
        for frame in 1..<frameLength {
            if (samples[frame - 1] >= 0 && samples[frame] < 0) ||
               (samples[frame - 1] < 0 && samples[frame] >= 0) {
                zeroCrossings += 1
            }
        }

        return Float(zeroCrossings)
    }

    // MARK: - EQ Processor Tests

    func testEQProcessorWarmVoice() async throws {
        let processor = EQProcessor()
        let context = AudioProcessingContext()

        let buffer = createTestBuffer(frequency: 1000, amplitude: 0.5)

        let config = ProcessorConfig(
            processorID: "eq",
            enabled: true,
            parameters: [
                "preset": .string("warmVoice")
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        XCTAssertNotNil(processed)
        XCTAssertEqual(processed.frameLength, buffer.frameLength)
    }

    func testEQProcessorClarity() async throws {
        let processor = EQProcessor()
        let context = AudioProcessingContext()

        let buffer = createTestBuffer(frequency: 2000, amplitude: 0.5)

        let config = ProcessorConfig(
            processorID: "eq",
            enabled: true,
            parameters: [
                "preset": .string("clarity")
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        XCTAssertNotNil(processed)
    }

    func testEQProcessorAnalysis() async throws {
        let processor = EQProcessor()
        let buffer = createTestBuffer(frequency: 1000, amplitude: 0.5)

        let analysis = await processor.analyze(buffer: buffer)

        XCTAssertNotNil(analysis)
        XCTAssertEqual(analysis?.processorID, "eq")
    }

    // MARK: - Voice Enhancement Processor Tests

    func testVoiceEnhancementSubtle() async throws {
        let processor = VoiceEnhancementProcessor()
        let context = AudioProcessingContext()

        let buffer = createTestBuffer(frequency: 500, amplitude: 0.3)
        let originalRMS = calculateRMS(buffer: buffer)

        let config = ProcessorConfig(
            processorID: "voiceEnhancement",
            enabled: true,
            parameters: [
                "preset": .string("subtle")
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        let processedRMS = calculateRMS(buffer: processed)

        XCTAssertNotNil(processed)
        // Voice enhancement should alter the signal
        XCTAssertNotEqual(processedRMS, originalRMS, accuracy: 0.01)
    }

    func testVoiceEnhancementMaximum() async throws {
        let processor = VoiceEnhancementProcessor()
        let context = AudioProcessingContext()

        let buffer = createTestBuffer(frequency: 800, amplitude: 0.4)

        let config = ProcessorConfig(
            processorID: "voiceEnhancement",
            enabled: true,
            parameters: [
                "preset": .string("maximum")
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        XCTAssertNotNil(processed)
    }

    func testVoiceEnhancementAnalysis() async throws {
        let processor = VoiceEnhancementProcessor()
        let buffer = createTestBuffer(frequency: 500, amplitude: 0.2)

        let analysis = await processor.analyze(buffer: buffer)

        XCTAssertNotNil(analysis)
        XCTAssertTrue(analysis!.metrics.keys.contains("voiceStrength"))
    }

    // MARK: - Reverb Removal Processor Tests

    func testReverbRemovalLight() async throws {
        let processor = ReverbRemovalProcessor()
        let context = AudioProcessingContext()

        let buffer = createTestBuffer(amplitude: 0.5)

        let config = ProcessorConfig(
            processorID: "reverbRemoval",
            enabled: true,
            parameters: [
                "strength": .float(0.3)
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        XCTAssertNotNil(processed)
        XCTAssertEqual(processed.frameLength, buffer.frameLength)
    }

    func testReverbRemovalHeavy() async throws {
        let processor = ReverbRemovalProcessor()
        let context = AudioProcessingContext()

        let buffer = createTestBuffer(amplitude: 0.5)
        let originalRMS = calculateRMS(buffer: buffer)

        let config = ProcessorConfig(
            processorID: "reverbRemoval",
            enabled: true,
            parameters: [
                "strength": .float(0.8)
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        let processedRMS = calculateRMS(buffer: processed)

        // Heavy reverb removal should reduce RMS
        XCTAssertLessThan(processedRMS, originalRMS)
    }

    func testReverbRemovalAnalysis() async throws {
        let processor = ReverbRemovalProcessor()
        let buffer = createTestBuffer(amplitude: 0.5)

        let analysis = await processor.analyze(buffer: buffer)

        XCTAssertNotNil(analysis)
        XCTAssertTrue(analysis!.metrics.keys.contains("reverbEstimate"))
    }

    // MARK: - LUFS Normalization Processor Tests

    func testLUFSNormalization() async throws {
        let processor = LoudnessNormalizerProcessor()
        let context = AudioProcessingContext()

        // Create quiet buffer
        let buffer = createTestBuffer(amplitude: 0.1)
        let originalRMS = calculateRMS(buffer: buffer)

        let config = ProcessorConfig(
            processorID: "loudnessNormalization",
            enabled: true,
            parameters: [
                "target": .float(-16.0),
                "truePeak": .float(-1.0)
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        let processedRMS = calculateRMS(buffer: processed)

        // LUFS normalization should increase level
        XCTAssertGreaterThan(processedRMS, originalRMS)
    }

    func testLUFSTruePeakLimiting() async throws {
        let processor = LoudnessNormalizerProcessor()
        let context = AudioProcessingContext()

        // Create loud buffer
        let buffer = createTestBuffer(amplitude: 0.9)

        let config = ProcessorConfig(
            processorID: "loudnessNormalization",
            enabled: true,
            parameters: [
                "target": .float(-6.0),  // Very loud target
                "truePeak": .float(-1.0)
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        XCTAssertNotNil(processed)

        // Check peak doesn't exceed limit
        guard let floatData = processed.floatChannelData else {
            XCTFail("Could not access float data")
            return
        }

        let samples = floatData[0]
        let frameLength = Int(processed.frameLength)

        var peak: Float = 0
        for frame in 0..<frameLength {
            peak = max(peak, abs(samples[frame]))
        }

        let peakDb = 20.0 * log10(peak)
        XCTAssertLessThanOrEqual(peakDb, -0.9)  // Allow small margin
    }

    func testLUFSAnalysis() async throws {
        let processor = LoudnessNormalizerProcessor()
        let buffer = createTestBuffer(amplitude: 0.3)

        let analysis = await processor.analyze(buffer: buffer)

        XCTAssertNotNil(analysis)
        XCTAssertTrue(analysis!.metrics.keys.contains("measuredLUFS"))

        let lufs = analysis!.metrics["measuredLUFS"]!
        XCTAssertGreaterThan(lufs, -60.0)  // Should be reasonable
        XCTAssertLessThan(lufs, 0.0)       // Should be negative
    }

    // MARK: - Integration Tests with Advanced Processors

    func testAdvancedProcessingChain() async throws {
        let context = AudioProcessingContext()
        let chain = AudioProcessingChain(context: context)

        // Build advanced chain
        chain.addProcessor(NoiseReductionProcessor())
        chain.addProcessor(EQProcessor())
        chain.addProcessor(VoiceEnhancementProcessor())
        chain.addProcessor(CompressionProcessor())
        chain.addProcessor(ReverbRemovalProcessor())
        chain.addProcessor(LoudnessNormalizerProcessor())

        let buffer = createTestBuffer(amplitude: 0.3)

        let configs = [
            ProcessorConfig(processorID: "noiseReduction", enabled: true, parameters: ["strength": .float(0.5)]),
            ProcessorConfig(processorID: "eq", enabled: true, parameters: ["preset": .string("warmVoice")]),
            ProcessorConfig(processorID: "voiceEnhancement", enabled: true, parameters: ["preset": .string("moderate")]),
            ProcessorConfig(processorID: "compression", enabled: true, parameters: ["ratio": .float(3.0)]),
            ProcessorConfig(processorID: "reverbRemoval", enabled: true, parameters: ["strength": .float(0.5)]),
            ProcessorConfig(processorID: "loudnessNormalization", enabled: true, parameters: ["target": .float(-16.0)])
        ]

        let processed = try await chain.process(
            buffer: buffer,
            configs: configs,
            progress: { progress in
                print("Progress: \(Int(progress * 100))%")
            }
        )

        XCTAssertNotNil(processed)
        XCTAssertEqual(processed.frameLength, buffer.frameLength)

        // Verify processing changed the audio
        let originalRMS = calculateRMS(buffer: buffer)
        let processedRMS = calculateRMS(buffer: processed)
        XCTAssertNotEqual(originalRMS, processedRMS, accuracy: 0.001)
    }

    func testFullPresetProcessing() async throws {
        let context = AudioProcessingContext()
        let chain = AudioProcessingChain(context: context)

        // Use actual preset from DefaultPresets
        let preset = DefaultPresets.clearNarration

        try chain.buildChain(from: preset, processorRegistry: ProcessorRegistry.shared)

        let buffer = createTestBuffer(amplitude: 0.4)

        let processed = try await chain.process(
            buffer: buffer,
            configs: preset.processingChain,
            progress: { _ in }
        )

        XCTAssertNotNil(processed)
    }

    // MARK: - Performance Tests

    func testEQPerformance() throws {
        let processor = EQProcessor()
        let context = AudioProcessingContext()
        let buffer = createTestBuffer(duration: 10.0)  // 10 seconds

        let config = ProcessorConfig(
            processorID: "eq",
            enabled: true,
            parameters: ["preset": .string("warmVoice")]
        )

        measure {
            Task {
                _ = try await processor.process(buffer: buffer, config: config, context: context)
            }
        }
    }

    func testLUFSPerformance() throws {
        let processor = LoudnessNormalizerProcessor()
        let context = AudioProcessingContext()
        let buffer = createTestBuffer(duration: 10.0)

        let config = ProcessorConfig(
            processorID: "loudnessNormalization",
            enabled: true,
            parameters: ["target": .float(-16.0)]
        )

        measure {
            Task {
                _ = try await processor.process(buffer: buffer, config: config, context: context)
            }
        }
    }
}
