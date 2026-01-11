//
//  ShootSceneDetailView.swift
//  ReTakeAi
//

import SwiftUI

struct ShootSceneDetailView: View {
    let projectID: UUID
    let sceneID: UUID

    @State private var viewModel: ShootSceneDetailViewModel
    @State private var playingTake: Take?

    init(projectID: UUID, sceneID: UUID) {
        self.projectID = projectID
        self.sceneID = sceneID
        _viewModel = State(initialValue: ShootSceneDetailViewModel(projectID: projectID, sceneID: sceneID))
    }

    var body: some View {
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
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .fullScreenCover(item: $playingTake) { take in
            ZStack(alignment: .topTrailing) {
                VideoPlayerView(videoURL: take.fileURL, autoplay: true) { playingTake = nil }
                    .ignoresSafeArea()

                Button {
                    playingTake = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .black.opacity(0.35))
                        .padding(10)
                }
                .buttonStyle(.plain)
            }
            .statusBarHidden(true)
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
                        onPlay: {
                            playingTake = preferred
                        },
                        onMarkPreferred: {}
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteTake(preferred)
                            if playingTake?.id == preferred.id { playingTake = nil }
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
                        onPlay: {
                            playingTake = take
                        },
                        onMarkPreferred: { viewModel.markPreferred(take) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteTake(take)
                            if playingTake?.id == take.id { playingTake = nil }
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
                HStack(spacing: 12) {
                    VideoThumbnailView(
                        videoURL: take.fileURL,
                        isPortrait: take.resolution.height >= take.resolution.width,
                        durationText: nil
                    )
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Take \(take.takeNumber)")
                            .font(.headline)

                        Text("\(take.duration.shortDuration) • \(take.recordedAt.timeAgo)")
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


