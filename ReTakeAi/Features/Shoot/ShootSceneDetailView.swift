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
    @State private var showRecording = false

    init(projectID: UUID, sceneID: UUID) {
        self.projectID = projectID
        self.sceneID = sceneID
        _viewModel = State(initialValue: ShootSceneDetailViewModel(projectID: projectID, sceneID: sceneID))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Script Section
                    if let scene = viewModel.scene {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SCRIPT")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textTertiary)

                            Text(scene.scriptText)
                                .font(.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.Colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.Colors.border, lineWidth: 1)
                        )
                    }

                    // Takes Section
                    takesSections
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .padding(.bottom, 80) // Space for sticky CTA
            }

            // Sticky bottom CTA
            stickyBottomCTA
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(titleText)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
        }
        .onAppear {
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sceneDidUpdate)) { _ in
            viewModel.load()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .fullScreenCover(isPresented: $showRecording, onDismiss: {
            viewModel.load()
        }) {
            if let project = viewModel.project, let scene = viewModel.scene {
                NavigationStack {
                    RecordingView(project: project, scene: scene)
                }
            }
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

    // MARK: - Sticky Bottom CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(height: 1)

            Button {
                showRecording = true
            } label: {
                Label(
                    viewModel.takes.isEmpty ? "Record First Take" : "Retake",
                    systemImage: "video.fill"
                )
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle(background: AppTheme.Colors.cta, expandsToFullWidth: true))
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(AppTheme.Colors.surface)
    }

    // MARK: - Takes Sections

    @ViewBuilder
    private var takesSections: some View {
        if viewModel.takes.isEmpty {
            // No takes - just show script (already shown above) with clear action
            EmptyView()
        } else {
            let preferredID = viewModel.scene?.selectedTakeID
            let preferred = viewModel.takes.first(where: { $0.id == preferredID })
                ?? viewModel.takes.max(by: { $0.takeNumber < $1.takeNumber })
            let others = viewModel.takes.filter { $0.id != preferred?.id }

            VStack(alignment: .leading, spacing: 16) {
                // Preferred Take
                if let preferred {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREFERRED TAKE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textTertiary)

                        ShootSceneTakeRowView(
                            take: preferred,
                            isPreferred: true,
                            onPlay: { playingTake = preferred },
                            onMarkPreferred: {},
                            onDelete: {
                                viewModel.deleteTake(preferred)
                                if playingTake?.id == preferred.id { playingTake = nil }
                            }
                        )
                    }
                }

                // Other Takes - only show if >1 take total
                if !others.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OTHER TAKES")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textTertiary)

                        ForEach(others) { take in
                            ShootSceneTakeRowView(
                                take: take,
                                isPreferred: false,
                                onPlay: { playingTake = take },
                                onMarkPreferred: { viewModel.markPreferred(take) },
                                onDelete: {
                                    viewModel.deleteTake(take)
                                    if playingTake?.id == take.id { playingTake = nil }
                                }
                            )
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
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    ZStack {
                        VideoThumbnailView(
                            videoURL: take.fileURL,
                            isPortrait: take.resolution.height >= take.resolution.width,
                            durationText: nil
                        )
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.35), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Take \(take.takeNumber)")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text("•")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textTertiary)

                            Text(take.duration.shortDuration)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            if isPreferred {
                                Image(systemName: "hand.thumbsup.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.success)
                            }
                        }

                        Text(take.recordedAt.timeAgo)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // Mark as preferred button (only for non-preferred takes)
            if !isPreferred {
                Button(action: onMarkPreferred) {
                    Image(systemName: "hand.thumbsup")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.destructive)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isPreferred ? AppTheme.Colors.success.opacity(0.3) : AppTheme.Colors.border, lineWidth: 1)
        )
    }
}


