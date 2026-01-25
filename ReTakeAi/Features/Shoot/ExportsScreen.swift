//
//  ExportsScreen.swift
//  ReTakeAi
//

import SwiftUI
import Photos

struct ExportsScreen: View {
    let projectID: UUID

    @State private var project: Project?
    @State private var playingExport: ExportedVideo?
    @State private var showingSaveSuccess = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""

    private var sortedExports: [ExportedVideo] {
        (project?.exports ?? []).sorted { $0.exportedAt > $1.exportedAt }
    }

    init(projectID: UUID) {
        self.projectID = projectID
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            if let project, project.exports.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(sortedExports) { export in
                            exportCard(export)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Exports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            reload()
        }
        .refreshable {
            reload()
        }
        .fullScreenCover(item: $playingExport) { export in
            ZStack(alignment: .topTrailing) {
                VideoPlayerView(videoURL: export.fileURL, autoplay: true) { playingExport = nil }
                    .ignoresSafeArea()

                Button {
                    playingExport = nil
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding()
            }
            .statusBarHidden(true)
        }
        .overlay(alignment: .bottom) {
            if showingSaveSuccess {
                toastView(message: "Saved to Photos", icon: "checkmark.circle.fill", color: AppTheme.Colors.success)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showingSaveError {
                toastView(message: saveErrorMessage, icon: "exclamationmark.circle.fill", color: .red)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingSaveSuccess)
        .animation(.easeInOut(duration: 0.25), value: showingSaveError)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)

            VStack(spacing: 6) {
                Text("No exports yet")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Preview your video and export when ready.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }

    // MARK: - Export Card

    @ViewBuilder
    private func exportCard(_ export: ExportedVideo) -> some View {
        let url = export.fileURL
        let fileExists = FileManager.default.fileExists(atPath: url.path)

        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail with play overlay
            Button {
                if fileExists {
                    playingExport = export
                }
            } label: {
                ZStack {
                    if fileExists {
                        VideoThumbnailView(
                            videoURL: export.fileURL,
                            isPortrait: export.aspect == .portrait9x16,
                            durationText: nil
                        )
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        // Play overlay
                        Circle()
                            .fill(.black.opacity(0.5))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .offset(x: 2)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.Colors.surface)
                            .frame(height: 180)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.title)
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                    Text("File missing")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                }
                            }
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!fileExists)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Final Export")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(export.formattedDate)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Text("\(export.aspect.title) • \(export.formattedDuration) • \(export.formattedSize)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }

            // Action buttons
            if fileExists {
                HStack(spacing: 12) {
                    // Share button
                    ShareLink(item: export.fileURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                    )

                    // Save to Photos button
                    Button {
                        saveToPhotos(export)
                    } label: {
                        Label("Save to Photos", systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                    )
                }
            }

            // Delete option
            Button(role: .destructive) {
                deleteExport(export)
            } label: {
                Label("Delete Export", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
    }

    // MARK: - Toast

    private func toastView(message: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .padding(.bottom, 32)
    }

    // MARK: - Actions

    private func reload() {
        project = ProjectStore.shared.getProject(by: projectID)
    }

    private func saveToPhotos(_ export: ExportedVideo) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    saveErrorMessage = "Photo access denied"
                    showingSaveError = true
                    hideSaveErrorAfterDelay()
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(
                        with: .video,
                        fileURL: export.fileURL,
                        options: nil
                    )
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if success {
                            showingSaveSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingSaveSuccess = false
                            }
                        } else {
                            saveErrorMessage = error?.localizedDescription ?? "Save failed"
                            showingSaveError = true
                            hideSaveErrorAfterDelay()
                        }
                    }
                }
            }
        }
    }

    private func hideSaveErrorAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showingSaveError = false
        }
    }

    private func deleteExport(_ export: ExportedVideo) {
        guard var current = ProjectStore.shared.getProject(by: projectID) else { return }

        if playingExport?.id == export.id {
            playingExport = nil
        }

        try? FileManager.default.removeItem(at: export.fileURL)

        current.exports.removeAll { $0.id == export.id }
        try? ProjectStore.shared.updateProject(current)
        project = current
    }
}


