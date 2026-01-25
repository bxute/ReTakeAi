//
//  ScriptInputView.swift
//  ReTakeAi
//

import SwiftUI

struct ScriptInputView: View {
    let project: Project
    @State private var viewModel: ScriptInputViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool
    @State private var hasEverSavedInSession = false
    @State private var showingClearDraftConfirm = false
    private let autosaveTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    init(project: Project) {
        self.project = project
        _viewModel = State(initialValue: ScriptInputViewModel(project: project))
    }
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                hintBanner
                
                scriptEditor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Edit Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(AppTheme.Colors.cta)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard viewModel.isDirty else { return }
                    let ok = viewModel.saveScript()
                    if ok {
                        hasEverSavedInSession = true
                    }
                } label: {
                    Text(saveButtonTitle)
                }
                .disabled(!viewModel.isDirty)
                .foregroundStyle(viewModel.isDirty ? AppTheme.Colors.cta : AppTheme.Colors.textTertiary)
            }
        }
        .alert("Clear draft?", isPresented: $showingClearDraftConfirm) {
            Button("Clear", role: .destructive) {
                viewModel.scriptText = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the current draft text.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isEditorFocused {
                helperActions
            }
        }
        .onReceive(autosaveTimer) { _ in
            Task { @MainActor in
                let didSave = await viewModel.autoSaveIfNeeded()
                if didSave {
                    hasEverSavedInSession = true
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                isEditorFocused = true
            }
        }
        .onDisappear {
            viewModel.cancelAutoSave()
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
        ZStack(alignment: .topLeading) {
            TextEditor(text: $viewModel.scriptText)
                .focused($isEditorFocused)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.background)
            
            if viewModel.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(
                    """
                    Start typing or paste your script here…
                    You can write rough notes, full paragraphs,
                    or unstructured thoughts.
                    """
                )
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .allowsHitTesting(false)
            }
        }
    }

    private var hintBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Paste or write freely — we'll break this into scenes later.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var saveButtonTitle: String {
        if viewModel.isDirty { return "Save" }
        return hasEverSavedInSession ? "Saved" : "Save"
    }
    
    private var helperActions: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AppTheme.Colors.border.opacity(0.7))
            
            HStack {
                Button("Clear draft") {
                    showingClearDraftConfirm = true
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.background)
        }
    }
}
