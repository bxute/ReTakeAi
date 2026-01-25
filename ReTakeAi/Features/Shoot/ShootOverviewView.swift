//
//  ShootOverviewView.swift
//  ReTakeAi
//

import SwiftUI

struct ShootOverviewView: View {
    let projectID: UUID
    @State private var viewModel: ShootOverviewViewModel

    @State private var selectedSceneForRecording: VideoScene?
    @State private var selectedSceneForDetails: VideoScene?

    init(projectID: UUID) {
        self.projectID = projectID
        _viewModel = State(initialValue: ShootOverviewViewModel(projectID: projectID))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if viewModel.project != nil {
                        scenesSection
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .padding(.bottom, 80) // Space for sticky CTA
            }

            // Sticky bottom CTA
            if !viewModel.scenes.isEmpty {
                stickyBottomCTA
            }
        }
        .navigationTitle("Scene Shoot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Scene Shoot")
                        .font(.headline)
                    Text("\(viewModel.scenes.count) scenes • \(viewModel.recordedScenesCount) recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationDestination(item: $selectedSceneForDetails) { scene in
            ShootSceneDetailView(projectID: projectID, sceneID: scene.id)
        }
        .onAppear {
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sceneDidUpdate)) { _ in
            viewModel.load()
        }
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

    // MARK: - Sticky Bottom CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                if let nextScene = viewModel.nextSceneToRecord {
                    Button {
                        selectedSceneForRecording = nextScene
                    } label: {
                        Label("Record Next Scene", systemImage: "video.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)
                } else {
                    NavigationLink {
                        PreviewScreen(projectID: projectID)
                    } label: {
                        Label("Review & Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    // MARK: - Scenes Section

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.scenes.isEmpty {
                Text("Generate scenes to start shooting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.scenes.sorted(by: { $0.orderIndex < $1.orderIndex })) { scene in
                    sceneCard(for: scene)
                }
            }
        }
    }

    // MARK: - Scene Card

    private func sceneCard(for scene: VideoScene) -> some View {
        let takes = viewModel.getTakes(for: scene)
        let best = viewModel.bestTake(for: scene)
        let isRecorded = scene.isRecorded

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail: Only show for recorded scenes
                if isRecorded, let best {
                    VideoThumbnailView(
                        videoURL: best.fileURL,
                        isPortrait: best.resolution.height > best.resolution.width,
                        durationText: nil
                    )
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Header: Status dot + Scene title + duration + action button
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        // Status indicator dot
                        Circle()
                            .fill(isRecorded ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)

                        Text("Scene \(scene.orderIndex + 1)")
                            .font(.subheadline.weight(.semibold))

                        if let duration = scene.duration {
                            Text("\(Int(duration))s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Action button: different for recorded vs unrecorded
                        if isRecorded {
                            Button {
                                selectedSceneForRecording = scene
                            } label: {
                                Text("Retake")
                                    .font(.caption2.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(.secondary)
                        } else {
                            Button {
                                selectedSceneForRecording = scene
                            } label: {
                                Text("Record Scene")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.red)
                        }
                    }

                    // Script preview
                    Text(scene.scriptText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    // Takes info: Only show for recorded scenes
                    if isRecorded {
                        HStack(spacing: 6) {
                            Text("Takes: \(takes.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let best {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                Text("Best: #\(best.takeNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                Text(best.duration.shortDuration)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isRecorded ? Color.green.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isRecorded ? Color.green.opacity(0.3) : Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSceneForDetails = scene
        }
    }
}

