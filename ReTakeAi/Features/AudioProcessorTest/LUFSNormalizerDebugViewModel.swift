//
//  LUFSNormalizerDebugViewModel.swift
//  ReTakeAi
//
//  ViewModel for LUFS normalizer debug screen
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
@Observable
class LUFSNormalizerDebugViewModel: NSObject {

    // MARK: - State

    var selectedAudioURL: URL?
    var originalAudioURL: URL?
    var processedAudioURL: URL?

    var isProcessing = false
    var processingProgress: Double = 0.0
    var currentStage: String = "Processing..."

    var errorMessage: String?
    var showError = false

    // MARK: - LUFS Settings

    var normalizerEnabled = true
    var targetLUFS: Double = -16.0      // EBU R128 broadcast standard
    var truePeakLimit: Double = -1.0    // dBTP

    // MARK: - Audio Playback

    private var originalPlayer: AVAudioPlayer?
    private var processedPlayer: AVAudioPlayer?

    var isPlayingOriginal = false
    var isPlayingProcessed = false

    // MARK: - Metrics

    var originalDuration: TimeInterval = 0
    var processedDuration: TimeInterval = 0

    var originalLUFS: Float = 0
    var processedLUFS: Float = 0
    var originalPeak: Float = 0
    var processedPeak: Float = 0
    var appliedGain: Float = 0

    var originalWaveform: [Float] = []
    var processedWaveform: [Float] = []

    var processingTime: TimeInterval = 0

    var hasResults: Bool {
        originalAudioURL != nil && processedAudioURL != nil
    }

    // MARK: - Processing

    func processAudio() async {
        guard let inputURL = selectedAudioURL else {
            showError(message: "Please select an audio file first")
            return
        }

        isProcessing = true
        processingProgress = 0.0
        errorMessage = nil
        defer { isProcessing = false }

        let didStartAccessing = inputURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                inputURL.stopAccessingSecurityScopedResource()
            }
        }

        let startTime = Date()

        do {
            let tempDir = FileManager.default.temporaryDirectory

            // Copy original
            currentStage = "Copying original..."
            processingProgress = 0.1

            let originalCopyURL = tempDir.appendingPathComponent("lufs_original_\(UUID().uuidString).\(inputURL.pathExtension)")
            try FileManager.default.copyItem(at: inputURL, to: originalCopyURL)
            originalAudioURL = originalCopyURL

            // Measure original LUFS
            currentStage = "Analyzing original..."
            processingProgress = 0.3
            (originalLUFS, originalPeak) = try await measureAudio(url: originalCopyURL)

            // Apply normalizer if enabled
            if normalizerEnabled {
                currentStage = "Applying LUFS normalization..."
                processingProgress = 0.5

                let processedURL = tempDir.appendingPathComponent("lufs_processed_\(UUID().uuidString).m4a")

                let processor = LUFSNormalizerProcessor()
                let config = ProcessorConfig([
                    "targetLUFS": targetLUFS,
                    "truePeak": truePeakLimit
                ])

                try await processor.process(inputURL: originalCopyURL, outputURL: processedURL, config: config)

                processedAudioURL = processedURL

                // Measure processed LUFS
                currentStage = "Analyzing result..."
                processingProgress = 0.8
                (processedLUFS, processedPeak) = try await measureAudio(url: processedURL)

                appliedGain = processedLUFS - originalLUFS

            } else {
                // Bypass
                currentStage = "Bypassing normalizer..."
                processingProgress = 0.5

                let bypassedURL = tempDir.appendingPathComponent("lufs_bypassed_\(UUID().uuidString).\(inputURL.pathExtension)")
                try FileManager.default.copyItem(at: originalCopyURL, to: bypassedURL)
                processedAudioURL = bypassedURL

                processedLUFS = originalLUFS
                processedPeak = originalPeak
                appliedGain = 0
            }

            processingTime = Date().timeIntervalSince(startTime)

            // Load waveforms
            currentStage = "Generating waveforms..."
            processingProgress = 0.9

            originalDuration = try await loadDuration(url: originalCopyURL)
            originalWaveform = try await WaveformExtractor.extractSamples(from: originalCopyURL, targetSampleCount: 500)

            if let processedURL = processedAudioURL {
                processedDuration = try await loadDuration(url: processedURL)
                processedWaveform = try await WaveformExtractor.extractSamples(from: processedURL, targetSampleCount: 500)
            }

            processingProgress = 1.0
            currentStage = "Complete!"

            AppLogger.ui.info("LUFS Normalizer Debug: Processing complete in \(self.processingTime)s")
            AppLogger.ui.info("  Original LUFS: \(self.originalLUFS)")
            AppLogger.ui.info("  Processed LUFS: \(self.processedLUFS)")
            AppLogger.ui.info("  Applied Gain: \(self.appliedGain) dB")

        } catch {
            showError(message: "Processing failed: \(error.localizedDescription)")
            AppLogger.ui.error("LUFS Normalizer Debug: Processing failed - \(error)")
        }
    }

    // MARK: - Audio Playback

    func playOriginal() {
        guard let url = originalAudioURL else { return }
        stopAll()

        do {
            originalPlayer = try AVAudioPlayer(contentsOf: url)
            originalPlayer?.delegate = self
            originalPlayer?.play()
            isPlayingOriginal = true
        } catch {
            showError(message: "Failed to play original: \(error.localizedDescription)")
        }
    }

    func playProcessed() {
        guard let url = processedAudioURL else { return }
        stopAll()

        do {
            processedPlayer = try AVAudioPlayer(contentsOf: url)
            processedPlayer?.delegate = self
            processedPlayer?.play()
            isPlayingProcessed = true
        } catch {
            showError(message: "Failed to play processed: \(error.localizedDescription)")
        }
    }

    private func stopAll() {
        originalPlayer?.stop()
        processedPlayer?.stop()
        isPlayingOriginal = false
        isPlayingProcessed = false
    }

    // MARK: - Helpers

    private func loadDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    private func measureAudio(url: URL) async throws -> (lufs: Float, peak: Float) {
        // Simple approximation - read first second and measure
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat

        let framesToRead = min(AVAudioFrameCount(format.sampleRate), AVAudioFrameCount(file.length))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
            return (0, 0)
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else { return (0, 0) }

        var sum: Float = 0
        var peak: Float = 0
        let frameCount = Int(buffer.frameLength)
        let samples = channelData[0]

        for i in 0..<frameCount {
            let sample = samples[i]
            sum += sample * sample
            peak = max(peak, abs(sample))
        }

        let rms = sqrt(sum / Float(frameCount))
        let lufs = 20.0 * log10(max(rms, 1e-10))
        let peakDB = 20.0 * log10(max(peak, 1e-10))

        return (lufs, peakDB)
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
        AppLogger.ui.error("\(message)")
    }

    func reset() {
        stopAll()
        originalAudioURL = nil
        processedAudioURL = nil
        processingProgress = 0.0
        currentStage = "Processing..."
        originalDuration = 0
        processedDuration = 0
        originalLUFS = 0
        processedLUFS = 0
        originalPeak = 0
        processedPeak = 0
        appliedGain = 0
        originalWaveform = []
        processedWaveform = []
        processingTime = 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension LUFSNormalizerDebugViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if player == self.originalPlayer {
                self.isPlayingOriginal = false
            } else if player == self.processedPlayer {
                self.isPlayingProcessed = false
            }
        }
    }
}
