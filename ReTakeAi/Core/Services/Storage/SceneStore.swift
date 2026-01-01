//
//  SceneStore.swift
//  ReTakeAi
//

import Foundation

class SceneStore: ObservableObject {
    static let shared = SceneStore()
    
    private let fileManager = FileStorageManager.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func createScene(projectID: UUID, orderIndex: Int, scriptText: String) throws -> VideoScene {
        let scene = VideoScene(projectID: projectID, orderIndex: orderIndex, scriptText: scriptText)
        
        try fileManager.createSceneDirectory(for: scene.id, projectID: projectID)
        try saveScene(scene)
        
        AppLogger.storage.info("Created scene \(orderIndex) for project")
        return scene
    }
    
    func updateScene(_ scene: VideoScene) throws {
        try saveScene(scene)
        AppLogger.storage.info("Updated scene: \(scene.id.uuidString)")
    }
    
    func deleteScene(_ scene: VideoScene) throws {
        try fileManager.deleteScene(sceneID: scene.id, projectID: scene.projectID)
        AppLogger.storage.info("Deleted scene: \(scene.id.uuidString)")
    }
    
    func getScene(sceneID: UUID, projectID: UUID) -> VideoScene? {
        loadScene(sceneID: sceneID, projectID: projectID)
    }
    
    func getScenes(for project: Project) -> [VideoScene] {
        project.sceneIDs.compactMap { sceneID in
            loadScene(sceneID: sceneID, projectID: project.id)
        }.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    func addTake(_ take: Take, to scene: VideoScene) throws {
        var updatedScene = scene
        updatedScene.takeIDs.append(take.id)
        try updateScene(updatedScene)
    }
    
    func selectTake(_ take: Take, for scene: VideoScene) throws {
        var updatedScene = scene
        updatedScene.selectedTakeID = take.id
        try updateScene(updatedScene)
    }
    
    private func saveScene(_ scene: VideoScene) throws {
        let sceneDir = fileManager.sceneDirectory(for: scene.id, projectID: scene.projectID)
        let fileURL = sceneDir.appendingPathComponent(Constants.Storage.sceneFileName)
        
        let data = try encoder.encode(scene)
        try data.write(to: fileURL)
    }
    
    private func loadScene(sceneID: UUID, projectID: UUID) -> VideoScene? {
        let sceneDir = fileManager.sceneDirectory(for: sceneID, projectID: projectID)
        let fileURL = sceneDir.appendingPathComponent(Constants.Storage.sceneFileName)
        
        guard let data = try? Data(contentsOf: fileURL),
              let scene = try? decoder.decode(VideoScene.self, from: data) else {
            AppLogger.storage.error("Failed to load scene: \(sceneID.uuidString)")
            return nil
        }
        
        return scene
    }
}
