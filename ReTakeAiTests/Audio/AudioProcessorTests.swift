//
//  AudioProcessorTests.swift
//  ReTakeAiTests
//
//  Unit tests for audio processors
//

import XCTest
import AVFoundation
@testable import ReTakeAi

final class AudioProcessorTests: XCTestCase {

    // MARK: - Helper Methods

    /// Create a test buffer with sine wave
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

    /// Create test buffer with noise
    func createNoiseBuffer(
        amplitude: Float = 0.1,
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

        for frame in 0..<Int(frameCount) {
            samples[frame] = amplitude * (Float.random(in: -1.0...1.0))
        }

        return buffer
    }

    /// Calculate RMS level
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

    /// Calculate peak level
    func calculatePeak(buffer: AVAudioPCMBuffer) -> Float {
        guard let floatData = buffer.floatChannelData else { return 0 }

        let samples = floatData[0]
        let frameLength = Int(buffer.frameLength)

        var peak: Float = 0
        for frame in 0..<frameLength {
            peak = max(peak, abs(samples[frame]))
        }

        return peak
    }

    // MARK: - Gate Processor Tests

    func testGateProcessor() async throws {
        let processor = GateProcessor()
        let context = AudioProcessingContext()

        // Create buffer with signal + noise
        let buffer = createTestBuffer(amplitude: 0.5)

        let config = ProcessorConfig(
            processorID: "gate",
            enabled: true,
            parameters: [
                "threshold": .float(-40.0),
                "ratio": .float(4.0)
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

    func testGateAnalysis() async throws {
        let processor = GateProcessor()
        let buffer = createNoiseBuffer(amplitude: 0.01)

        let analysis = await processor.analyze(buffer: buffer)

        XCTAssertNotNil(analysis)
        XCTAssertEqual(analysis?.processorID, "gate")
        XCTAssertTrue(analysis!.metrics["gatedPercentage"]! > 0)
    }

    // MARK: - Normalization Processor Tests

    func testNormalizationProcessor() async throws {
        let processor = NormalizationProcessor()
        let context = AudioProcessingContext()

        // Create quiet buffer
        let buffer = createTestBuffer(amplitude: 0.1)
        let originalRMS = calculateRMS(buffer: buffer)

        let config = ProcessorConfig(
            processorID: "normalization",
            enabled: true,
            parameters: [
                "target": .float(-16.0),
                "peakLimit": .float(-1.0)
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        let processedRMS = calculateRMS(buffer: processed)

        // RMS should increase after normalization
        XCTAssertGreaterThan(processedRMS, originalRMS)
    }

    func testNormalizationAnalysis() async throws {
        let processor = NormalizationProcessor()
        let buffer = createTestBuffer(amplitude: 0.2)

        let analysis = await processor.analyze(buffer: buffer)

        XCTAssertNotNil(analysis)
        XCTAssertTrue(analysis!.metrics.keys.contains("currentLoudness"))
        XCTAssertTrue(analysis!.metrics.keys.contains("peakLevel"))
    }

    // MARK: - Compression Processor Tests

    func testCompressionProcessor() async throws {
        let processor = CompressionProcessor()
        let context = AudioProcessingContext()

        // Create buffer with varying dynamics
        let buffer = createTestBuffer(amplitude: 0.8)
        let originalPeak = calculatePeak(buffer: buffer)

        let config = ProcessorConfig(
            processorID: "compression",
            enabled: true,
            parameters: [
                "ratio": .float(4.0),
                "threshold": .float(-20.0),
                "attack": .float(0.005),
                "release": .float(0.1),
                "knee": .string("soft")
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        let processedPeak = calculatePeak(buffer: processed)

        // Peak should be reduced after compression
        XCTAssertLessThanOrEqual(processedPeak, originalPeak)
    }

    // MARK: - De-Esser Processor Tests

    func testDeEsserProcessor() async throws {
        let processor = DeEsserProcessor()
        let context = AudioProcessingContext()

        // Create high-frequency content (simulating sibilance)
        let buffer = createTestBuffer(frequency: 6000, amplitude: 0.5)

        let config = ProcessorConfig(
            processorID: "deEsser",
            enabled: true,
            parameters: [
                "threshold": .float(-20.0),
                "frequency": .float(6000.0),
                "ratio": .float(4.0)
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

    // MARK: - Noise Reduction Processor Tests

    func testNoiseReductionProcessor() async throws {
        let processor = NoiseReductionProcessor()
        let context = AudioProcessingContext()
        context.noiseFloor = -60.0

        let buffer = createNoiseBuffer(amplitude: 0.05)
        let originalRMS = calculateRMS(buffer: buffer)

        let config = ProcessorConfig(
            processorID: "noiseReduction",
            enabled: true,
            parameters: [
                "strength": .float(0.7)
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        let processedRMS = calculateRMS(buffer: processed)

        // RMS should decrease after noise reduction
        XCTAssertLessThan(processedRMS, originalRMS)
    }

    // MARK: - Pop Removal Processor Tests

    func testPopRemovalProcessor() async throws {
        let processor = PopRemovalProcessor()
        let context = AudioProcessingContext()

        let buffer = createTestBuffer(amplitude: 0.5)

        let config = ProcessorConfig(
            processorID: "popRemoval",
            enabled: true,
            parameters: [
                "sensitivity": .float(0.5)
            ]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        XCTAssertNotNil(processed)
    }

    // MARK: - Click Removal Processor Tests

    func testClickRemovalProcessor() async throws {
        let processor = ClickRemovalProcessor()
        let context = AudioProcessingContext()

        let buffer = createTestBuffer(amplitude: 0.5)

        let config = ProcessorConfig(
            processorID: "clickRemoval",
            enabled: true,
            parameters: [:]
        )

        let processed = try await processor.process(
            buffer: buffer,
            config: config,
            context: context
        )

        XCTAssertNotNil(processed)
    }

    // MARK: - Integration Tests

    func testProcessingChain() async throws {
        let context = AudioProcessingContext()
        let chain = AudioProcessingChain(context: context)

        // Add processors
        chain.addProcessor(GateProcessor())
        chain.addProcessor(NoiseReductionProcessor())
        chain.addProcessor(CompressionProcessor())
        chain.addProcessor(NormalizationProcessor())

        let buffer = createTestBuffer(amplitude: 0.3)

        let configs = [
            ProcessorConfig(processorID: "gate", enabled: true, parameters: ["threshold": .float(-40.0)]),
            ProcessorConfig(processorID: "noiseReduction", enabled: true, parameters: ["strength": .float(0.5)]),
            ProcessorConfig(processorID: "compression", enabled: true, parameters: ["ratio": .float(3.0)]),
            ProcessorConfig(processorID: "normalization", enabled: true, parameters: ["target": .float(-16.0)])
        ]

        let processed = try await chain.process(
            buffer: buffer,
            configs: configs,
            progress: { _ in }
        )

        XCTAssertNotNil(processed)
        XCTAssertEqual(processed.frameLength, buffer.frameLength)
    }
}
