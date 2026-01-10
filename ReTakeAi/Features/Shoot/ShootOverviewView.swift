//
//  ShootOverviewView.swift
//  ReTakeAi
//

import SwiftUI

struct ShootOverviewView: View {
    let projectID: UUID
    @State private var viewModel: ShootOverviewViewModel

    @State private var selectedSceneForRecording: VideoScene?

    init(projectID: UUID) {
        self.projectID = projectID
        _viewModel = State(initialValue: ShootOverviewViewModel(projectID: projectID))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if let project = viewModel.project {
                    progressSection(project: project)

                    scenesSection
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .navigationTitle("Shoot")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.load()
        }
        .fullScreenCover(item: $selectedSceneForRecording, onDismiss: {
            viewModel.load()
        }) { scene in
            if let project = viewModel.project {
                NavigationStack {
                    RecordingView(project: project, scene: scene)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
    }

    private func progressSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recording Progress")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.recordedScenesCount)/\(viewModel.scenes.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(viewModel.recordedScenesCount), total: Double(max(viewModel.scenes.count, 1)))
                .tint(viewModel.recordedScenesCount == viewModel.scenes.count ? .green : .blue)

            if let next = viewModel.nextSceneToRecord {
                Button {
                    selectedSceneForRecording = next
                } label: {
                    Label("Go to Shoot Scene \(next.orderIndex + 1)", systemImage: "video.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else if !viewModel.scenes.isEmpty {
                Text("All scenes have at least one take.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("No scenes yet. Generate scenes first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Scenes to Shoot")
                    .font(.title3.weight(.semibold))
                Text("Review takes, mark a preferred take, and jump back into recording.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.scenes.isEmpty {
                Text("Generate scenes to start shooting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.scenes.sorted(by: { $0.orderIndex < $1.orderIndex })) { scene in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Scene \(scene.orderIndex + 1)")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if scene.isRecorded {
                                        Text("Recorded")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.blue)
                                    } else {
                                        Text("Not recorded")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(scene.scriptText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)

                                let takes = viewModel.getTakes(for: scene)
                                HStack(spacing: 10) {
                                    Text("\(takes.count) take\(takes.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let best = viewModel.bestTake(for: scene) {
                                        HStack(spacing: 6) {
                                            Image(systemName: scene.selectedTakeID == best.id ? "checkmark.circle.fill" : "sparkles")
                                                .font(.caption)
                                                .foregroundStyle(scene.selectedTakeID == best.id ? .green : .secondary)
                                            Text("Best: Take \(best.takeNumber)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: 0)

                            NavigationLink {
                                ShootSceneDetailView(projectID: projectID, sceneID: scene.id)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)

                            Button {
                                selectedSceneForRecording = scene
                            } label: {
                                Image(systemName: "video.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }

                        let takes = viewModel.getTakes(for: scene)
                        if !takes.isEmpty {
                            Divider().opacity(0.4)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(takes.sorted(by: { $0.takeNumber < $1.takeNumber })) { take in
                                    ShootTakeRowView(
                                        take: take,
                                        isSelected: scene.selectedTakeID == take.id
                                    )
                                }
                            }
                        }
                    }
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                }
            }

            NavigationLink {
                ShootExportsView(projectID: projectID)
            } label: {
                Label("Go to Exports", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

private struct ShootTakeRowView: View {
    let take: Take
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(spacing: 6) {
                Text("Take \(take.takeNumber)")
                    .font(.footnote.weight(.semibold))

                if isSelected {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }

            Spacer(minLength: 0)

            Text(take.duration.shortDuration)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(take.recordedAt.timeAgo)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}


