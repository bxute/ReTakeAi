//
//  PreviewScreen.swift
//  ReTakeAi
//

import SwiftUI

struct PreviewScreen: View {
    let projectID: UUID
    let previewURL: URL

    @State private var selectedAspect: VideoAspect = .portrait9x16
    @State private var showingExport = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingExport) {
            if let project = ProjectStore.shared.getProject(by: projectID) {
                ExportView(project: project)
            }
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
}

