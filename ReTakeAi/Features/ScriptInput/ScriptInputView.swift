//
//  ScriptInputView.swift
//  ReTakeAi
//

import SwiftUI

struct ScriptInputView: View {
    let project: Project
    @State private var viewModel: ScriptInputViewModel
    @State private var showRecordingFlow = false
    @State private var confirmedProject: Project?
    @Environment(\.dismiss) private var dismiss
    
    init(project: Project) {
        self.project = project
        _viewModel = State(initialValue: ScriptInputViewModel(project: project))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.scenesConfirmed {
                readyToRecordView
            } else if viewModel.hasGeneratedScenes {
                scenesPreview
            } else {
                scriptEditor
            }
        }
        .navigationTitle("Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.scenesConfirmed {
                    EmptyView()
                } else if viewModel.hasGeneratedScenes {
                    Button("Confirm") {
                        Task {
                            let success = await viewModel.confirmScenes()
                            if success {
                                confirmedProject = ProjectStore.shared.getProject(by: project.id)
                            }
                        }
                    }
                } else {
                    Button("Generate Scenes") {
                        Task {
                            await viewModel.generateScenes()
                        }
                    }
                    .disabled(!viewModel.canGenerateScenes || viewModel.isGeneratingScenes)
                }
            }
        }
        .navigationDestination(isPresented: $showRecordingFlow) {
            if let proj = confirmedProject,
               let firstScene = SceneStore.shared.getScenes(for: proj).first {
                RecordingView(project: proj, scene: firstScene)
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
    
    private var scriptEditor: some View {
        VStack(spacing: 16) {
            TextEditor(text: $viewModel.scriptText)
                .font(.body)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            if viewModel.isGeneratingScenes {
                LoadingView(message: "Generating scenes...")
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var scenesPreview: some View {
        List {
            Section {
                Text("Review the generated scenes. Tap Confirm to proceed to recording.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ForEach(Array(viewModel.generatedScenes.enumerated()), id: \.element.id) { index, scene in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scene \(index + 1)")
                        .font(.headline)
                    
                    Text(scene.scriptText)
                        .font(.body)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var readyToRecordView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("Scenes Created!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("\(viewModel.generatedScenes.count) scenes ready for recording")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                Button {
                    showRecordingFlow = true
                } label: {
                    Label("Start Recording", systemImage: "video.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Record Later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}
