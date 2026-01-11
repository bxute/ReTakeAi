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
    @State private var isPreparingPreview = false
    @State private var previewURL: URL?
    @State private var showingPreview = false

    init(projectID: UUID) {
        self.projectID = projectID
        _viewModel = State(initialValue: ShootOverviewViewModel(projectID: projectID))
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if let project = viewModel.project {
                        scenesSection
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }

            if isPreparingPreview {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Preparing Video Preview….")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Scene Shoot")
        .navigationBarTitleDisplayMode(.inline)
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
        .fullScreenCover(isPresented: $showingPreview) {
            if let previewURL {
                NavigationStack {
                    VideoPlayerView(videoURL: previewURL)
                        .navigationTitle("Preview")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingPreview = false }
                            }
                        }
                }
            }
        }
    }

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
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
                    let takes = viewModel.getTakes(for: scene)
                    let best = viewModel.bestTake(for: scene)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Group {
                                if let best {
                                    VideoThumbnailView(
                                        videoURL: best.fileURL,
                                        isPortrait: best.resolution.height > best.resolution.width,
                                        durationText: nil
                                    )
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.secondary.opacity(0.12))
                                        Image(systemName: "video.slash")
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(width: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Scene \(scene.orderIndex + 1)")
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()

                                    Button {
                                        selectedSceneForRecording = scene
                                    } label: {
                                        Text(scene.isRecorded ? "ReTake" : "Record")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.red)
                                }

                                Text(scene.scriptText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)

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
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSceneForDetails = scene
                    }
                }
            }

            if !viewModel.scenes.isEmpty && viewModel.scenes.allSatisfy({ $0.isRecorded }) {
                Button {
                    Task { await preparePreview() }
                } label: {
                    Label("Preview", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isPreparingPreview)

                NavigationLink {
                    ShootExportsView(projectID: projectID)
                } label: {
                    Label("Export Video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 16)
            }
        }
    }

    private func preparePreview() async {
        guard !isPreparingPreview else { return }
        isPreparingPreview = true
        defer { isPreparingPreview = false }

        do {
            let projectStore = ProjectStore.shared
            let sceneStore = SceneStore.shared
            let takeStore = TakeStore.shared

            guard let latestProject = projectStore.getProject(by: projectID) else {
                viewModel.errorMessage = "Project not found"
                return
            }

            let scenes = sceneStore.getScenes(for: latestProject)
            guard !scenes.isEmpty else {
                viewModel.errorMessage = "No scenes to preview"
                return
            }

            let selectedTakes = scenes.compactMap { scene -> Take? in
                guard let selectedTakeID = scene.selectedTakeID else { return nil }
                let takes = takeStore.getTakes(for: scene)
                return takes.first { $0.id == selectedTakeID }
            }

            guard selectedTakes.count == scenes.count else {
                viewModel.errorMessage = "Please select a take for each scene before previewing."
                return
            }

            let tmp = FileManager.default.temporaryDirectory
            let url = tmp.appendingPathComponent("preview_\(projectID.uuidString)_\(Int(Date().timeIntervalSince1970)).mov")
            try? FileManager.default.removeItem(at: url)

            let merged = try await VideoMerger.shared.mergeScenes(
                selectedTakes,
                outputURL: url,
                targetRenderSize: latestProject.videoAspect.exportRenderSize,
                progress: nil
            )

            previewURL = merged
            showingPreview = true
        } catch {
            viewModel.errorMessage = "Preview failed: \(error.localizedDescription)"
        }
    }
}

