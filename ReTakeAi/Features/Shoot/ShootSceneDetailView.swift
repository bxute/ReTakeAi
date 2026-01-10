//
//  ShootSceneDetailView.swift
//  ReTakeAi
//

import SwiftUI

struct ShootSceneDetailView: View {
    let projectID: UUID
    let sceneID: UUID

    @State private var viewModel: ShootSceneDetailViewModel
    @State private var selectedTake: Take?
    @State private var showingRecording = false

    init(projectID: UUID, sceneID: UUID) {
        self.projectID = projectID
        self.sceneID = sceneID
        _viewModel = State(initialValue: ShootSceneDetailViewModel(projectID: projectID, sceneID: sceneID))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let take = selectedTake {
                VideoPlayerView(videoURL: take.fileURL)
                    .frame(height: 300)
                    .background(Color.black)
            }

            List {
                if let scene = viewModel.scene {
                    Section("Script") {
                        Text(scene.scriptText)
                            .font(.body)
                            .padding(.vertical, 6)
                    }
                }

                Section {
                    if viewModel.takes.isEmpty {
                        ContentUnavailableView(
                            "No Takes Yet",
                            systemImage: "video.slash",
                            description: Text("Record your first take to get started")
                        )
                    } else {
                        ForEach(viewModel.takes) { take in
                            ShootSceneTakeRowView(
                                take: take,
                                isPreferred: viewModel.scene?.selectedTakeID == take.id,
                                onPlay: { selectedTake = take },
                                onMarkPreferred: { viewModel.markPreferred(take) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.deleteTake(take)
                                    if selectedTake?.id == take.id { selectedTake = nil }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    viewModel.markPreferred(take)
                                } label: {
                                    Label("Preferred", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                    }
                } header: {
                    Text("Takes (\(viewModel.takes.count))")
                }
            }
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingRecording = true
                } label: {
                    Label("Record Take", systemImage: "video.badge.plus")
                }
                .disabled(viewModel.project == nil || viewModel.scene == nil)
            }
        }
        .sheet(isPresented: $showingRecording) {
            if let project = viewModel.project, let scene = viewModel.scene {
                NavigationStack {
                    RecordingView(project: project, scene: scene)
                }
            }
        }
        .onAppear {
            viewModel.load()
            if selectedTake == nil {
                if let preferredID = viewModel.scene?.selectedTakeID,
                   let preferred = viewModel.takes.first(where: { $0.id == preferredID }) {
                    selectedTake = preferred
                } else {
                    selectedTake = viewModel.takes.last
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
    }

    private var titleText: String {
        if let scene = viewModel.scene {
            return "Scene \(scene.orderIndex + 1)"
        }
        return "Scene"
    }
}

private struct ShootSceneTakeRowView: View {
    let take: Take
    let isPreferred: Bool
    let onPlay: () -> Void
    let onMarkPreferred: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 10) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Take \(take.takeNumber)")
                                .font(.headline)

                            if isPreferred {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack(spacing: 12) {
                            Label(take.duration.shortDuration, systemImage: "clock")
                            Text(take.recordedAt.timeAgo)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if !isPreferred {
                Button(action: onMarkPreferred) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}


