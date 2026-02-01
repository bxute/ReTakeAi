//
//  SilenceAttenuatorDebugViewModel.swift
//  ReTakeAi
//
//  ViewModel for silence attenuator debug screen
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
@Observable
class SilenceAttenuatorDebugViewModel: NSObject {

    // MARK: - State

    var selectedAudioURL: URL?
    var originalAudioURL: URL?
    var processedAudioURL: URL?

    var isProcessing = false
    var processingProgress: Double = 0.0
    var currentStage: String = "Processing..."

    var errorMessage: String?
    var showError = false

    // MARK: - Attenuator Settings

    var attenuatorEnabled = true
    var attenuation: Double = -5.0      // dB
    var thresholdOffset: Double = 8.0   // dB above noise floor
    var attackTime: Double = 0.012      // 12 ms
    var releaseTime: Double = 0.200     // 200 ms

    // MARK: - Audio Playback

    private var originalPlayer: AVAudioPlayer?
    private var processedPlayer: AVAudioPlayer?

    var isPlayingOriginal = false
    var isPlayingProcessed = false

    // MARK: - Metrics

    var originalDuration: TimeInterval = 0
    var processedDuration: TimeInterval = 0

    var originalRMS: Float = 0
    var processedRMS: Float = 0

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

            let originalCopyURL = tempDir.appendingPathComponent("attenuator_original_\(UUID().uuidString).\(inputURL.pathExtension)")
            try FileManager.default.copyItem(at: inputURL, to: originalCopyURL)
            originalAudioURL = originalCopyURL

            // Apply attenuator if enabled
            if attenuatorEnabled {
                currentStage = "Applying silence attenuator..."
                processingProgress = 0.3

                let processedURL = tempDir.appendingPathComponent("attenuator_processed_\(UUID().uuidString).m4a")

                let processor = SilenceAttenuatorProcessor()
                let config = ProcessorConfig([
                    "frameSize": 0.020,
                    "attenuation": attenuation,
                    "thresholdOffset": thresholdOffset,
                    "attackTime": attackTime,
                    "releaseTime": releaseTime
                ])

                try await processor.process(inputURL: originalCopyURL, outputURL: processedURL, config: config)

                processedAudioURL = processedURL
            } else {
                // Bypass
                currentStage = "Bypassing attenuator..."
                processingProgress = 0.5

                let bypassedURL = tempDir.appendingPathComponent("attenuator_bypassed_\(UUID().uuidString).\(inputURL.pathExtension)")
                try FileManager.default.copyItem(at: originalCopyURL, to: bypassedURL)
                processedAudioURL = bypassedURL
            }

            processingTime = Date().timeIntervalSince(startTime)

            // Load metrics
            currentStage = "Calculating metrics..."
            processingProgress = 0.9

            originalDuration = try await loadDuration(url: originalCopyURL)
            originalRMS = try await calculateRMS(url: originalCopyURL)
            originalWaveform = try await WaveformExtractor.extractSamples(from: originalCopyURL, targetSampleCount: 500)

            if let processedURL = processedAudioURL {
                processedDuration = try await loadDuration(url: processedURL)
                processedRMS = try await calculateRMS(url: processedURL)
                processedWaveform = try await WaveformExtractor.extractSamples(from: processedURL, targetSampleCount: 500)
            }

            processingProgress = 1.0
            currentStage = "Complete!"

            AppLogger.ui.info("Silence Attenuator Debug: Processing complete in \(self.processingTime)s")
            AppLogger.ui.info("  Original RMS: \(self.originalRMS)")
            AppLogger.ui.info("  Processed RMS: \(self.processedRMS)")
            if attenuatorEnabled {
                let reduction = (originalRMS - processedRMS) / originalRMS * 100
                AppLogger.ui.info("  RMS Reduction: \(reduction)%")
            }

        } catch {
            showError(message: "Processing failed: \(error.localizedDescription)")
            AppLogger.ui.error("Silence Attenuator Debug: Processing failed - \(error)")
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

    private func calculateRMS(url: URL) async throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat

        let framesToRead = min(AVAudioFrameCount(format.sampleRate), AVAudioFrameCount(file.length))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
            return 0
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else { return 0 }

        var sum: Float = 0
        let frameCount = Int(buffer.frameLength)
        let samples = channelData[0]

        for i in 0..<frameCount {
            let sample = samples[i]
            sum += sample * sample
        }

        return sqrt(sum / Float(frameCount))
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
        originalRMS = 0
        processedRMS = 0
        originalWaveform = []
        processedWaveform = []
        processingTime = 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension SilenceAttenuatorDebugViewModel: AVAudioPlayerDelegate {
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
