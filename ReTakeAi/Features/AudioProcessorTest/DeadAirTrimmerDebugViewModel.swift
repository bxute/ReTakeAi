//
//  DeadAirTrimmerDebugViewModel.swift
//  ReTakeAi
//
//  ViewModel for dead air trimmer debug screen
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
@Observable
class DeadAirTrimmerDebugViewModel: NSObject {

    // MARK: - State

    var selectedAudioURL: URL?
    var originalAudioURL: URL?
    var processedAudioURL: URL?

    var isProcessing = false
    var processingProgress: Double = 0.0
    var currentStage: String = "Processing..."

    var errorMessage: String?
    var showError = false

    // MARK: - Trimmer Settings

    var trimmerEnabled = true
    var trimStart = true
    var trimEnd = true
    var trimMid = false
    var startBuffer: Double = 0.25
    var endBuffer: Double = 0.25
    var minDeadAirDuration: Double = 1.0
    var maxMidPauseDuration: Double = 1.5
    var minSustainedVoiceDuration: Double = 0.1

    // MARK: - Audio Playback

    private var originalPlayer: AVAudioPlayer?
    private var processedPlayer: AVAudioPlayer?

    var isPlayingOriginal = false
    var isPlayingProcessed = false

    // MARK: - Metrics

    var originalDuration: TimeInterval = 0
    var processedDuration: TimeInterval = 0
    var savedDuration: TimeInterval = 0

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

            let originalCopyURL = tempDir.appendingPathComponent("deadair_original_\(UUID().uuidString).\(inputURL.pathExtension)")
            try FileManager.default.copyItem(at: inputURL, to: originalCopyURL)
            originalAudioURL = originalCopyURL

            // Get original duration
            originalDuration = try await loadDuration(url: originalCopyURL)

            // Apply trimmer if enabled
            if trimmerEnabled {
                currentStage = "Trimming dead air..."
                processingProgress = 0.3

                let trimmedURL = tempDir.appendingPathComponent("deadair_trimmed_\(UUID().uuidString).m4a")

                let processor = DeadAirTrimmerProcessor()
                let config = ProcessorConfig([
                    "trimStart": trimStart,
                    "trimEnd": trimEnd,
                    "trimMid": trimMid,
                    "startBuffer": startBuffer,
                    "endBuffer": endBuffer,
                    "minDeadAirDuration": minDeadAirDuration,
                    "maxMidPauseDuration": maxMidPauseDuration,
                    "minSustainedVoiceDuration": minSustainedVoiceDuration
                ])

                try await processor.process(inputURL: originalCopyURL, outputURL: trimmedURL, config: config)

                processedAudioURL = trimmedURL

                // Get processed duration
                processedDuration = try await loadDuration(url: trimmedURL)
                savedDuration = originalDuration - processedDuration

            } else {
                // Bypass
                currentStage = "Bypassing trimmer..."
                processingProgress = 0.5

                let bypassedURL = tempDir.appendingPathComponent("deadair_bypassed_\(UUID().uuidString).\(inputURL.pathExtension)")
                try FileManager.default.copyItem(at: originalCopyURL, to: bypassedURL)
                processedAudioURL = bypassedURL

                processedDuration = originalDuration
                savedDuration = 0
            }

            processingTime = Date().timeIntervalSince(startTime)

            // Load waveforms
            currentStage = "Generating waveforms..."
            processingProgress = 0.9

            originalWaveform = try await WaveformExtractor.extractSamples(from: originalCopyURL, targetSampleCount: 500)

            if let processedURL = processedAudioURL {
                processedWaveform = try await WaveformExtractor.extractSamples(from: processedURL, targetSampleCount: 500)
            }

            processingProgress = 1.0
            currentStage = "Complete!"

            AppLogger.ui.info("Dead Air Trimmer Debug: Processing complete in \(self.processingTime)s")
            AppLogger.ui.info("  Original: \(self.originalDuration)s")
            AppLogger.ui.info("  Trimmed: \(self.processedDuration)s")
            AppLogger.ui.info("  Saved: \(self.savedDuration)s")

        } catch {
            showError(message: "Processing failed: \(error.localizedDescription)")
            AppLogger.ui.error("Dead Air Trimmer Debug: Processing failed - \(error)")
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
        savedDuration = 0
        originalWaveform = []
        processedWaveform = []
        processingTime = 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension DeadAirTrimmerDebugViewModel: AVAudioPlayerDelegate {
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
