//
//  ShootSceneDetailViewModel.swift
//  ReTakeAi
//

import Foundation

@MainActor
@Observable
final class ShootSceneDetailViewModel {
    var project: Project?
    var scene: VideoScene?
    var takes: [Take] = []
    var errorMessage: String?

    let projectID: UUID
    let sceneID: UUID

    private let projectStore = ProjectStore.shared
    private let sceneStore = SceneStore.shared
    private let takeStore = TakeStore.shared

    init(projectID: UUID, sceneID: UUID) {
        self.projectID = projectID
        self.sceneID = sceneID
        load()
    }

    func load() {
        guard let p = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            project = nil
            scene = nil
            takes = []
            return
        }

        project = p

        guard let s = sceneStore.getScene(sceneID: sceneID, projectID: projectID) else {
            errorMessage = "Scene not found"
            scene = nil
            takes = []
            return
        }

        scene = s
        takes = takeStore.getTakes(for: s).sorted(by: { $0.takeNumber < $1.takeNumber })
    }

    func deleteTake(_ take: Take) {
        guard scene != nil else { return }
        do {
            try takeStore.deleteTake(take)
            // Scene metadata is migrated based on disk; reload to reflect takeIDs + preferred take.
            load()
            // Notify other views (e.g., ShootOverviewView) to refresh
            NotificationCenter.default.post(name: .sceneDidUpdate, object: nil)
        } catch {
            errorMessage = "Failed to delete take: \(error.localizedDescription)"
        }
    }

    func markPreferred(_ take: Take) {
        guard let currentScene = scene else { return }
        do {
            try sceneStore.selectTake(take, for: currentScene)
            load()
        } catch {
            errorMessage = "Failed to mark preferred: \(error.localizedDescription)"
        }
    }
}


