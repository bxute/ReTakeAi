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
        "hpf": true,                    // High-Pass Filter
        "voiceBandPass": false,         // Voice Band-Pass
        "spectralNoiseReduction": false,// Spectral Noise Reduction
        "adaptiveGate": false,          // Adaptive Gate
        "voiceEQ": false,               // Voice EQ
        "multiBandCompressor": false,   // Multi-Band Compressor
        "deEsser": false,               // De-Esser
        "lufsNormalizer": false         // LUFS Normalizer
    ]

    var processorConfigs: [String: ProcessorConfig] = [
        "hpf": ProcessorConfig([
            "cutoffFrequency": 50.0,  // Default 60 Hz - safe for voice
            "makeupGain": 3.0         // +3 dB makeup gain
        ]),
        "voiceBandPass": ProcessorConfig([
            "lowCutoff": 85.0,
            "highCutoff": 4000.0,
            "order": 2
        ]),
        "spectralNoiseReduction": ProcessorConfig([
            "noiseProfileDuration": 0.5,
            "reductionAmount": 12.0,
            "smoothingFactor": 0.7
        ]),
        "adaptiveGate": ProcessorConfig([
            "threshold": -40.0,
            "ratio": 10.0,
            "attack": 5.0,
            "release": 50.0,
            "kneeWidth": 6.0
        ]),
        "voiceEQ": ProcessorConfig([
            "preset": "clarity"
        ]),
        "multiBandCompressor": ProcessorConfig([
            "lowThreshold": -20.0,
            "lowRatio": 2.0,
            "midThreshold": -15.0,
            "midRatio": 3.0,
            "highThreshold": -12.0,
            "highRatio": 4.0,
            "attack": 5.0,
            "release": 100.0
        ]),
        "deEsser": ProcessorConfig([
            "frequency": 7000.0,
            "threshold": -15.0,
            "ratio": 4.0,
            "bandwidth": 4000.0
        ]),
        "lufsNormalizer": ProcessorConfig([
            "targetLUFS": -16.0,
            "truePeak": -1.0
        ])
    ]

    // MARK: - Processor Info

    let processorInfo: [(id: String, name: String, description: String)] = [
        ("hpf", "High-Pass Filter", "Remove low-frequency rumble (60-100 Hz) with makeup gain"),
        ("voiceBandPass", "Voice Band-Pass", "Isolate voice frequencies (85-4000 Hz)"),
        ("spectralNoiseReduction", "Spectral Noise Reduction", "Remove constant background noise"),
        ("adaptiveGate", "Adaptive Gate", "Suppress noise during speech pauses"),
        ("voiceEQ", "Voice EQ", "Shape frequency for clarity (presets: clarity, warmth, broadcast, podcast)"),
        ("multiBandCompressor", "Multi-Band Compressor", "Control dynamics across frequency bands"),
        ("deEsser", "De-Esser", "Reduce harsh sibilance (S, T, Ch sounds)"),
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
                ("hpf", HPFProcessor(), "High-Pass Filter"),
                ("voiceBandPass", VoiceBandPassProcessor(), "Voice Band-Pass"),
                ("spectralNoiseReduction", SpectralNoiseReductionProcessor(), "Spectral Noise Reduction"),
                ("adaptiveGate", AdaptiveGateProcessor(), "Adaptive Gate"),
                ("voiceEQ", VoiceEQProcessor(), "Voice EQ"),
                ("multiBandCompressor", MultiBandCompressorProcessor(), "Multi-Band Compressor"),
                ("deEsser", DeEsserProcessor(), "De-Esser"),
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
