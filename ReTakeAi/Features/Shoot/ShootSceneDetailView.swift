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

                takesSections
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
            // Do not auto-play. User must tap a take to play.
            selectedTake = nil
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

    @ViewBuilder
    private var takesSections: some View {
        if viewModel.takes.isEmpty {
            Section {
                ContentUnavailableView(
                    "No Takes Yet",
                    systemImage: "video.slash",
                    description: Text("Record your first take to get started")
                )
            }
        } else {
            let preferredID = viewModel.scene?.selectedTakeID
            let preferred = viewModel.takes.first(where: { $0.id == preferredID })
            let others = viewModel.takes.filter { $0.id != preferredID }

            if let preferred {
                Section("Preferred Take") {
                    ShootSceneTakeRowView(
                        take: preferred,
                        isPreferred: true,
                        onPlay: { selectedTake = preferred },
                        onMarkPreferred: {}
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteTake(preferred)
                            if selectedTake?.id == preferred.id { selectedTake = nil }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Section("Other Takes") {
                ForEach(others) { take in
                    ShootSceneTakeRowView(
                        take: take,
                        isPreferred: false,
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
                }
            }
        }
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
                        Text("Take \(take.takeNumber)")
                            .font(.headline)

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

            Button(action: onMarkPreferred) {
                Image(systemName: isPreferred ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.title3)
                    .foregroundStyle(isPreferred ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .disabled(isPreferred)
        }
    }
}


