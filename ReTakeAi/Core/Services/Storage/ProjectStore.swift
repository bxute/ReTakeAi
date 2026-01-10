//
//  ProjectStore.swift
//  ReTakeAi
//

import Foundation

class ProjectStore: ObservableObject {
    static let shared = ProjectStore()
    
    @Published private(set) var projects: [Project] = []
    
    private let fileManager = FileStorageManager.shared
    private let decoder = JSONDecoder()
    private let ioQueue = DispatchQueue(label: "com.retakeai.projectstore.io", qos: .utility)
    
    private init() {
        decoder.dateDecodingStrategy = .iso8601
        loadProjects()
    }
    
    func createProject(title: String, script: String? = nil) throws -> Project {
        let project = Project(title: title, script: script)
        
        try fileManager.createProjectDirectory(for: project.id)
        try saveProject(project)
        
        projects.append(project)
        AppLogger.storage.info("Created project: \(project.title)")
        
        return project
    }
    
    func updateProject(_ project: Project) throws {
        var updatedProject = project
        updatedProject.updatedAt = Date()
        
        try saveProject(updatedProject)
        
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = updatedProject
        }
        
        AppLogger.storage.info("Updated project: \(project.title)")
    }
    
    func updateProjectAsync(_ project: Project) async throws {
        let updated: Project = {
            var p = project
            p.updatedAt = Date()
            return p
        }()
        
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    try self.saveProjectIO(updated)
                    
                    DispatchQueue.main.async {
                        if let index = self.projects.firstIndex(where: { $0.id == updated.id }) {
                            self.projects[index] = updated
                        }
                        AppLogger.storage.info("Updated project: \(updated.title)")
                        continuation.resume()
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteProject(_ project: Project) throws {
        try fileManager.deleteProject(projectID: project.id)
        projects.removeAll { $0.id == project.id }
        AppLogger.storage.info("Deleted project: \(project.title)")
    }
    
    func getProject(by id: UUID) -> Project? {
        projects.first { $0.id == id }
    }
    
    private func saveProject(_ project: Project) throws {
        try saveProjectIO(project)
    }
    
    private func saveProjectIO(_ project: Project) throws {
        let projectDir = fileManager.projectDirectory(for: project.id)
        let fileURL = projectDir.appendingPathComponent(Constants.Storage.projectFileName)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        try data.write(to: fileURL)
    }
    
    private func loadProjects() {
        let projectIDs = fileManager.listProjects()
        
        projects = projectIDs.compactMap { projectID in
            loadProject(projectID: projectID)
        }.sorted { $0.updatedAt > $1.updatedAt }
        
        AppLogger.storage.info("Loaded \(self.projects.count) projects")
    }
    
    private func loadProject(projectID: UUID) -> Project? {
        let projectDir = fileManager.projectDirectory(for: projectID)
        let fileURL = projectDir.appendingPathComponent(Constants.Storage.projectFileName)
        
        guard let data = try? Data(contentsOf: fileURL),
              let project = try? decoder.decode(Project.self, from: data) else {
            AppLogger.storage.error("Failed to load project: \(projectID.uuidString)")
            return nil
        }
        
        return project
    }
    
    func addScene(_ scene: VideoScene, to project: Project) throws {
        var updatedProject = project
        updatedProject.sceneIDs.append(scene.id)
        try updateProject(updatedProject)
    }
    
    func removeScene(_ scene: VideoScene, from project: Project) throws {
        var updatedProject = project
        updatedProject.sceneIDs.removeAll { $0 == scene.id }
        try updateProject(updatedProject)
    }
}
