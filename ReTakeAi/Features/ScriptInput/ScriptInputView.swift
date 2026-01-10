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
        scriptEditor
        .navigationTitle("Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    let ok = viewModel.saveScript()
                    if ok {
                        dismiss()
                    }
                }
            }
        }
        .onAppear { viewModel.startAutoSave(every: 2.0) }
        .onDisappear { viewModel.stopAutoSave(); viewModel.saveScript() }
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
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            TextEditor(text: $viewModel.scriptText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            if viewModel.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Paste or type your script here…")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
    }
}
