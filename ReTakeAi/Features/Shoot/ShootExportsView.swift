//
//  ShootExportsView.swift
//  ReTakeAi
//

import SwiftUI

struct ShootExportsView: View {
    let projectID: UUID
    @State private var viewModel: ShootOverviewViewModel

    init(projectID: UUID) {
        self.projectID = projectID
        _viewModel = State(initialValue: ShootOverviewViewModel(projectID: projectID))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let project = viewModel.project {
                    exportSection(project: project)

                    if !project.exports.isEmpty {
                        previousExportsSection(project: project)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .navigationTitle("Exports")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.load()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
    }

    private func exportSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export")
                .font(.headline)

            if viewModel.isReadyToExport {
                NavigationLink {
                    ExportView(project: project)
                } label: {
                    Label(project.exports.isEmpty ? "Export Final Video" : "Re-Export Video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Text(project.exports.isEmpty ? "All scenes recorded! Ready to export." : "Create a new export from the latest takes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Finish recording to export.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func previousExportsSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous Exports")
                .font(.headline)

            ForEach(project.exports.sorted(by: { $0.exportedAt > $1.exportedAt })) { export in
                ShootExportRowView(export: export, onDelete: { viewModel.deleteExport(export) })
                Divider()
            }
        }
    }
}

struct ShootExportRowView: View {
    let export: ExportedVideo
    let onDelete: () -> Void

    @State private var showingShareSheet = false
    @State private var showingPlayer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(export.formattedDate)
                        .font(.headline)
                    Text("\(export.aspect.title) • \(export.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button { showingPlayer = true } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Button { showingShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            Text(export.formattedSize)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showingPlayer) {
            NavigationStack {
                VideoPlayerView(videoURL: export.fileURL)
                    .navigationTitle("Exported Video")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingPlayer = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [export.fileURL])
        }
    }
}


