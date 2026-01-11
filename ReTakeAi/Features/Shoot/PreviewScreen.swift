//
//  PreviewScreen.swift
//  ReTakeAi
//

import SwiftUI

struct PreviewScreen: View {
    let projectID: UUID
    @State private var project: Project?
    @State private var selectedAspect: VideoAspect = .portrait9x16
    @State private var isWorking = false
    @State private var progressMessage: String?

    @State private var cachedPreviewURLs: [VideoAspect: URL] = [:]
    @State private var lastMergedURL: URL?

    @State private var showingPlayer = false
    @State private var playingURL: URL?
    @State private var showingExports = false

    @State private var showingExport = false
    @Environment(\.dismiss) private var dismiss

    init(projectID: UUID) {
        self.projectID = projectID
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    informationSection

                    aspectSelectionSection

                    optionsSection

                    generatedPreviewSection

                    Button {
                        Task { await generatePreview(force: true) }
                    } label: {
                        Label(hasGeneratedPreviewForSelectedAspect ? "Re-Generate Preview" : "Generate Preview", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isWorking)

                    if hasGeneratedPreviewForSelectedAspect {
                        VStack(spacing: 10) {
                            Button {
                                Task { await exportVideo() }
                            } label: {
                                Label("Export Video", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isWorking || project == nil)

                            HStack(spacing: 10) {
                                Text(finalDurationText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(finalSizeText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }

            if let progressMessage {
                ProgressDialog(message: progressMessage)
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingExports = true
                } label: {
                    Text("Go to Exports")
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
    }

    // MARK: - Aspect Ratio Selector

    private var aspectRatioSelector: some View {
        HStack(spacing: 0) {
            ForEach(VideoAspect.allCases) { aspect in
                aspectButton(for: aspect)
            }
        }
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .foregroundStyle(selectedAspect == aspect ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                selectedAspect == aspect
                    ? Color.accentColor
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .foregroundStyle(selectedAspect == aspect ? .white : .primary)
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Information")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text(project?.title ?? "Project")
                    .font(.subheadline.weight(.semibold))
                Text("Finalize your export settings, then generate a preview or export.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var aspectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aspect Ratio")
                .font(.headline)
            aspectRatioSelector
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Background Music")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Not implemented yet")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "music.note")
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Advanced AI Trims")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Not implemented yet")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "scissors")
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var hasGeneratedPreviewForSelectedAspect: Bool {
        if let url = cachedPreviewURLs[selectedAspect] {
            return FileManager.default.fileExists(atPath: url.path)
        }
        return false
    }

    private var generatedPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Generated Video")
                .font(.headline)

            if let url = cachedPreviewURLs[selectedAspect], FileManager.default.fileExists(atPath: url.path) {
                Button {
                    playingURL = url
                    showingPlayer = true
                } label: {
                    VideoThumbnailView(videoURL: url, isPortrait: false, durationText: nil)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Text("Duration: \(finalDurationText.replacingOccurrences(of: "Duration: ", with: ""))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No preview generated yet.")
                        .font(.subheadline.weight(.semibold))
                    Text("Tap “Generate Preview” to create a preview for the selected aspect ratio.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

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
        guard !isWorking else { return }
        guard let takes = loadSelectedTakes() else { return }

        if !force,
           let cached = cachedPreviewURLs[selectedAspect],
           FileManager.default.fileExists(atPath: cached.path) {
            lastMergedURL = cached
            playingURL = cached
            showingPlayer = true
            return
        }

        isWorking = true
        progressMessage = "Preparing Video Preview…."
        defer {
            isWorking = false
            progressMessage = nil
        }

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
            playingURL = merged
            showingPlayer = true
        } catch {
            // no-op for now
        }
    }

    private func exportVideo() async {
        guard !isWorking else { return }
        guard var project else { return }
        guard let takes = loadSelectedTakes() else { return }

        isWorking = true
        progressMessage = "Exporting Video…."
        defer {
            isWorking = false
            progressMessage = nil
        }

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

private struct ProgressDialog: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

