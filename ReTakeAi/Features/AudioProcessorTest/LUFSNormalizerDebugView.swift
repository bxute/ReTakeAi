//
//  LUFSNormalizerDebugView.swift
//  ReTakeAi
//
//  Debug view for LUFS normalizer testing with A/B comparison
//

import SwiftUI
import UniformTypeIdentifiers

struct LUFSNormalizerDebugView: View {
    @State private var viewModel = LUFSNormalizerDebugViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // File Selection
                    fileSelectionSection

                    if viewModel.selectedAudioURL != nil {
                        // Normalizer Controls
                        normalizerControlsSection

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
            .navigationTitle("LUFS Normalizer Debug")
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

    // MARK: - Normalizer Controls

    private var normalizerControlsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Normalizer Settings")
                    .font(.headline)
                Spacer()
                Image(systemName: "waveform.and.magnifyingglass")
                    .foregroundColor(.blue)
            }

            // Enable Toggle
            Toggle("Enable LUFS Normalizer", isOn: $viewModel.normalizerEnabled)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding()
                .background(viewModel.normalizerEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(12)

            if viewModel.normalizerEnabled {
                // Target LUFS Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Target LUFS")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(viewModel.targetLUFS)) LUFS")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                    }

                    Slider(value: $viewModel.targetLUFS, in: -23...(-9), step: 1)
                        .tint(.blue)

                    HStack {
                        Text("-23 LUFS (Quiet)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("-9 LUFS (Loud)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Target perceived loudness level")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)

                // True Peak Limiter
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("True Peak Limit")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(viewModel.truePeakLimit)) dBTP")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }

                    Slider(value: $viewModel.truePeakLimit, in: -3...(-0.1), step: 0.1)
                        .tint(.red)

                    HStack {
                        Text("-3 dBTP (Safe)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("-0.1 dBTP (Maximum)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Prevent clipping and distortion")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .cornerRadius(12)

                // Platform Presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Platform Presets")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Button("YouTube/IG") {
                                viewModel.targetLUFS = -14.0
                                viewModel.truePeakLimit = -1.0
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)

                            Button("Broadcast") {
                                viewModel.targetLUFS = -16.0
                                viewModel.truePeakLimit = -1.0
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)

                            Button("Podcast") {
                                viewModel.targetLUFS = -16.0
                                viewModel.truePeakLimit = -1.0
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 8) {
                            Button("Spotify") {
                                viewModel.targetLUFS = -14.0
                                viewModel.truePeakLimit = -2.0
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)

                            Button("Apple Music") {
                                viewModel.targetLUFS = -16.0
                                viewModel.truePeakLimit = -1.0
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
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
                        Text("What is LUFS?")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Text("LUFS = Loudness Units relative to Full Scale\n\n• Industry standard for perceived loudness\n• Ensures consistent volume across scenes\n• Platform-ready (YouTube, Instagram, etc.)\n• -16 LUFS = broadcast standard\n• -14 LUFS = social media standard")
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
                        Image(systemName: "waveform.and.magnifyingglass")
                    }
                    Text(viewModel.isProcessing ? viewModel.currentStage : "Process Audio")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isProcessing ? Color.gray : Color.blue)
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

            // LUFS Comparison
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("LUFS:")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f", viewModel.originalLUFS))
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        HStack {
                            Text("Peak:")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f dBTP", viewModel.originalPeak))
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Normalized")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("LUFS:")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f", viewModel.processedLUFS))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        HStack {
                            Text("Peak:")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f dBTP", viewModel.processedPeak))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }

            // Gain Applied
            if viewModel.normalizerEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Gain Applied", systemImage: "slider.horizontal.3")
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%+.1f dB", viewModel.appliedGain))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.appliedGain > 0 ? .green : .red)
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

            // A/B Comparison
            VStack(spacing: 16) {
                ComparisonCard(
                    title: "Original",
                    duration: viewModel.originalDuration,
                    rms: Float(viewModel.originalLUFS),
                    waveform: viewModel.originalWaveform,
                    isPlaying: viewModel.isPlayingOriginal,
                    onPlay: { viewModel.playOriginal() },
                    color: .gray
                )

                if viewModel.processedAudioURL != nil {
                    ComparisonCard(
                        title: viewModel.normalizerEnabled ? "Normalized" : "Bypassed",
                        duration: viewModel.processedDuration,
                        rms: Float(viewModel.processedLUFS),
                        waveform: viewModel.processedWaveform,
                        isPlaying: viewModel.isPlayingProcessed,
                        onPlay: { viewModel.playProcessed() },
                        color: viewModel.normalizerEnabled ? .blue : .gray
                    )
                }
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
    LUFSNormalizerDebugView()
}
