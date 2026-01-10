//
//  SceneBreakdownReviewView.swift
//  ReTakeAi
//

import SwiftUI

struct SceneBreakdownReviewView: View {
    @State private var viewModel: SceneBreakdownReviewViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingDraft: GeneratedSceneDraft?
    @State private var showingPrompt = false

    init(projectID: UUID, mode: SceneBreakdownReviewViewModel.Mode) {
        _viewModel = State(initialValue: SceneBreakdownReviewViewModel(projectID: projectID, mode: mode))
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let projectDirection = viewModel.projectDirection {
                        ProjectDirectionHeader(direction: projectDirection)
                    }

                    if let prompt = viewModel.promptUsed {
                        DisclosureGroup(isExpanded: $showingPrompt) {
                            Text(prompt)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        } label: {
                            Text("Prompt used")
                                .font(.headline)
                        }
                        .padding(.vertical, 4)
                    }

                    if viewModel.drafts.isEmpty, !viewModel.isLoading {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No scenes yet")
                                .font(.headline)
                            Text("Generate scenes from your script, then review and edit each scene.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    } else {
                        ForEach(viewModel.drafts.sorted(by: { $0.orderIndex < $1.orderIndex })) { draft in
                            SceneDraftCard(
                                draft: draft,
                                onTap: { editingDraft = draft }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Working…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Scenes")
        .navigationBarTitleDisplayMode(.inline)
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
    }
}

private struct ProjectDirectionHeader: View {
    let direction: AIDirection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Project direction")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(direction.delivery)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                Spacer()
                Text(direction.tone.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.10), in: Capsule())
            }

            Text(direction.actorInstructions)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Divider().opacity(0.0)
            }
        )
    }
}

private struct SceneDraftCard: View {
    let draft: GeneratedSceneDraft
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Scene \(draft.orderIndex + 1)")
                        .font(.headline)
                    Spacer()
                    Text("\(draft.expectedDurationSeconds)s")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.10), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Narration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(draft.scriptText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let direction = draft.direction {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Direction")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("\(direction.tone.rawValue) • \(direction.delivery)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(direction.actorInstructions)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                HStack {
                    Text("Tap to edit")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

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
            VStack(spacing: 12) {
                HStack {
                    Text("Expected duration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper("\(draft.expectedDurationSeconds)s", value: $draft.expectedDurationSeconds, in: 1...600)
                        .labelsHidden()
                    Text("\(draft.expectedDurationSeconds)s")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal)

                if let direction = draft.direction {
                    VStack(alignment: .leading, spacing: 6) {
                        Divider()
                        HStack {
                            Text("Direction")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(direction.tone.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }

                        Text(direction.delivery)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(direction.actorInstructions)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                }

                Divider()

                TextEditor(text: $draft.scriptText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)

                Spacer(minLength: 0)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Edit Scene \(draft.orderIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


