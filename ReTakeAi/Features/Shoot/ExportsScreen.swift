//
//  ExportsScreen.swift
//  ReTakeAi
//

import SwiftUI

struct ExportsScreen: View {
    let projectID: UUID

    @State private var project: Project?
    @State private var playingExport: ExportedVideo?

    private var sortedExports: [ExportedVideo] {
        (project?.exports ?? []).sorted { $0.exportedAt > $1.exportedAt }
    }

    init(projectID: UUID) {
        self.projectID = projectID
    }

    var body: some View {
        Group {
            if let project, project.exports.isEmpty {
                ContentUnavailableView(
                    "No Exports Yet",
                    systemImage: "square.and.arrow.up",
                    description: Text("Export a video to see it here.")
                )
            } else {
                List {
                    ForEach(sortedExports) { export in
                        exportRow(export)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            deleteExport(sortedExports[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Exports")
        .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private func exportRow(_ export: ExportedVideo) -> some View {
        let url = export.fileURL
        let fileExists = FileManager.default.fileExists(atPath: url.path)

        Button {
            playingExport = export
        } label: {
            HStack(spacing: 12) {
                if fileExists {
                    VideoThumbnailView(
                        videoURL: export.fileURL,
                        isPortrait: export.aspect == .portrait9x16,
                        durationText: nil
                    )
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(export.formattedDate)
                        .font(.subheadline.weight(.semibold))
                    Text("\(export.aspect.title) • \(export.formattedDuration) • \(export.formattedSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !fileExists {
                        Text("File missing")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                Spacer(minLength: 0)

                if fileExists {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func reload() {
        project = ProjectStore.shared.getProject(by: projectID)
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


