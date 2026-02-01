//
//  ExportView.swift
//  SceneFlow
//

import SwiftUI

struct ExportView: View {
    let project: Project
    @State private var viewModel: ExportViewModel
    @State private var showingShareSheet = false
    
    init(project: Project) {
        self.project = project
        _viewModel = State(initialValue: ExportViewModel(project: project))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isExporting {
                exportingView
            } else if let exportedURL = viewModel.exportedURL {
                exportedView(url: exportedURL)
            } else {
                readyToExportView
            }
        }
        .padding()
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = viewModel.exportedURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private var readyToExportView: some View {
        VStack(spacing: 30) {
            Image(systemName: "film.stack")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            Text("Ready to Export")
                .font(.title2)
                .fontWeight(.semibold)

            let info = viewModel.getExportInfo()

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Scenes", value: "\(info.sceneCount)")
                InfoRow(label: "Duration", value: info.formattedDuration)
                InfoRow(label: "Est. Size", value: info.formattedSize)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Audio Processing Settings
            audioProcessingSection

            Button {
                Task {
                    await viewModel.exportVideo()
                }
            } label: {
                Label("Export Video", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canExport())
        }
    }

    private var audioProcessingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Audio Enhancement", systemImage: "waveform")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $viewModel.audioProcessingEnabled)
                    .labelsHidden()
            }

            if viewModel.audioProcessingEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Processing Preset")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Audio Preset", selection: $viewModel.selectedAudioPreset) {
                        ForEach(viewModel.availablePresets, id: \.self) { presetName in
                            Text(presetName).tag(presetName)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Show preset description
                    Text(AudioPresets.description(for: viewModel.selectedAudioPreset))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var exportingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.exportProgress)
                .progressViewStyle(.linear)

            Text(viewModel.exportingStage.isEmpty ? "Exporting..." : viewModel.exportingStage)
                .font(.headline)

            Text("\(Int(viewModel.exportProgress * 100))% complete")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func exportedView(url: URL) -> some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
            
            Text("Export Complete!")
                .font(.title2)
                .fontWeight(.semibold)
            
            VideoPlayerView(videoURL: url)
                .frame(height: 300)
                .cornerRadius(12)
            
            VStack(spacing: 12) {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("Share Video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    Task {
                        await viewModel.saveToPhotoLibrary()
                    }
                } label: {
                    Label("Save to Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
