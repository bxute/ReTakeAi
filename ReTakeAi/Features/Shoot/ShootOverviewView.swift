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
            LazyVStack(alignment: .leading, spacing: 20) {
                if let project = viewModel.project {
                    progressSection(project: project)

                    scenesSection

                    exportSection(project: project)

                    if !project.exports.isEmpty {
                        previousExportsSection(project: project)
                    }
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
            Text("Scenes")
                .font(.headline)

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
                                    if scene.isComplete {
                                        Text("Complete")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.green)
                                    } else if scene.isRecorded {
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
                            }

                            Spacer(minLength: 0)

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
        }
    }

    private func exportSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export")
                .font(.headline)

            if viewModel.isReadyToExport {
                NavigationLink {
                    ExportView(project: project)
                } label: {
                    Label(project.exports.isEmpty ? "Export Final Video" : "Re-Export Video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Text(project.exports.isEmpty ? "All scenes recorded! Ready to export." : "Create a new export from the latest takes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Finish recording and selecting best takes to export.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func previousExportsSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous Exports")
                .font(.headline)

            ForEach(project.exports.sorted(by: { $0.exportedAt > $1.exportedAt })) { export in
                ShootExportRowView(export: export, onDelete: { viewModel.deleteExport(export) })
                Divider()
            }
        }
    }
}

private struct ShootExportRowView: View {
    let export: ExportedVideo
    let onDelete: () -> Void

    @State private var showingShareSheet = false
    @State private var showingPlayer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(export.formattedDate)
                        .font(.headline)
                    Text("\(export.aspect.title) • \(export.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button { showingPlayer = true } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Button { showingShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            Text(export.formattedSize)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showingPlayer) {
            NavigationStack {
                VideoPlayerView(videoURL: export.fileURL)
                    .navigationTitle("Exported Video")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingPlayer = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [export.fileURL])
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


