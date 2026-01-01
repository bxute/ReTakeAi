//
//  ProjectDetailView.swift
//  ReTakeAi
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var currentProject: Project
    @State private var scenes: [VideoScene] = []
    @State private var selectedSceneForRecording: VideoScene?
    
    private let sceneStore = SceneStore.shared
    private let projectStore = ProjectStore.shared

    init(project: Project) {
        self.project = project
        _currentProject = State(initialValue: project)
    }
    
    var body: some View {
        List {
            if !scenes.isEmpty {
                // Progress Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recording Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(recordedScenesCount)/\(scenes.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(recordedScenesCount), total: Double(scenes.count))
                            .tint(recordedScenesCount == scenes.count ? .green : .blue)
                        
                        if let nextScene = nextIncompleteScene {
                            Button {
                                selectedSceneForRecording = nextScene
                            } label: {
                                Label("Record Scene \(nextScene.orderIndex + 1)", systemImage: "video.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section("Scenes") {
                if scenes.isEmpty {
                    NavigationLink {
                        ScriptInputView(project: currentProject)
                    } label: {
                        Label("Add Script & Generate Scenes", systemImage: "text.badge.plus")
                    }
                } else {
                    ForEach(scenes) { scene in
                        HStack {
                            NavigationLink(value: scene) {
                                VideoSceneRowView(scene: scene)
                            }
                            
                            // Quick record button for incomplete scenes
                            if !scene.isComplete {
                                Button {
                                    selectedSceneForRecording = scene
                                } label: {
                                    Image(systemName: "video.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            if !scenes.isEmpty && scenes.allSatisfy({ $0.isComplete }) {
                Section {
                    NavigationLink {
                        ExportView(project: currentProject)
                    } label: {
                        Label(currentProject.exports.isEmpty ? "Export Final Video" : "Re-Export Video", systemImage: "square.and.arrow.up")
                            .foregroundColor(.green)
                    }
                } footer: {
                    Text(currentProject.exports.isEmpty ? "All scenes recorded! Ready to export." : "Create a new export from the latest takes.")
                }
            }
            
            if !currentProject.exports.isEmpty {
                Section("Previous Exports") {
                    ForEach(currentProject.exports.sorted(by: { $0.exportedAt > $1.exportedAt })) { export in
                        ExportRowView(export: export, project: currentProject, onDelete: {
                            deleteExport(export)
                        })
                    }
                }
            }
            
            Section("Project Info") {
                LabeledContent("Status", value: currentProject.status.rawValue.capitalized)
                LabeledContent("Created", value: currentProject.createdAt.formatted(style: .medium))
            }
        }
        .navigationTitle(currentProject.title)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: VideoScene.self) { scene in
            SceneReviewView(project: currentProject, scene: scene)
        }
        .fullScreenCover(item: $selectedSceneForRecording, onDismiss: {
            // After recording is dismissed, refresh project + scenes so takes appear immediately.
            loadProjectAndScenes()
        }) { scene in
            NavigationStack {
                RecordingView(project: currentProject, scene: scene)
            }
        }
        .onAppear {
            loadProjectAndScenes()
        }
        .refreshable {
            loadProjectAndScenes()
        }
    }
    
    private func loadProjectAndScenes() {
        if let latest = projectStore.getProject(by: project.id) {
            currentProject = latest
        }
        scenes = sceneStore.getScenes(for: currentProject)

        // Keep project status in sync with scene completion.
        // - exported should never be downgraded
        // - completed when every scene has a selected/best take
        // - recording once any scene has at least one take
        let desiredStatus: ProjectStatus? = {
            if currentProject.status == .exported { return nil }
            if !scenes.isEmpty && scenes.allSatisfy({ $0.isComplete }) { return .completed }
            if scenes.contains(where: { $0.isRecorded }) { return .recording }
            return .draft
        }()

        if let desiredStatus, desiredStatus != currentProject.status {
            var updated = currentProject
            updated.status = desiredStatus
            do {
                try projectStore.updateProject(updated)
                currentProject = updated
            } catch {
                AppLogger.ui.error("Failed to update project status: \(error.localizedDescription)")
            }
        }
    }
    
    private var completedScenesCount: Int {
        scenes.filter { $0.isComplete }.count
    }

    private var recordedScenesCount: Int {
        scenes.filter { $0.isRecorded }.count
    }
    
    private var nextIncompleteScene: VideoScene? {
        // "Next to record" = first scene with no takes yet.
        scenes.first { !$0.isRecorded }
    }
    
    private func deleteExport(_ export: ExportedVideo) {
        var updatedProject = currentProject
        updatedProject.exports.removeAll { $0.id == export.id }
        
        // Delete the file
        do {
            try FileManager.default.removeItem(at: export.fileURL)
            try projectStore.updateProject(updatedProject)
            currentProject = updatedProject
            AppLogger.ui.info("Deleted export: \(export.fileURL.lastPathComponent)")
        } catch {
            AppLogger.ui.error("Failed to delete export: \(error.localizedDescription)")
        }
    }
}

struct VideoSceneRowView: View {
    let scene: VideoScene
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Scene \(scene.orderIndex + 1)")
                    .font(.headline)
                
                Spacer()
                
                if scene.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if scene.isRecorded {
                    Text("Recorded")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Not recorded")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Text(scene.scriptText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if scene.isRecorded {
                Text("\(scene.takeIDs.count) take\(scene.takeIDs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExportRowView: View {
    let export: ExportedVideo
    let project: Project
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
                
                Button {
                    showingPlayer = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
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
        .padding(.vertical, 4)
        .sheet(isPresented: $showingPlayer) {
            NavigationStack {
                VideoPlayerView(videoURL: export.fileURL)
                    .navigationTitle("Exported Video")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingPlayer = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [export.fileURL])
        }
    }
}

//struct ShareSheet: UIViewControllerRepresentable {
//    let items: [Any]
//    
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        UIActivityViewController(activityItems: items, applicationActivities: nil)
//    }
//    
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}
