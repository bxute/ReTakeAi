//
//  DeadAirTrimmerDebugView.swift
//  ReTakeAi
//
//  Debug view for dead air trimmer testing with A/B comparison
//

import SwiftUI
import UniformTypeIdentifiers

struct DeadAirTrimmerDebugView: View {
    @State private var viewModel = DeadAirTrimmerDebugViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // File Selection
                    fileSelectionSection

                    if viewModel.selectedAudioURL != nil {
                        // Trimmer Controls
                        trimmerControlsSection

                        // Process Button
                        processButton

                        // Results
                        if viewModel.hasResults {
                            resultsSection
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dead Air Trimmer Debug")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - File Selection

    private var fileSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio File")
                .font(.headline)

            Button(action: { showFilePicker = true }) {
                HStack {
                    Image(systemName: "folder")
                    Text(viewModel.selectedAudioURL?.lastPathComponent ?? "Select Audio File")
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Trimmer Controls

    private var trimmerControlsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Trimmer Settings")
                    .font(.headline)
                Spacer()
                Image(systemName: "scissors")
                    .foregroundColor(.red)
            }

            // Enable Toggle
            Toggle("Enable Dead Air Trimmer", isOn: $viewModel.trimmerEnabled)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding()
                .background(viewModel.trimmerEnabled ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(12)

            if viewModel.trimmerEnabled {
                // Trim Location Toggles
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trim Locations")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Toggle("Trim Start (before first voice)", isOn: $viewModel.trimStart)
                        .font(.caption)
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)

                    Toggle("Trim End (after last voice)", isOn: $viewModel.trimEnd)
                        .font(.caption)
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)

                    Toggle("Trim Mid-Scene (compress long pauses)", isOn: $viewModel.trimMid)
                        .font(.caption)
                        .padding()
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                // Buffer Settings
                if viewModel.trimStart || viewModel.trimEnd {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Buffer Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if viewModel.trimStart {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Start Buffer")
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.2fs", viewModel.startBuffer))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }

                                Slider(value: $viewModel.startBuffer, in: 0...1.0, step: 0.05)
                                    .tint(.blue)

                                Text("Silence to keep before first voice")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if viewModel.trimEnd {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("End Buffer")
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.2fs", viewModel.endBuffer))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }

                                Slider(value: $viewModel.endBuffer, in: 0...1.0, step: 0.05)
                                    .tint(.blue)

                                Text("Silence to keep after last voice")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                }

                // Dead Air Detection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Min Dead Air Duration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(String(format: "%.1fs", viewModel.minDeadAirDuration))
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }

                    Slider(value: $viewModel.minDeadAirDuration, in: 0.5...5.0, step: 0.5)
                        .tint(.red)

                    HStack {
                        Text("0.5s (Sensitive)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("5.0s (Conservative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Silence longer than this is considered dead air")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .cornerRadius(12)

                // Sustained Voice Detection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Min Sustained Voice")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(String(format: "%.2fs", viewModel.minSustainedVoiceDuration))
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }

                    Slider(value: $viewModel.minSustainedVoiceDuration, in: 0.0...0.3, step: 0.05)
                        .tint(.green)

                    HStack {
                        Text("0.0s (Catch all)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("0.3s (Very strict)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Voice must be this long to count (ignores breath, clicks)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)

                // Mid-Scene Settings
                if viewModel.trimMid {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Mid-Scene Pause")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.1fs", viewModel.maxMidPauseDuration))
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .fontWeight(.bold)
                        }

                        Slider(value: $viewModel.maxMidPauseDuration, in: 0.5...3.0, step: 0.1)
                            .tint(.orange)

                        Text("Long pauses will be compressed to this duration")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)
                }

                // Quick Presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Presets")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        Button("Gentle") {
                            viewModel.trimStart = true
                            viewModel.trimEnd = true
                            viewModel.trimMid = false
                            viewModel.startBuffer = 0.5
                            viewModel.endBuffer = 0.5
                            viewModel.minDeadAirDuration = 2.0
                            viewModel.minSustainedVoiceDuration = 0.05
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)

                        Button("Standard") {
                            viewModel.trimStart = true
                            viewModel.trimEnd = true
                            viewModel.trimMid = false
                            viewModel.startBuffer = 0.25
                            viewModel.endBuffer = 0.25
                            viewModel.minDeadAirDuration = 1.0
                            viewModel.minSustainedVoiceDuration = 0.1
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)

                        Button("Aggressive") {
                            viewModel.trimStart = true
                            viewModel.trimEnd = true
                            viewModel.trimMid = true
                            viewModel.startBuffer = 0.1
                            viewModel.endBuffer = 0.1
                            viewModel.minDeadAirDuration = 0.5
                            viewModel.maxMidPauseDuration = 1.0
                            viewModel.minSustainedVoiceDuration = 0.2
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(12)

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("How It Works")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Text("• Analyzes audio for voice vs silence\n• Detects dead air (long silent pauses)\n• Trims at start/end with buffer\n• Optionally compresses mid-scene pauses\n• Returns shorter, tighter audio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Process Button

    private var processButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await viewModel.processAudio()
                }
            }) {
                HStack {
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "scissors")
                    }
                    Text(viewModel.isProcessing ? viewModel.currentStage : "Process Audio")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isProcessing ? Color.gray : Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isProcessing)

            if viewModel.isProcessing {
                ProgressView(value: viewModel.processingProgress)
                    .progressViewStyle(.linear)
            }
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            Text("Results")
                .font(.headline)

            // Duration Comparison
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2fs", viewModel.originalDuration))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                Image(systemName: "arrow.right")
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trimmed")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(String(format: "%.2fs", viewModel.processedDuration))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }

            // Savings
            if viewModel.trimmerEnabled && viewModel.savedDuration > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Time Saved", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.2fs (%.0f%%)", viewModel.savedDuration, (viewModel.savedDuration / viewModel.originalDuration) * 100))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    HStack {
                        Label("Processing Time", systemImage: "clock")
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.2f sec", viewModel.processingTime))
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Waveform Comparison
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original Waveform")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    if !viewModel.originalWaveform.isEmpty {
                        WaveformView(samples: viewModel.originalWaveform, color: .gray, label: "")
                            .frame(height: 60)
                    }

                    Button(action: { viewModel.playOriginal() }) {
                        HStack {
                            Image(systemName: viewModel.isPlayingOriginal ? "stop.fill" : "play.fill")
                            Text(viewModel.isPlayingOriginal ? "Stop" : "Play Original")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trimmed Waveform")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)

                    if !viewModel.processedWaveform.isEmpty {
                        WaveformView(samples: viewModel.processedWaveform, color: .red, label: "")
                            .frame(height: 60)
                    }

                    Button(action: { viewModel.playProcessed() }) {
                        HStack {
                            Image(systemName: viewModel.isPlayingProcessed ? "stop.fill" : "play.fill")
                            Text(viewModel.isPlayingProcessed ? "Stop" : "Play Trimmed")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                viewModel.selectedAudioURL = url
                viewModel.reset()
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
            viewModel.showError = true
        }
    }
}

// MARK: - Preview

#Preview {
    DeadAirTrimmerDebugView()
}
