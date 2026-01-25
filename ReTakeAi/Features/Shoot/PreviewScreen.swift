//
//  PreviewScreen.swift
//  ReTakeAi
//

import SwiftUI

struct PreviewScreen: View {
    let projectID: UUID
    @State private var project: Project?
    @State private var selectedAspect: VideoAspect = .portrait9x16

    @State private var isGenerating = false
    @State private var isExporting = false

    @State private var cachedPreviewURLs: [VideoAspect: URL] = [:]
    @State private var lastMergedURL: URL?

    @State private var showingPlayer = false
    @State private var playingURL: URL?
    @State private var showingExports = false

    @Environment(\.dismiss) private var dismiss

    init(projectID: UUID) {
        self.projectID = projectID
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    informationSection

                    aspectSelectionSection

                    // Inline generating state
                    if isGenerating {
                        inlineProgressCard(
                            title: "Generating preview…",
                            subtitle: "This may take a few seconds."
                        )
                    }

                    // Inline exporting state
                    if isExporting {
                        inlineProgressCard(
                            title: "Exporting video…",
                            subtitle: "You can leave this screen."
                        )
                    }

                    // Generate Preview button (when no preview yet)
                    if !hasGeneratedPreviewForSelectedAspect && !isGenerating {
                        Button {
                            Task { await generatePreview(force: true) }
                        } label: {
                            Label("Generate Preview", systemImage: "play.circle.fill")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle(background: AppTheme.Colors.cta))
                        .disabled(isGenerating || isExporting)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .padding(.bottom, hasGeneratedPreviewForSelectedAspect ? 200 : 20)
            }

            // Sticky Preview Card at bottom
            if hasGeneratedPreviewForSelectedAspect {
                stickyPreviewCard
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Preview")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingExports = true
                } label: {
                    Text("Exports")
                        .foregroundStyle(AppTheme.Colors.cta)
                }
                .disabled(project?.exports.isEmpty ?? true)
            }
        }
        .task {
            load()
        }
        .navigationDestination(isPresented: $showingExports) {
            ExportsScreen(projectID: projectID)
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let playingURL {
                ZStack(alignment: .topTrailing) {
                    VideoPlayerView(videoURL: playingURL, autoplay: true) { showingPlayer = false }
                        .ignoresSafeArea()

                    Button {
                        showingPlayer = false
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
        }
    }

    // MARK: - Inline Progress Card

    private func inlineProgressCard(title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(AppTheme.Colors.cta)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - Sticky Preview Card

    private var stickyPreviewCard: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(height: 1)

            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "film.fill")
                        .foregroundStyle(AppTheme.Colors.success)
                    Text("Preview Ready")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                // Thumbnail + info
                if let url = cachedPreviewURLs[selectedAspect] {
                    HStack(spacing: 12) {
                        VideoThumbnailView(videoURL: url, isPortrait: selectedAspect == .portrait9x16, durationText: nil)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(finalDurationText)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text(selectedAspect.title)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            Text(finalSizeText)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }

                        Spacer()
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        if let url = cachedPreviewURLs[selectedAspect] {
                            playingURL = url
                            showingPlayer = true
                        }
                    } label: {
                        Label("Play Preview", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle(
                        background: AppTheme.Colors.surface,
                        foreground: AppTheme.Colors.textPrimary,
                        expandsToFullWidth: true,
                        cornerRadius: 10,
                        verticalPadding: 12,
                        horizontalPadding: 12
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                    )

                    Button {
                        Task { await exportVideo() }
                    } label: {
                        Label("Export Video", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle(
                        background: AppTheme.Colors.cta,
                        expandsToFullWidth: true,
                        cornerRadius: 10,
                        verticalPadding: 12,
                        horizontalPadding: 12
                    ))
                    .disabled(isExporting || project == nil)
                }

                // Re-generate option
                Button {
                    Task { await generatePreview(force: true) }
                } label: {
                    Text("Re-generate Preview")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .disabled(isGenerating)
            }
            .padding(16)
        }
        .background(AppTheme.Colors.surface)
    }

    // MARK: - Aspect Ratio Selector

    private var aspectRatioSelector: some View {
        HStack(spacing: 0) {
            ForEach(VideoAspect.allCases) { aspect in
                aspectButton(for: aspect)
            }
        }
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }

    private func aspectButton(for aspect: VideoAspect) -> some View {
        Button {
            selectedAspect = aspect
        } label: {
            VStack(spacing: 2) {
                Text(aspect.title)
                    .font(.subheadline.weight(.semibold))
                Text(aspect.subtitle)
                    .font(.caption2)
                    .foregroundStyle(selectedAspect == aspect ? AppTheme.Colors.textPrimary.opacity(0.8) : AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                selectedAspect == aspect
                    ? AppTheme.Colors.cta
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .foregroundStyle(selectedAspect == aspect ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INFORMATION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textTertiary)

            VStack(alignment: .leading, spacing: 6) {
                Text(project?.title ?? "Project")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Finalize your export settings, then generate a preview.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(12)
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
    }

    private var aspectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASPECT RATIO")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            aspectRatioSelector
        }
    }

    private var hasGeneratedPreviewForSelectedAspect: Bool {
        if let url = cachedPreviewURLs[selectedAspect] {
            return FileManager.default.fileExists(atPath: url.path)
        }
        return false
    }

    // MARK: - Data Loading

    private func load() {
        let projectStore = ProjectStore.shared
        project = projectStore.getProject(by: projectID)

        // Default aspect: based on first selected take (vertical vs landscape)
        if let takes = loadSelectedTakes(), let first = takes.first {
            selectedAspect = (first.resolution.height >= first.resolution.width) ? .portrait9x16 : .landscape16x9
        } else if let project {
            selectedAspect = project.videoAspect
        }
    }

    private func loadSelectedTakes() -> [Take]? {
        guard let project else { return nil }
        let sceneStore = SceneStore.shared
        let takeStore = TakeStore.shared
        let scenes = sceneStore.getScenes(for: project)
        guard !scenes.isEmpty else { return [] }

        let selected = scenes.compactMap { scene -> Take? in
            guard let id = scene.selectedTakeID else { return nil }
            return takeStore.getTakes(for: scene).first { $0.id == id }
        }
        return selected.count == scenes.count ? selected : nil
    }

    private var finalDurationText: String {
        guard let takes = loadSelectedTakes() else { return "Duration: —" }
        let total = takes.reduce(0) { $0 + $1.duration }
        return "Duration: \(total.formattedDuration)"
    }

    private var finalSizeText: String {
        if let url = cachedPreviewURLs[selectedAspect], FileManager.default.fileExists(atPath: url.path) {
            let size = FileStorageManager.shared.fileSize(at: url)
            return "Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
        }
        guard let takes = loadSelectedTakes() else { return "Size: —" }
        let estimate = takes.reduce(Int64(0)) { $0 + $1.fileSize }
        return "Size: ~\(ByteCountFormatter.string(fromByteCount: estimate, countStyle: .file))"
    }

    private func generatePreview(force: Bool) async {
        guard !isGenerating && !isExporting else { return }
        guard let takes = loadSelectedTakes() else { return }

        if !force,
           let cached = cachedPreviewURLs[selectedAspect],
           FileManager.default.fileExists(atPath: cached.path) {
            // Don't auto-play, just use cached
            lastMergedURL = cached
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let tmp = FileManager.default.temporaryDirectory
            let url = tmp.appendingPathComponent("preview_\(projectID.uuidString)_\(selectedAspect.rawValue)_\(Int(Date().timeIntervalSince1970)).mov")
            try? FileManager.default.removeItem(at: url)

            let merged = try await VideoMerger.shared.mergeScenes(
                takes,
                outputURL: url,
                targetAspect: selectedAspect,
                progress: nil
            )

            cachedPreviewURLs[selectedAspect] = merged
            lastMergedURL = merged
            // Don't auto-play - user will tap "Play Preview"
        } catch {
            // no-op for now
        }
    }

    private func exportVideo() async {
        guard !isGenerating && !isExporting else { return }
        guard var project else { return }
        guard let takes = loadSelectedTakes() else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            project.videoAspect = selectedAspect
            try ProjectStore.shared.updateProject(project)

            let exportDir = FileStorageManager.shared.exportsDirectory(for: projectID)
            // Ensure exports directory exists
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            
            let fileName = "export_\(Int(Date().timeIntervalSince1970)).mov"
            let outputURL = exportDir.appendingPathComponent(fileName)

            let mergedURL = try await VideoMerger.shared.mergeScenes(
                takes,
                outputURL: outputURL,
                targetAspect: selectedAspect,
                progress: nil
            )

            // Verify file was written
            guard FileManager.default.fileExists(atPath: mergedURL.path) else {
                throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export file not created"])
            }

            let totalDuration = takes.reduce(0) { $0 + $1.duration }
            let fileSize = FileStorageManager.shared.fileSize(at: mergedURL)

            // Store export with the actual output URL's filename
            let exportedVideo = ExportedVideo(
                projectID: projectID,
                fileURL: outputURL,  // Use outputURL to ensure consistency
                aspect: selectedAspect,
                duration: totalDuration,
                fileSize: fileSize
            )

            var updated = ProjectStore.shared.getProject(by: projectID) ?? project
            updated.videoAspect = selectedAspect
            updated.exports.append(exportedVideo)
            updated.status = .exported
            try ProjectStore.shared.updateProject(updated)
            self.project = updated
            showingExports = true
        } catch {
            // no-op for now
        }
    }
}

