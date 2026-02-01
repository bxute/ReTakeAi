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
        "silenceAttenuator": true,      // Silence Attenuator (Pure Gain)
        "lufsNormalizer": true          // LUFS Normalizer
    ]

    var processorConfigs: [String: ProcessorConfig] = [
        "silenceAttenuator": ProcessorConfig([
            "frameSize": 0.020,       // 20 ms frames
            "attenuation": -5.0,      // -5 dB for silence
            "thresholdOffset": 8.0,   // +8 dB above noise floor
            "attackTime": 0.012,      // 12 ms
            "releaseTime": 0.200      // 200 ms
        ]),
        "lufsNormalizer": ProcessorConfig([
            "targetLUFS": -16.0,      // EBU R128 broadcast standard
            "truePeak": -1.0          // dBTP (prevent clipping)
        ])
    ]

    // MARK: - Processor Info

    let processorInfo: [(id: String, name: String, description: String)] = [
        ("silenceAttenuator", "Silence Attenuator", "Pure gain-based silence reduction with adaptive threshold"),
        ("lufsNormalizer", "LUFS Normalizer", "Normalize to broadcast standard loudness (-16 LUFS)")
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

    var savedFilesMessage: String?
    var showSavedMessage = false
    var savedDirectoryURL: URL?
    var filesToShare: [URL] = []
    var showShareSheet = false

    // MARK: - Save to Files

    func getDocumentsDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("AudioProcessorTests", isDirectory: true)
    }

    func saveProcessedAudio() {
        guard let originalURL = originalAudioURL,
              let processedURL = processedAudioURL else {
            showError(message: "No audio files to save")
            return
        }

        do {
            // Use temp directory for preparing files to share
            let tempDir = FileManager.default.temporaryDirectory
            let audioTestDir = tempDir.appendingPathComponent("AudioProcessorTests_\(UUID().uuidString)", isDirectory: true)

            // Create directory
            try FileManager.default.createDirectory(at: audioTestDir, withIntermediateDirectories: true)

            // Generate timestamp for filenames
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")

            // Copy original
            let originalDestURL = audioTestDir.appendingPathComponent("original_\(timestamp).\(originalURL.pathExtension)")
            try FileManager.default.copyItem(at: originalURL, to: originalDestURL)

            // Copy processed
            let processedDestURL = audioTestDir.appendingPathComponent("processed_\(timestamp).\(processedURL.pathExtension)")
            try FileManager.default.copyItem(at: processedURL, to: processedDestURL)

            // Save processor configuration info
            let configURL = audioTestDir.appendingPathComponent("config_\(timestamp).txt")
            let configText = generateConfigText()
            try configText.write(to: configURL, atomically: true, encoding: .utf8)

            // Prepare files for sharing
            filesToShare = [originalDestURL, processedDestURL, configURL]
            showShareSheet = true

            AppLogger.ui.info("Files prepared for sharing")

        } catch {
            showError(message: "Failed to prepare files: \(error.localizedDescription)")
        }
    }

    private func generateConfigText() -> String {
        var text = "Audio Processor Test Configuration\n"
        text += "===================================\n\n"
        text += "Date: \(Date())\n\n"
        text += "Enabled Processors:\n"

        for info in processorInfo {
            if enabledProcessors[info.id] == true {
                text += "- \(info.name)\n"
                text += "  \(info.description)\n"

                if let config = processorConfigs[info.id] {
                    text += "  Config: \(config.parameters)\n"
                }
                text += "\n"
            }
        }

        text += "\nOriginal Duration: \(String(format: "%.2f", originalDuration))s\n"
        text += "Processed Duration: \(String(format: "%.2f", processedDuration))s\n"

        return text
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

        // Start accessing security-scoped resource for files picked from Files app
        let didStartAccessing = inputURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                inputURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            currentStage = "Processing audio..."

            // Create output URLs
            let tempDir = FileManager.default.temporaryDirectory
            var currentURL = inputURL
            var intermediateURLs: [URL] = []

            // Define processing order
            let processingOrder: [(id: String, processor: any AudioProcessorProtocol, name: String)] = [
                ("silenceAttenuator", SilenceAttenuatorProcessor(), "Silence Attenuator"),
                ("lufsNormalizer", LUFSNormalizerProcessor(), "LUFS Normalizer")
            ]

            // Count enabled processors for progress tracking
            let enabledCount = processingOrder.filter { enabledProcessors[$0.id] == true }.count

            if enabledCount == 0 {
                // No processing, just copy
                let processedURL = tempDir.appendingPathComponent("processed_\(UUID().uuidString).m4a")
                try FileManager.default.copyItem(at: inputURL, to: processedURL)
                processedAudioURL = processedURL
                processingProgress = 1.0
            } else {
                // Apply each enabled processor in order
                var processorIndex = 0
                for (id, processor, name) in processingOrder {
                    if enabledProcessors[id] == true {
                        currentStage = "Applying \(name)..."
                        processingProgress = Double(processorIndex) / Double(enabledCount)

                        let outputURL = tempDir.appendingPathComponent("intermediate_\(UUID().uuidString).m4a")
                        let config = processorConfigs[id] ?? processor.defaultConfig

                        try await processor.process(inputURL: currentURL, outputURL: outputURL, config: config)

                        // Clean up previous intermediate file (but not the original input)
                        if currentURL != inputURL {
                            try? FileManager.default.removeItem(at: currentURL)
                        }

                        currentURL = outputURL
                        intermediateURLs.append(outputURL)
                        processorIndex += 1
                    }
                }

                processedAudioURL = currentURL
                processingProgress = 1.0
                currentStage = "Processing complete!"
            }

            // Copy original to temp directory for playback (to avoid security-scoped access issues)
            let originalCopyURL = tempDir.appendingPathComponent("original_\(UUID().uuidString).\(inputURL.pathExtension)")
            try FileManager.default.copyItem(at: inputURL, to: originalCopyURL)
            originalAudioURL = originalCopyURL

            // Load durations
            originalDuration = try await loadDuration(url: originalCopyURL)
            if let processedURL = processedAudioURL {
                processedDuration = try await loadDuration(url: processedURL)

                // Extract waveforms
                currentStage = "Generating waveforms..."
                originalWaveform = try await WaveformExtractor.extractSamples(from: originalCopyURL, targetSampleCount: 500)
                processedWaveform = try await WaveformExtractor.extractSamples(from: processedURL, targetSampleCount: 500)
            }

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
