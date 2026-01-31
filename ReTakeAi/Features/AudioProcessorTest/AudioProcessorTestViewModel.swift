//
//  AudioProcessorTestViewModel.swift
//  ReTakeAi
//
//  ViewModel for audio processor test screen
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
@Observable
class AudioProcessorTestViewModel: NSObject {

    // MARK: - State

    var selectedAudioURL: URL?
    var originalAudioURL: URL?
    var processedAudioURL: URL?

    var isProcessing = false
    var processingProgress: Double = 0.0
    var currentStage: String = ""

    var errorMessage: String?
    var showError = false

    // MARK: - Processor Selection

    var enabledProcessors: [String: Bool] = [
        "gate": true,
        "noiseReduction": true,
        "normalization": true,
        "compression": true,
        "deEsser": true,
        "popRemoval": false,
        "clickRemoval": false,
        "eq": true,
        "voiceEnhancement": false,
        "reverbRemoval": false,
        "loudnessNormalization": true
    ]

    // MARK: - Processor Info

    let processorInfo: [(id: String, name: String, description: String)] = [
        ("gate", "Noise Gate", "Suppress audio below threshold"),
        ("noiseReduction", "Noise Reduction", "Remove background noise"),
        ("popRemoval", "Pop Removal", "Remove plosives (P, B sounds)"),
        ("clickRemoval", "Click Removal", "Remove clicks and mouth noises"),
        ("deEsser", "De-Esser", "Reduce harsh sibilance (S, T sounds)"),
        ("eq", "Parametric EQ", "Shape frequency response"),
        ("voiceEnhancement", "Voice Enhancement", "Optimize speech clarity"),
        ("compression", "Compressor", "Control dynamic range"),
        ("reverbRemoval", "Reverb Removal", "Reduce room reflections"),
        ("normalization", "Normalization", "Basic volume normalization"),
        ("loudnessNormalization", "LUFS Normalization", "Industry-standard loudness")
    ]

    // MARK: - Audio Playback

    private var originalPlayer: AVAudioPlayer?
    private var processedPlayer: AVAudioPlayer?

    var isPlayingOriginal = false
    var isPlayingProcessed = false

    // MARK: - Audio Duration and Metrics

    var originalDuration: TimeInterval = 0
    var processedDuration: TimeInterval = 0

    var originalWaveform: [Float] = []
    var processedWaveform: [Float] = []

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

        do {
            currentStage = "Processing audio..."

            // TODO: Implement audio processing when audio engine is ready
            // For now, just simulate processing
            for i in 0...10 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                processingProgress = Double(i) / 10.0
                currentStage = "Processing... \(i * 10)%"
            }

            // For now, just copy the original as processed
            let tempDir = FileManager.default.temporaryDirectory
            let processedURL = tempDir.appendingPathComponent("processed_\(UUID().uuidString).m4a")

            try FileManager.default.copyItem(at: inputURL, to: processedURL)

            processedAudioURL = processedURL
            originalAudioURL = inputURL

            // Load durations
            originalDuration = try await loadDuration(url: inputURL)
            processedDuration = try await loadDuration(url: processedURL)

            // Extract waveforms
            currentStage = "Generating waveforms..."
            originalWaveform = try await WaveformExtractor.extractSamples(from: inputURL, targetSampleCount: 500)
            processedWaveform = try await WaveformExtractor.extractSamples(from: processedURL, targetSampleCount: 500)

            currentStage = "Complete!"

            AppLogger.ui.info("Audio processing completed (stub mode)")

        } catch {
            showError(message: "Processing failed: \(error.localizedDescription)")
            AppLogger.ui.error("Audio processing failed: \(error)")
        }
    }

    // MARK: - Audio Playback

    func playOriginal() {
        guard let url = originalAudioURL else { return }
        stopProcessed()

        do {
            originalPlayer = try AVAudioPlayer(contentsOf: url)
            originalPlayer?.delegate = self
            originalPlayer?.play()
            isPlayingOriginal = true
        } catch {
            showError(message: "Failed to play original: \(error.localizedDescription)")
        }
    }

    func stopOriginal() {
        originalPlayer?.stop()
        isPlayingOriginal = false
    }

    func playProcessed() {
        guard let url = processedAudioURL else { return }
        stopOriginal()

        do {
            processedPlayer = try AVAudioPlayer(contentsOf: url)
            processedPlayer?.delegate = self
            processedPlayer?.play()
            isPlayingProcessed = true
        } catch {
            showError(message: "Failed to play processed: \(error.localizedDescription)")
        }
    }

    func stopProcessed() {
        processedPlayer?.stop()
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

    // MARK: - Reset

    func reset() {
        stopOriginal()
        stopProcessed()

        selectedAudioURL = nil
        originalAudioURL = nil
        processedAudioURL = nil
        processingProgress = 0.0
        currentStage = ""
        errorMessage = nil
        showError = false
        originalDuration = 0
        processedDuration = 0
        originalWaveform = []
        processedWaveform = []
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioProcessorTestViewModel: AVAudioPlayerDelegate {
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
