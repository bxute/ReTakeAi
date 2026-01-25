//
//  PreviewScreen.swift
//  ReTakeAi
//

import SwiftUI
import AVFoundation

struct PreviewScreen: View {
    let projectID: UUID
    @State private var project: Project?
    @State private var selectedAspect: VideoAspect = .portrait9x16

    @State private var isGenerating = false
    @State private var isExporting = false

    @State private var cachedPreviewURLs: [VideoAspect: URL] = [:]
    @State private var lastMergedURL: URL?

    @State private var playerItem: PlayerItem?
    @State private var showingExports = false
    @State private var isAspectSectionExpanded = false
    @State private var lastGeneratedAspect: VideoAspect?

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
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .padding(.bottom, 220)
            }

            // Sticky bottom action
            if isExporting {
                stickyExportingCard
            } else if isGenerating {
                stickyPreviewCardLoading
            } else if hasGeneratedPreviewForSelectedAspect {
                stickyPreviewCard
            } else {
                stickyGenerateButton
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
        }
        .task {
            load()
        }
        .navigationDestination(isPresented: $showingExports) {
            ExportsScreen(projectID: projectID)
        }
        .fullScreenCover(item: $playerItem) { item in
            ZStack(alignment: .topTrailing) {
                VideoPlayerView(videoURL: item.url, autoplay: true) { playerItem = nil }
                    .ignoresSafeArea()

                Button {
                    playerItem = nil
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
                        if let url = cachedPreviewURLs[selectedAspect],
                           FileManager.default.fileExists(atPath: url.path) {
                            playerItem = PlayerItem(url: url)
                        } else {
                            // File missing - regenerate
                            Task { await generatePreview(force: true) }
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

                // Re-generate option - only show when aspect changed
                if let lastAspect = lastGeneratedAspect, lastAspect != selectedAspect {
                    Button {
                        Task { await generatePreview(force: true) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                            Text("Re-generate for \(selectedAspect.title)")
                                .font(.caption)
                        }
                        .foregroundStyle(AppTheme.Colors.cta)
                    }
                    .disabled(isGenerating)
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .background(AppTheme.Colors.surface)
    }

    // MARK: - Sticky Preview Card Loading

    private var stickyPreviewCardLoading: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(height: 1)

            VStack(spacing: 12) {
                // Header - same as ready state but with spinner
                HStack {
                    ProgressView()
                        .tint(AppTheme.Colors.cta)
                    Text("Generating Preview…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                // Thumbnail + info - exact same layout as ready state
                HStack(spacing: 12) {
                    // Thumbnail shimmer - same size as VideoThumbnailView
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.Colors.background)
                        .frame(width: 80, height: 80)
                        .shimmer()

                    // Info - same VStack structure as ready state
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.background)
                            .frame(width: 80, height: 16)
                            .shimmer()

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.background)
                            .frame(width: 50, height: 14)
                            .shimmer()

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.background)
                            .frame(width: 60, height: 14)
                            .shimmer()
                    }

                    Spacer()
                }

                // Action buttons - same styling as ready state but disabled
                HStack(spacing: 12) {
                    Button {} label: {
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
                    .disabled(true)
                    .opacity(0.5)

                    Button {} label: {
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
                    .disabled(true)
                    .opacity(0.5)
                }
            }
            .padding(16)
        }
        .background(AppTheme.Colors.surface)
    }

    // MARK: - Sticky Generate Button

    // MARK: - Sticky Exporting Card

    private var stickyExportingCard: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(height: 1)

            HStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.Colors.cta)
                Text("Saving export…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(16)
        }
        .background(AppTheme.Colors.surface)
    }

    private var stickyGenerateButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(height: 1)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAspectSectionExpanded = false
                }
                Task { await generatePreview(force: true) }
            } label: {
                Label("Generate Preview", systemImage: "play.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle(background: AppTheme.Colors.cta, expandsToFullWidth: true))
            .disabled(isGenerating || isExporting)
            .padding(.horizontal)
            .padding(.vertical, 12)
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
        Text(project?.title ?? "Project")
            .font(.title2.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
    }

    private var aspectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section note
            Text("Choose how your video will be framed")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            // Bordered container with all content
            VStack(spacing: 0) {
                // Header - tap to expand/collapse
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAspectSectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("Aspect Ratio")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Spacer()

                        Text(selectedAspect.title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.cta)

                        Image(systemName: isAspectSectionExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)

                // Expanded content
                if isAspectSectionExpanded {
                    // Divider
                    Rectangle()
                        .fill(AppTheme.Colors.border)
                        .frame(height: 1)

                    VStack(spacing: 14) {
                        // Crop preview
                        cropPreviewSection

                        // Aspect ratio selector
                        aspectRatioSelector
                    }
                    .padding(14)
                }
            }
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

    // MARK: - Crop Preview

    private var cropPreviewSection: some View {
        let sourceIsPortrait = isSourceVideoPortrait
        let previewWidth: CGFloat = 100
        let previewHeight: CGFloat = sourceIsPortrait ? previewWidth * 16 / 9 : previewWidth * 9 / 16

        return HStack(spacing: 14) {
            // Thumbnail with crop overlay
            ZStack {
                if let take = loadSelectedTakes()?.first {
                    AsyncThumbnailView(videoURL: take.fileURL)
                        .frame(width: previewWidth, height: previewHeight)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(AppTheme.Colors.background)
                        .frame(width: previewWidth, height: previewHeight)
                        .overlay(
                            Image(systemName: "video.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        )
                }

                CropOverlayView(
                    containerSize: CGSize(width: previewWidth, height: previewHeight),
                    targetAspect: selectedAspect.aspectRatio
                )
            }
            .frame(width: previewWidth, height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(selectedAspect.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("•")
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    Text(selectedAspect.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Text("Shaded area will be cropped out")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }

            Spacer()
        }
    }

    private var isSourceVideoPortrait: Bool {
        if let take = loadSelectedTakes()?.first {
            return take.resolution.height > take.resolution.width
        }
        return true // Default to portrait
    }
}

// MARK: - Crop Overlay View

private struct CropOverlayView: View {
    let containerSize: CGSize
    let targetAspect: CGFloat

    var body: some View {
        let cropRect = calculateCropRect()

        Canvas { context, size in
            // Fill entire area with semi-transparent black
            let fullPath = Path(CGRect(origin: .zero, size: size))

            // Create the crop area path (the visible region)
            let cropPath = Path(roundedRect: cropRect, cornerRadius: 4)

            // Subtract crop area from full area to get the dimmed region
            var dimmedPath = fullPath
            dimmedPath = dimmedPath.subtracting(cropPath)

            // Draw the dimmed overlay
            context.fill(dimmedPath, with: .color(.black.opacity(0.65)))

            // Draw crop area border
            context.stroke(cropPath, with: .color(AppTheme.Colors.cta), lineWidth: 2)
        }
    }

    private func calculateCropRect() -> CGRect {
        let containerAspect = containerSize.width / containerSize.height

        let cropWidth: CGFloat
        let cropHeight: CGFloat

        if targetAspect > containerAspect {
            // Target is wider - fit to width, crop height
            cropWidth = containerSize.width
            cropHeight = cropWidth / targetAspect
        } else {
            // Target is taller - fit to height, crop width
            cropHeight = containerSize.height
            cropWidth = cropHeight * targetAspect
        }

        let x = (containerSize.width - cropWidth) / 2
        let y = (containerSize.height - cropHeight) / 2

        return CGRect(x: x, y: y, width: cropWidth, height: cropHeight)
    }
}

// MARK: - Async Thumbnail View

private struct AsyncThumbnailView: View {
    let videoURL: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(ProgressView())
            }
        }
        .task {
            thumbnail = await generateThumbnail()
        }
    }

    private func generateThumbnail() async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVAsset(url: videoURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 600, height: 600)

                let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

extension PreviewScreen {
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
            // Use caches directory instead of temp (temp gets cleaned too aggressively)
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let previewDir = caches.appendingPathComponent("Previews", isDirectory: true)
            try? FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)
            
            let url = previewDir.appendingPathComponent("preview_\(projectID.uuidString)_\(selectedAspect.rawValue).mov")
            try? FileManager.default.removeItem(at: url)

            let merged = try await VideoMerger.shared.mergeScenes(
                takes,
                outputURL: url,
                targetAspect: selectedAspect,
                progress: nil
            )

            cachedPreviewURLs[selectedAspect] = merged
            lastMergedURL = merged
            lastGeneratedAspect = selectedAspect
            // Don't auto-play - user will tap "Play Preview"
        } catch {
            // no-op for now
        }
    }

    private func exportVideo() async {
        guard !isGenerating && !isExporting else { return }
        guard var project else { return }
        guard let takes = loadSelectedTakes() else { return }

        // Check if we have a cached preview to copy (instant export)
        guard let previewURL = cachedPreviewURLs[selectedAspect],
              FileManager.default.fileExists(atPath: previewURL.path) else {
            // No preview - shouldn't happen but generate if needed
            await generatePreview(force: true)
            return
        }

        isExporting = true
        defer { isExporting = false }

        do {
            project.videoAspect = selectedAspect
            try ProjectStore.shared.updateProject(project)

            let exportDir = FileStorageManager.shared.exportsDirectory(for: projectID)
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            
            let fileName = "export_\(Int(Date().timeIntervalSince1970)).mov"
            let outputURL = exportDir.appendingPathComponent(fileName)

            // Copy the preview file instead of re-encoding
            try FileManager.default.copyItem(at: previewURL, to: outputURL)

            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export file not created"])
            }

            let totalDuration = takes.reduce(0) { $0 + $1.duration }
            let fileSize = FileStorageManager.shared.fileSize(at: outputURL)

            let exportedVideo = ExportedVideo(
                projectID: projectID,
                fileURL: outputURL,
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

// MARK: - Player Item

private struct PlayerItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Shimmer Effect

private struct ShimmerModifier: ViewModifier {
    @State private var opacity: Double = 0.4

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                }
            }
    }
}

private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

