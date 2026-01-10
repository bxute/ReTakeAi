//
//  ShootOverviewViewModel.swift
//  ReTakeAi
//

import Foundation

@MainActor
@Observable
final class ShootOverviewViewModel {
    var project: Project?
    var scenes: [VideoScene] = []
    var takes: [UUID: [Take]] = [:]
    var errorMessage: String?
    var isLoading = false

    let projectID: UUID

    private let projectStore = ProjectStore.shared
    private let sceneStore = SceneStore.shared
    private let takeStore = TakeStore.shared

    init(projectID: UUID) {
        self.projectID = projectID
        load()
    }

    func load() {
        guard let latest = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            project = nil
            scenes = []
            takes = [:]
            return
        }

        project = latest
        scenes = sceneStore.getScenes(for: latest)
        takes = [:]
        for scene in scenes {
            takes[scene.id] = takeStore.getTakes(for: scene)
        }
    }

    func getTakes(for scene: VideoScene) -> [Take] {
        takes[scene.id] ?? []
    }

    var recordedScenesCount: Int {
        scenes.filter { $0.isRecorded }.count
    }

    var isReadyToExport: Bool {
        !scenes.isEmpty && scenes.allSatisfy { $0.isComplete }
    }

    var nextSceneToRecord: VideoScene? {
        // Prefer first scene with no takes yet.
        scenes.first { !$0.isRecorded }
    }

    func deleteExport(_ export: ExportedVideo) {
        guard var current = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            return
        }

        current.exports.removeAll { $0.id == export.id }

        do {
            try FileManager.default.removeItem(at: export.fileURL)
        } catch {
            // If file deletion fails, still allow metadata removal.
        }

        do {
            try projectStore.updateProject(current)
            project = current
        } catch {
            errorMessage = "Failed to delete export: \(error.localizedDescription)"
        }
    }
}


