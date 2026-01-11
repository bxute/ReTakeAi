//
//  PreviewScreen.swift
//  ReTakeAi
//

import SwiftUI

struct PreviewScreen: View {
    let projectID: UUID
    let takes: [Take]

    @State private var previewURL: URL
    @State private var selectedAspect: VideoAspect
    @State private var mergedAspect: VideoAspect
    @State private var isPreparingPreview = false
    @State private var showingExport = false
    @Environment(\.dismiss) private var dismiss

    init(projectID: UUID, takes: [Take], initialPreviewURL: URL, initialAspect: VideoAspect) {
        self.projectID = projectID
        self.takes = takes
        _previewURL = State(initialValue: initialPreviewURL)
        _selectedAspect = State(initialValue: initialAspect)
        _mergedAspect = State(initialValue: initialAspect)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Video Preview with aspect ratio container
                videoPreviewSection
                    .frame(maxWidth: .infinity)
                    .background(Color.black)

                // Aspect Ratio Selector
                aspectRatioSelector
                    .padding(.horizontal)
                    .padding(.top, 20)

                Spacer()

                // Export CTA
                exportButton
                    .padding(.horizontal)
                    .padding(.bottom, 16)
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
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingExport) {
            if let project = ProjectStore.shared.getProject(by: projectID) {
                ExportView(project: project)
            }
        }
        .task(id: selectedAspect) {
            await regeneratePreviewIfNeeded()
        }
    }

    // MARK: - Video Preview

    private var videoPreviewSection: some View {
        GeometryReader { geometry in
            let containerSize = calculatePreviewSize(in: geometry.size)

            ZStack {
                Color.black

                VideoPlayerView(videoURL: previewURL, autoplay: true)
                    .frame(width: containerSize.width, height: containerSize.height)
                    .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(previewContainerAspectRatio, contentMode: .fit)
        .animation(.easeInOut(duration: 0.25), value: selectedAspect)
    }

    private var previewContainerAspectRatio: CGFloat {
        // Container aspect ratio adapts to show the selected aspect with padding
        switch selectedAspect {
        case .portrait9x16:
            return 9.0 / 16.0
        case .landscape16x9:
            return 16.0 / 9.0
        case .square1x1:
            return 1.0
        }
    }

    private func calculatePreviewSize(in containerSize: CGSize) -> CGSize {
        let targetAspect = selectedAspect.aspectRatio
        let containerAspect = containerSize.width / containerSize.height

        if targetAspect > containerAspect {
            // Width-constrained
            let width = containerSize.width
            let height = width / targetAspect
            return CGSize(width: width, height: height)
        } else {
            // Height-constrained
            let height = containerSize.height
            let width = height * targetAspect
            return CGSize(width: width, height: height)
        }
    }

    // MARK: - Aspect Ratio Selector

    private var aspectRatioSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aspect Ratio")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(VideoAspect.allCases) { aspect in
                    aspectButton(for: aspect)
                }
            }
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
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

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            // Update project's aspect ratio before navigating to export
            updateProjectAspect()
            showingExport = true
        } label: {
            Label("Export Video", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func updateProjectAspect() {
        guard var project = ProjectStore.shared.getProject(by: projectID) else { return }
        project.videoAspect = selectedAspect
        try? ProjectStore.shared.updateProject(project)
    }

    private func regeneratePreviewIfNeeded() async {
        guard selectedAspect != mergedAspect else { return }
        guard !takes.isEmpty else { return }
        guard !isPreparingPreview else { return }

        isPreparingPreview = true
        defer { isPreparingPreview = false }

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

            previewURL = merged
            mergedAspect = selectedAspect
        } catch {
            // Keep showing the last good preview if regeneration fails.
        }
    }
}

