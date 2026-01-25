//
//  SceneBreakdownReviewView.swift
//  ReTakeAi
//

import SwiftUI

struct SceneBreakdownReviewView: View {
    @State private var viewModel: SceneBreakdownReviewViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingDraft: GeneratedSceneDraft?
    @State private var showingRegenerateConfirm = false
    @State private var expandedSceneID: UUID?
    @State private var isDirectionExpanded = false
    @State private var showingShoot = false
    
    // Reorder mode
    @State private var isReorderMode = false
    @State private var reorderedDrafts: [GeneratedSceneDraft] = []

    init(projectID: UUID, mode: SceneBreakdownReviewViewModel.Mode) {
        _viewModel = State(initialValue: SceneBreakdownReviewViewModel(projectID: projectID, mode: mode))
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingStateView
                } else if viewModel.drafts.isEmpty {
                    emptyStateView
                } else {
                    scenesContent
                }
            }
        }
        .navigationTitle(isReorderMode ? "Reorder Scenes" : "Scenes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(AppTheme.Colors.cta)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isReorderMode {
                    Button("Done") {
                        saveReorderedDrafts()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.cta)
                } else {
                    Menu {
                        Button {
                            enterReorderMode()
                        } label: {
                            Label("Reorder Scenes", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Button {
                            showingRegenerateConfirm = true
                        } label: {
                            Label("Regenerate Scenes", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            
            if isReorderMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        exitReorderMode()
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $editingDraft) { draft in
            SceneDraftEditorSheet(
                draft: draft,
                onSave: { updated in
                    Task {
                        _ = await viewModel.saveEditedDraft(updated)
                    }
                }
            )
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .alert("Regenerate Scenes?", isPresented: $showingRegenerateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate", role: .destructive) {
                Task {
                    expandedSceneID = nil
                    await viewModel.regenerateScenesReplacingScriptAndScenes()
                }
            }
        } message: {
            Text("This will replace all current scenes. Your edits will be lost.")
        }
        .navigationDestination(isPresented: $showingShoot) {
            ShootOverviewView(projectID: viewModel.projectID)
        }
    }
    
    // MARK: - Scenes Content
    
    private var scenesContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if isReorderMode {
                        // Reorder mode
                        ForEach(Array(reorderedDrafts.enumerated()), id: \.element.id) { index, draft in
                            reorderableDraftRow(for: draft, at: index)
                        }
                    } else {
                        // Normal mode
                        // Header
                        headerSection
                        
                        // Project Direction Card
                        if let direction = viewModel.projectDirection {
                            DirectionCard(
                                direction: direction,
                                isExpanded: $isDirectionExpanded
                            )
                        }
                        
                        // Regenerate button (de-emphasized)
                        regenerateButton
                        
                        // Scene Cards
                        ForEach(sortedDrafts) { draft in
                            SceneCard(
                                draft: draft,
                                isExpanded: expandedSceneID == draft.id,
                                onTap: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        if expandedSceneID == draft.id {
                                            expandedSceneID = nil
                                        } else {
                                            expandedSceneID = draft.id
                                        }
                                    }
                                },
                                onEditNarration: {
                                    editingDraft = draft
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100) // Space for sticky CTA
            }
            .scrollIndicators(.hidden)
            
            // Sticky Bottom CTA (hide in reorder mode)
            if !isReorderMode {
                stickyBottomCTA
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.projectTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text(metadataText)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
    
    private var metadataText: String {
        let count = viewModel.drafts.count
        let totalDuration = viewModel.drafts.reduce(0) { $0 + $1.expectedDurationSeconds }
        let toneText = viewModel.projectDirection?.tone.rawValue ?? "Professional"
        return "\(count) scenes • ~\(totalDuration)s • \(toneText)"
    }
    
    // MARK: - Regenerate Button
    
    private var regenerateButton: some View {
        Button {
            showingRegenerateConfirm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                Text("Regenerate all scenes")
                    .font(.subheadline)
            }
            .foregroundStyle(AppTheme.Colors.textTertiary)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
    
    // MARK: - Sticky Bottom CTA
    
    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppTheme.Colors.border)
            
            Button {
                showingShoot = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.body.weight(.semibold))
                    Text("Go to Shoot")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.cta)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.background)
        }
    }
    
    // MARK: - Loading State
    
    private var loadingStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.Colors.cta)
                    .symbolEffect(.pulse)
                
                Text("Creating scenes...")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                LoadingStep(text: "Analyzing your script", state: .completed)
                LoadingStep(text: "Structuring into scenes", state: .inProgress)
                LoadingStep(text: "Adding delivery guidance", state: .pending)
                LoadingStep(text: "Finalizing", state: .pending)
            }
            .padding(.horizontal, 40)
            
            Text("Usually takes a few seconds")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            VStack(spacing: 8) {
                Text("Add a script to generate scenes")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text("Write or paste your script first")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Write Script")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.cta)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private var sortedDrafts: [GeneratedSceneDraft] {
        viewModel.drafts.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    // MARK: - Reorder Mode
    
    private func reorderableDraftRow(for draft: GeneratedSceneDraft, at index: Int) -> some View {
        let isFirst = index == 0
        let isLast = index == reorderedDrafts.count - 1
        
        return HStack(spacing: 12) {
            // Move buttons
            VStack(spacing: 0) {
                Button {
                    moveDraft(at: index, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isFirst ? AppTheme.Colors.textTertiary.opacity(0.3) : AppTheme.Colors.textSecondary)
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
                .disabled(isFirst)
                
                Button {
                    moveDraft(at: index, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isLast ? AppTheme.Colors.textTertiary.opacity(0.3) : AppTheme.Colors.textSecondary)
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
                .disabled(isLast)
            }
            
            // Scene info
            VStack(alignment: .leading, spacing: 4) {
                Text("Scene \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(draft.narrationScript)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                
                Text("~\(draft.expectedDurationSeconds)s")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
    
    private func moveDraft(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < reorderedDrafts.count else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            reorderedDrafts.swapAt(index, newIndex)
        }
    }
    
    private func enterReorderMode() {
        reorderedDrafts = sortedDrafts
        withAnimation(.easeInOut(duration: 0.2)) {
            isReorderMode = true
        }
    }
    
    private func exitReorderMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isReorderMode = false
        }
        reorderedDrafts = []
    }
    
    private func saveReorderedDrafts() {
        // Update orderIndex for each draft based on new position
        Task {
            for (index, draft) in reorderedDrafts.enumerated() {
                if draft.orderIndex != index {
                    var updated = draft
                    updated.orderIndex = index
                    _ = await viewModel.saveEditedDraft(updated)
                }
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isReorderMode = false
                }
                reorderedDrafts = []
            }
        }
    }
}

// MARK: - Loading Step

private struct LoadingStep: View {
    let text: String
    let state: StepState
    
    enum StepState {
        case pending, inProgress, completed
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch state {
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.success)
                case .inProgress:
                    Image(systemName: "circle.dotted")
                        .foregroundStyle(AppTheme.Colors.cta)
                        .symbolEffect(.pulse)
                case .pending:
                    Image(systemName: "circle")
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .font(.body)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(state == .pending ? AppTheme.Colors.textTertiary : AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Direction Card

private struct DirectionCard: View {
    let direction: AIDirection
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "theatermasks.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.cta)
                        
                        Text("Delivery Direction")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(direction.delivery)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        
                        Text(direction.actorInstructions)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                } else {
                    Text(direction.delivery)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scene Card

private struct SceneCard: View {
    let draft: GeneratedSceneDraft
    let isExpanded: Bool
    let onTap: () -> Void
    let onEditNarration: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack {
                    Text("Scene \(draft.orderIndex + 1)")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    
                    Text("\(draft.expectedDurationSeconds)s")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.Colors.border.opacity(0.5))
                        .clipShape(Capsule())
                }
                .padding(16)
                
                if isExpanded {
                    expandedContent
                } else {
                    // Collapsed: narration preview only
                    Text(draft.scriptText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isExpanded ? AppTheme.Colors.cta.opacity(0.5) : AppTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .background(AppTheme.Colors.border)
            
            // Narration section
            VStack(alignment: .leading, spacing: 6) {
                Text("NARRATION")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Text(draft.scriptText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            
            // Direction section
            if let direction = draft.direction {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DIRECTION")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    
                    Text("\(direction.tone.rawValue) • \(direction.delivery)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    Text(direction.actorInstructions)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
            }
            
            Divider()
                .background(AppTheme.Colors.border)
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onEditNarration()
                } label: {
                    Text("Edit Narration")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.cta)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.Colors.cta.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Editor Sheet

private struct SceneDraftEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: GeneratedSceneDraft
    let onSave: (GeneratedSceneDraft) -> Void

    init(draft: GeneratedSceneDraft, onSave: @escaping (GeneratedSceneDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Duration control
                            HStack {
                                Text("Expected duration")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Spacer()
                                HStack(spacing: 12) {
                                    Button {
                                        if draft.expectedDurationSeconds > 1 {
                                            draft.expectedDurationSeconds -= 1
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(AppTheme.Colors.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Text("\(draft.expectedDurationSeconds)s")
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                        .frame(width: 50)
                                    
                                    Button {
                                        if draft.expectedDurationSeconds < 600 {
                                            draft.expectedDurationSeconds += 1
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(AppTheme.Colors.cta)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            // Direction display
                            if let direction = draft.direction {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Direction")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                        Spacer()
                                        Text(direction.tone.rawValue)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.cta)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.Colors.cta.opacity(0.15))
                                            .clipShape(Capsule())
                                    }

                                    Text(direction.delivery)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Colors.textSecondary)

                                    Text(direction.actorInstructions)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(16)
                                .background(AppTheme.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            // Narration editor
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Narration")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                
                                TextEditor(text: $draft.scriptText)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 200)
                                    .padding(12)
                                    .background(AppTheme.Colors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Edit Scene \(draft.orderIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.cta)
                    .disabled(draft.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(AppTheme.Colors.cta)
    }
}

