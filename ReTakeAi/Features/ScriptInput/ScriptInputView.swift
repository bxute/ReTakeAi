//
//  ScriptInputView.swift
//  ReTakeAi
//

import SwiftUI

struct ScriptInputView: View {
    let project: Project
    @State private var viewModel: ScriptInputViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(project: Project) {
        self.project = project
        _viewModel = State(initialValue: ScriptInputViewModel(project: project))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasGeneratedScenes {
                scenesPreview
            } else {
                scriptEditor
            }
        }
        .navigationTitle("Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.hasGeneratedScenes {
                    Button("Confirm") {
                        Task {
                            let ok = await viewModel.confirmScenes()
                            if ok {
                                // Return to Project Detail so the user can see scenes/takes and start recording per scene.
                                dismiss()
                            }
                        }
                    }
                } else {
                    Button("Generate Scenes") {
                        Task {
                            viewModel.saveScript()
                            await viewModel.generateScenes()
                        }
                    }
                    .disabled(!viewModel.canGenerateScenes || viewModel.isGeneratingScenes)
                }
            }
        }
        .onDisappear {
            // Persist whatever the user typed even if they leave without confirming.
            viewModel.saveScript()
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
}
