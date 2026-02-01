//
//  SilenceAttenuatorDebugView.swift
//  ReTakeAi
//
//  Debug view for silence attenuator testing with A/B comparison
//

import SwiftUI
import UniformTypeIdentifiers

struct SilenceAttenuatorDebugView: View {
    @State private var viewModel = SilenceAttenuatorDebugViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // File Selection
                    fileSelectionSection

                    if viewModel.selectedAudioURL != nil {
                        // Attenuator Controls
                        attenuatorControlsSection

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
            .navigationTitle("Silence Attenuator Debug")
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

    // MARK: - Attenuator Controls

    private var attenuatorControlsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Attenuator Settings")
                    .font(.headline)
                Spacer()
                Image(systemName: "waveform.path")
                    .foregroundColor(.green)
            }

            // Enable Toggle
            Toggle("Enable Silence Attenuator", isOn: $viewModel.attenuatorEnabled)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding()
                .background(viewModel.attenuatorEnabled ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(12)

            if viewModel.attenuatorEnabled {
                // Attenuation Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Attenuation")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(viewModel.attenuation)) dB")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }

                    Slider(value: $viewModel.attenuation, in: -10...(-2), step: 0.5)
                        .tint(.green)

                    HStack {
                        Text("-10 dB (Maximum)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("-2 dB (Gentle)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("How much to reduce silence level")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)

                // Threshold Offset Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Threshold Offset")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("+\(Int(viewModel.thresholdOffset)) dB")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .fontWeight(.bold)
                    }

                    Slider(value: $viewModel.thresholdOffset, in: 4...12, step: 1)
                        .tint(.orange)

                    HStack {
                        Text("+4 dB (Sensitive)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+12 dB (Conservative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("dB above noise floor to detect voice")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(12)

                // Attack/Release
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Attack Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(viewModel.attackTime * 1000)) ms")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                    }

                    Slider(value: $viewModel.attackTime, in: 0.005...0.030, step: 0.001)
                        .tint(.blue)

                    Text("How fast to ramp down when entering silence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Release Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(viewModel.releaseTime * 1000)) ms")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                            .fontWeight(.bold)
                    }

                    Slider(value: $viewModel.releaseTime, in: 0.100...0.400, step: 0.010)
                        .tint(.purple)

                    Text("How slow to ramp up when exiting silence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(12)

                // Quick Presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Presets")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        Button("Gentle") {
                            viewModel.attenuation = -3.0
                            viewModel.thresholdOffset = 10.0
                            viewModel.attackTime = 0.015
                            viewModel.releaseTime = 0.250
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)

                        Button("Standard") {
                            viewModel.attenuation = -5.0
                            viewModel.thresholdOffset = 8.0
                            viewModel.attackTime = 0.012
                            viewModel.releaseTime = 0.200
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)

                        Button("Aggressive") {
                            viewModel.attenuation = -8.0
                            viewModel.thresholdOffset = 6.0
                            viewModel.attackTime = 0.010
                            viewModel.releaseTime = 0.150
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
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
                    Text("• Pure gain automation (no filters/EQ)\n• Adaptive threshold from noise floor\n• Voice untouched (0 dB gain)\n• Silence reduced by -5 dB\n• Smooth transitions prevent clicks")
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
                        Image(systemName: "waveform.path")
                    }
                    Text(viewModel.isProcessing ? viewModel.currentStage : "Process Audio")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isProcessing ? Color.gray : Color.green)
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

            // A/B Comparison
            VStack(spacing: 16) {
                // Original
                ComparisonCard(
                    title: "Original",
                    duration: viewModel.originalDuration,
                    rms: viewModel.originalRMS,
                    waveform: viewModel.originalWaveform,
                    isPlaying: viewModel.isPlayingOriginal,
                    onPlay: { viewModel.playOriginal() },
                    color: .gray
                )

                // Processed
                if viewModel.processedAudioURL != nil {
                    ComparisonCard(
                        title: viewModel.attenuatorEnabled ? "Attenuated" : "Bypassed",
                        duration: viewModel.processedDuration,
                        rms: viewModel.processedRMS,
                        waveform: viewModel.processedWaveform,
                        isPlaying: viewModel.isPlayingProcessed,
                        onPlay: { viewModel.playProcessed() },
                        color: viewModel.attenuatorEnabled ? .green : .gray
                    )
                }
            }

            // Metrics
            if viewModel.attenuatorEnabled && viewModel.processedRMS > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analysis")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Label("RMS Reduction", systemImage: "chart.line.downtrend.xyaxis")
                            .font(.caption)
                        Spacer()
                        let reduction = (viewModel.originalRMS - viewModel.processedRMS) / viewModel.originalRMS * 100
                        Text(String(format: "%.1f%%", reduction))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(reduction > 0 ? .green : .red)
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
    SilenceAttenuatorDebugView()
}
