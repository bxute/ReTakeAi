//
//  AudioProcessorTestView.swift
//  ReTakeAi
//
//  Test bed for audio processors
//

import SwiftUI
import UniformTypeIdentifiers

struct AudioProcessorTestView: View {
    @State private var viewModel: AudioProcessorTestViewModel?
    @State private var showFilePicker = false
    @State private var showPresetPicker = false
    @State private var loadError: String?
    @State private var showSilenceAttenuatorDebug = false
    @State private var showLUFSNormalizerDebug = false

    var body: some View {
        Group {
            if let error = loadError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Failed to Load")
                        .font(.title)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if let viewModel = viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView("Initializing Audio Engine...")
                    .onAppear {
                        Task {
                            do {
                                // Initialize viewModel with error handling
                                try await Task.sleep(nanoseconds: 100_000_000) // Small delay
                                await MainActor.run {
                                    self.viewModel = AudioProcessorTestViewModel()
                                }
                            } catch {
                                await MainActor.run {
                                    self.loadError = "Initialization failed: \(error.localizedDescription)"
                                }
                            }
                        }
                    }
            }
        }
        .navigationTitle("Audio Processor Test")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let viewModel = viewModel {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Debug screens
                        Button(action: { showSilenceAttenuatorDebug = true }) {
                            Label("Silence Attenuator Debug", systemImage: "waveform.path")
                        }

                        Button(action: { showLUFSNormalizerDebug = true }) {
                            Label("LUFS Normalizer Debug", systemImage: "waveform.and.magnifyingglass")
                        }

                        Divider()

                        // Stop playback
                        Button(action: {
                            viewModel.stopOriginal()
                            viewModel.stopProcessed()
                        }) {
                            Label("Stop Playback", systemImage: "stop.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showSilenceAttenuatorDebug) {
            SilenceAttenuatorDebugView()
        }
        .sheet(isPresented: $showLUFSNormalizerDebug) {
            LUFSNormalizerDebugView()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if let viewModel = viewModel {
                handleFileSelection(result, viewModel: viewModel)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.showError ?? false },
            set: { if viewModel != nil { viewModel!.showError = $0 } }
        )) {
            Button("OK") { }
        } message: {
            Text(viewModel?.errorMessage ?? "Unknown error")
        }
        .alert("Files Saved", isPresented: Binding(
            get: { viewModel?.showSavedMessage ?? false },
            set: { if viewModel != nil { viewModel!.showSavedMessage = $0 } }
        )) {
            Button("OK") { }
        } message: {
            Text(viewModel?.savedFilesMessage ?? "Files saved successfully")
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showShareSheet ?? false },
            set: { if viewModel != nil { viewModel!.showShareSheet = $0 } }
        )) {
            if let viewModel = viewModel {
                AudioFilesShareSheet(items: viewModel.filesToShare)
            }
        }
    }

    @ViewBuilder
    private func contentView(viewModel: AudioProcessorTestViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // File Selection
                fileSelectionSection(viewModel: viewModel)

                if viewModel.selectedAudioURL != nil {
                    // Processor Selection
                    processorSelectionSection(viewModel: viewModel)

                    // RNNoise Controls (if enabled)
                    if viewModel.enabledProcessors["rnnoise"] == true {
                        rnnoiseControlsSection(viewModel: viewModel)
                    }

                    // Quick Presets
                    presetSection(viewModel: viewModel)

                    // Process Button
                    processButton(viewModel: viewModel)

                    // Results
                    if viewModel.originalAudioURL != nil {
                        resultsSection(viewModel: viewModel)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - File Selection Section

    private func fileSelectionSection(viewModel: AudioProcessorTestViewModel) -> some View {
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

    // MARK: - Processor Selection Section

    private func processorSelectionSection(viewModel: AudioProcessorTestViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Processors")
                    .font(.headline)

                Spacer()

                Button("Select All") {
                    for key in viewModel.enabledProcessors.keys {
                        viewModel.enabledProcessors[key] = true
                    }
                }
                .font(.caption)

                Button("Clear All") {
                    for key in viewModel.enabledProcessors.keys {
                        viewModel.enabledProcessors[key] = false
                    }
                }
                .font(.caption)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.processorInfo, id: \.id) { info in
                    ProcessorRow(
                        name: info.name,
                        description: info.description,
                        isEnabled: Binding(
                            get: { viewModel.enabledProcessors[info.id] ?? false },
                            set: { viewModel.enabledProcessors[info.id] = $0 }
                        )
                    )
                }
            }
        }
    }

    // MARK: - RNNoise Controls Section

    private func rnnoiseControlsSection(viewModel: AudioProcessorTestViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RNNoise Settings")
                    .font(.headline)
                Spacer()
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.green)
            }

            // Strength Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Noise Reduction Strength")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int((viewModel.processorConfigs["rnnoise"]?["strength"] as? Float ?? 0.7) * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }

                Slider(
                    value: Binding(
                        get: {
                            Double(viewModel.processorConfigs["rnnoise"]?["strength"] as? Float ?? 0.7)
                        },
                        set: { newValue in
                            if var config = viewModel.processorConfigs["rnnoise"] {
                                config["strength"] = Float(newValue)
                                viewModel.processorConfigs["rnnoise"] = config
                            }
                        }
                    ),
                    in: 0.3...1.0,
                    step: 0.05
                )
                .tint(.green)

                HStack {
                    Text("30% (Light)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100% (Aggressive)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Quick presets
                HStack(spacing: 8) {
                    Button("Light (50%)") {
                        if var config = viewModel.processorConfigs["rnnoise"] {
                            config["strength"] = Float(0.5)
                            config["voicePreserve"] = Float(0.9)
                            viewModel.processorConfigs["rnnoise"] = config
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)

                    Button("Standard (70%)") {
                        if var config = viewModel.processorConfigs["rnnoise"] {
                            config["strength"] = Float(0.7)
                            config["voicePreserve"] = Float(0.85)
                            viewModel.processorConfigs["rnnoise"] = config
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)

                    Button("Aggressive (90%)") {
                        if var config = viewModel.processorConfigs["rnnoise"] {
                            config["strength"] = Float(0.9)
                            config["voicePreserve"] = Float(0.7)
                            viewModel.processorConfigs["rnnoise"] = config
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)

            // Voice Preserve Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Voice Preservation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int((viewModel.processorConfigs["rnnoise"]?["voicePreserve"] as? Float ?? 0.85) * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.bold)
                }

                Slider(
                    value: Binding(
                        get: {
                            Double(viewModel.processorConfigs["rnnoise"]?["voicePreserve"] as? Float ?? 0.85)
                        },
                        set: { newValue in
                            if var config = viewModel.processorConfigs["rnnoise"] {
                                config["voicePreserve"] = Float(newValue)
                                viewModel.processorConfigs["rnnoise"] = config
                            }
                        }
                    ),
                    in: 0.5...1.0,
                    step: 0.05
                )
                .tint(.orange)

                HStack {
                    Text("More Noise Removal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Safer for Voice")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Higher values preserve voice naturalness but may leave more background noise")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(12)

            // Info box
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("How It Works")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                Text("• Frame-based processing @ 16 kHz\n• Spectral noise suppression\n• Voice-adaptive gating\n• Preserves speech clarity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Preset Section

    private func presetSection(viewModel: AudioProcessorTestViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Presets (Coming Soon)")
                .font(.headline)

            Text("Presets will be available once audio processors are implemented")
                .font(.caption)
                .foregroundColor(.secondary)

            // TODO: Uncomment when audio engine is ready
            /*
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    PresetButton(name: "Studio Voice", icon: "mic") {
                        // TODO: Load preset
                    }

                    PresetButton(name: "Podcast Pro", icon: "waveform") {
                        // TODO: Load preset
                    }

                    PresetButton(name: "Clear Narration", icon: "text.bubble") {
                        // TODO: Load preset
                    }

                    PresetButton(name: "Cinematic", icon: "film") {
                        // TODO: Load preset
                    }

                    PresetButton(name: "Clean & Natural", icon: "leaf") {
                        // TODO: Load preset
                    }
                }
                .padding(.vertical, 4)
            }
            */
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Process Button

    private func processButton(viewModel: AudioProcessorTestViewModel) -> some View {
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
                        Image(systemName: "waveform.circle.fill")
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

    // MARK: - Results Section

    private func resultsSection(viewModel: AudioProcessorTestViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            Text("Results")
                .font(.headline)

            // Waveform Comparison
            VStack(spacing: 16) {
                WaveformView(
                    samples: viewModel.originalWaveform,
                    color: .gray,
                    label: "Original Audio"
                )

                WaveformView(
                    samples: viewModel.processedWaveform,
                    color: .green,
                    label: "Processed Audio"
                )
            }

            // Playback Controls
            HStack(spacing: 16) {
                // Original Audio
                AudioPlayerCard(
                    title: "Original",
                    duration: viewModel.originalDuration,
                    isPlaying: viewModel.isPlayingOriginal,
                    onPlay: { viewModel.playOriginal() },
                    color: .gray
                )

                // Processed Audio
                AudioPlayerCard(
                    title: "Processed",
                    duration: viewModel.processedDuration,
                    isPlaying: viewModel.isPlayingProcessed,
                    onPlay: { viewModel.playProcessed() },
                    color: .green
                )
            }

            // Save Files Button
            Button(action: {
                viewModel.saveProcessedAudio()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Files for Offline Comparison")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Text("Export to Files app, iCloud Drive, or save locally")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func handleFileSelection(_ result: Result<[URL], Error>, viewModel: AudioProcessorTestViewModel) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                viewModel.selectedAudioURL = url
                viewModel.originalAudioURL = nil
                viewModel.processedAudioURL = nil
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
            viewModel.showError = true
        }
    }
}

// MARK: - Processor Row

struct ProcessorRow: View {
    let name: String
    let description: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let name: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 100, height: 80)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Audio Player Card

struct AudioPlayerCard: View {
    let title: String
    let duration: TimeInterval
    let isPlaying: Bool
    let onPlay: () -> Void
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Button(action: onPlay) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(color)
            }
            .buttonStyle(.plain)

            Text(formatDuration(duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Files Share Sheet

struct AudioFilesShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

// MARK: - Preview

#Preview {
    AudioProcessorTestView()
}
