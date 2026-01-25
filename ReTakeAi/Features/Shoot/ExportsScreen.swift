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
    @State private var exportToDelete: ExportedVideo?

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
        .alert("Delete Export?", isPresented: .init(
            get: { exportToDelete != nil },
            set: { if !$0 { exportToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                exportToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let export = exportToDelete {
                    deleteExport(export)
                }
                exportToDelete = nil
            }
        } message: {
            Text("This export will be permanently deleted.")
        }
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
                Text(export.formattedDate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("\(export.aspect.title) • \(export.formattedDuration) • \(export.formattedSize)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Action buttons
            if fileExists {
                HStack(spacing: 12) {
                    // Share button
                    ShareLink(item: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.Colors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.borderless)

                    // Save to Photos button
                    Button {
                        saveToPhotos(export)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Save to Photos")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.Colors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Delete option
            Button {
                exportToDelete = export
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Delete Export")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderless)
            .padding(.top, 4)
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
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    saveErrorMessage = "Photo access denied"
                    showingSaveError = true
                    hideSaveErrorAfterDelay()
                }
                return
            }
            
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(
                        with: .video,
                        fileURL: export.fileURL,
                        options: nil
                    )
                }
                await MainActor.run {
                    showingSaveSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaveSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    saveErrorMessage = error.localizedDescription
                    showingSaveError = true
                    hideSaveErrorAfterDelay()
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


