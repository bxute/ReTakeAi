//
//  SceneReviewViewModel.swift
//  ReTakeAi
//

import Foundation

@MainActor
@Observable
class SceneReviewViewModel {
    var scenes: [VideoScene] = []
    var takes: [UUID: [Take]] = [:]
    var selectedTake: Take?
    var isLoading = false
    var errorMessage: String?
    
    let project: Project
    
    private let sceneStore = SceneStore.shared
    private let takeStore = TakeStore.shared
    private let projectStore = ProjectStore.shared
    
    init(project: Project) {
        self.project = project
        loadScenes()
    }
    
    func loadScenes() {
        scenes = sceneStore.getScenes(for: project)
        
        for scene in scenes {
            takes[scene.id] = takeStore.getTakes(for: scene)
        }
    }
    
    func getTakes(for scene: VideoScene) -> [Take] {
        takes[scene.id] ?? []
    }
    
    func selectTake(_ take: Take, for scene: VideoScene) {
        do {
            try sceneStore.selectTake(take, for: scene)
            loadScenes()
            AppLogger.ui.info("Selected take \(take.takeNumber) for scene \(scene.orderIndex)")
        } catch {
            errorMessage = "Failed to select take: \(error.localizedDescription)"
        }
    }
    
    func deleteTake(_ take: Take, from scene: VideoScene) {
        do {
            try takeStore.deleteTake(take)
            
            takes[scene.id] = takeStore.getTakes(for: scene)
            
            AppLogger.ui.info("Deleted take \(take.takeNumber)")
        } catch {
            errorMessage = "Failed to delete take: \(error.localizedDescription)"
        }
    }
    
    func nextIncompleteScene() -> VideoScene? {
        scenes.first { !$0.isComplete }
    }
    
    func hasNextScene(after scene: VideoScene) -> Bool {
        guard let index = scenes.firstIndex(where: { $0.id == scene.id }) else {
            return false
        }
        return index < scenes.count - 1
    }
    
    func getNextScene(after scene: VideoScene) -> VideoScene? {
        guard let index = scenes.firstIndex(where: { $0.id == scene.id }),
              index < scenes.count - 1 else {
            return nil
        }
        return scenes[index + 1]
    }
    
    func updateProjectStatus() {
        let allScenesComplete = scenes.allSatisfy { $0.isComplete }
        
        if allScenesComplete {
            var updatedProject = project
            updatedProject.status = .completed
            
            do {
                try projectStore.updateProject(updatedProject)
                AppLogger.ui.info("All scenes complete, project marked as completed")
            } catch {
                errorMessage = "Failed to update project status: \(error.localizedDescription)"
            }
        }
    }
    
    var allScenesComplete: Bool {
        !scenes.isEmpty && scenes.allSatisfy { $0.isComplete }
    }
    
    var completionProgress: Double {
        guard !scenes.isEmpty else { return 0 }
        let completed = scenes.filter { $0.isComplete }.count
        return Double(completed) / Double(scenes.count)
    }
    
    var incompleteScenes: [VideoScene] {
        scenes.filter { !$0.isComplete }
    }
}
