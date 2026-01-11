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

    @State private var cachedPreviewURLs: [VideoAspect: URL] = [:]
    @State private var lastMergedURL: URL?

    @State private var showingPlayer = false
    @State private var playingURL: URL?

    @State private var showingExport = false
    @Environment(\.dismiss) private var dismiss

    init(projectID: UUID) {
        self.projectID = projectID
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aspect Ratio")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        aspectRatioSelector
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Background Music")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Coming soon")
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
                            Text("Coming soon")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "scissors")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        Task { await generatePreview() }
                    } label: {
                        Label("Generate Preview", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isWorking)

                    if let project, !project.exports.isEmpty {
                        previousExportsSection(project: project)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }

            VStack(spacing: 8) {
                Spacer()

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
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
            }

            if isWorking {
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
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let playingURL {
                NavigationStack {
                    VideoPlayerView(videoURL: playingURL, autoplay: true) {
                        showingPlayer = false
                    }
                    .navigationTitle("Preview")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingPlayer = false }
                        }
                    }
                }
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
        if let url = lastMergedURL, FileManager.default.fileExists(atPath: url.path) {
            let size = FileStorageManager.shared.fileSize(at: url)
            return "Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
        }
        guard let takes = loadSelectedTakes() else { return "Size: —" }
        let estimate = takes.reduce(Int64(0)) { $0 + $1.fileSize }
        return "Size: ~\(ByteCountFormatter.string(fromByteCount: estimate, countStyle: .file))"
    }

    private func generatePreview() async {
        guard !isWorking else { return }
        guard let takes = loadSelectedTakes() else { return }

        if let cached = cachedPreviewURLs[selectedAspect],
           FileManager.default.fileExists(atPath: cached.path) {
            lastMergedURL = cached
            playingURL = cached
            showingPlayer = true
            return
        }

        isWorking = true
        defer { isWorking = false }

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
        defer { isWorking = false }

        do {
            project.videoAspect = selectedAspect
            try ProjectStore.shared.updateProject(project)

            let exportDir = FileStorageManager.shared.exportsDirectory(for: projectID)
            let fileName = "export_\(Date().timeIntervalSince1970).mov"
            let outputURL = exportDir.appendingPathComponent(fileName)

            let mergedURL = try await VideoMerger.shared.mergeScenes(
                takes,
                outputURL: outputURL,
                targetAspect: selectedAspect,
                progress: nil
            )

            let totalDuration = takes.reduce(0) { $0 + $1.duration }
            let fileSize = FileStorageManager.shared.fileSize(at: mergedURL)

            let exportedVideo = ExportedVideo(
                fileURL: mergedURL,
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
        } catch {
            // no-op for now
        }
    }

    private func previousExportsSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous Exports")
                .font(.headline)

            ForEach(project.exports.sorted(by: { $0.exportedAt > $1.exportedAt })) { export in
                Button {
                    playingURL = export.fileURL
                    showingPlayer = true
                } label: {
                    HStack(spacing: 12) {
                        VideoThumbnailView(
                            videoURL: export.fileURL,
                            isPortrait: export.aspect == .portrait9x16,
                            durationText: export.formattedDuration
                        )
                        .frame(width: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(export.formattedDate)
                                .font(.subheadline.weight(.semibold))
                            Text("\(export.aspect.title) • \(export.formattedSize)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

