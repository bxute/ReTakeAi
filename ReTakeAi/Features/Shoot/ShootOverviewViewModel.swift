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

    func bestTake(for scene: VideoScene) -> Take? {
        let all = getTakes(for: scene)
        guard !all.isEmpty else { return nil }

        if let preferredID = scene.selectedTakeID,
           let preferred = all.first(where: { $0.id == preferredID }) {
            return preferred
        }

        // Fallback best = latest take (highest takeNumber).
        return all.max(by: { $0.takeNumber < $1.takeNumber })
    }

    var recordedScenesCount: Int {
        scenes.filter { hasTakes(for: $0) }.count
    }

    var isReadyToExport: Bool {
        !scenes.isEmpty && scenes.allSatisfy { hasTakes(for: $0) }
    }

    var nextSceneToRecord: VideoScene? {
        // Prefer first scene with no takes yet (check actual takes, not cached takeIDs).
        scenes.sorted(by: { $0.orderIndex < $1.orderIndex }).first { !hasTakes(for: $0) }
    }

    /// Check if scene has actual takes in the store (not just cached takeIDs).
    func hasTakes(for scene: VideoScene) -> Bool {
        !(takes[scene.id] ?? []).isEmpty
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


