//
//  ProjectListViewModel.swift
//  SceneFlow
//

import Foundation

@MainActor
@Observable
class ProjectListViewModel {
    var projects: [Project] = []
    var isLoading = false
    var errorMessage: String?
    var showingCreateProject = false
    var progressByProjectID: [UUID: ProjectProgress] = [:]
    
    private let projectStore = ProjectStore.shared
    private let sceneStore = SceneStore.shared
    
    init() {
        loadProjects()
    }
    
    func loadProjects() {
        projects = projectStore.projects.sorted { $0.updatedAt > $1.updatedAt }
        progressByProjectID = Dictionary(uniqueKeysWithValues: projects.map { project in
            let scenes = sceneStore.getScenes(for: project)
            let recorded = scenes.filter { $0.isRecorded }.count
            let total = scenes.count
            let next = scenes.first(where: { !$0.isRecorded })?.orderIndex ?? scenes.first?.orderIndex ?? 0
            return (project.id, ProjectProgress(totalScenes: total, recordedScenes: recorded, nextSceneNumber: next + 1))
        })
    }
    
    func refresh() {
        loadProjects()
    }
    
    func createProject(title: String, script: String? = nil) {
        do {
            let project = try projectStore.createProject(title: title, script: script)
            loadProjects()
            AppLogger.ui.info("Created project: \(title)")
        } catch {
            errorMessage = "Failed to create project: \(error.localizedDescription)"
            AppLogger.ui.error("Failed to create project: \(error.localizedDescription)")
        }
    }
    
    func deleteProject(_ project: Project) {
        do {
            try projectStore.deleteProject(project)
            loadProjects()
            AppLogger.ui.info("Deleted project: \(project.title)")
        } catch {
            errorMessage = "Failed to delete project: \(error.localizedDescription)"
            AppLogger.ui.error("Failed to delete project: \(error.localizedDescription)")
        }
    }
    
    func updateProjectStatus(_ project: Project, status: ProjectStatus) {
        var updatedProject = project
        updatedProject.status = status
        
        do {
            try projectStore.updateProject(updatedProject)
            loadProjects()
        } catch {
            errorMessage = "Failed to update project: \(error.localizedDescription)"
        }
    }
    
    var hasProjects: Bool {
        !projects.isEmpty
    }

    var resumeProject: Project? {
        // Most recently edited, non-exported, in-progress project.
        projects.first(where: { project in
            guard project.status != .exported && (project.status == .draft || project.status == .recording) else { return false }
            return (progressByProjectID[project.id]?.totalScenes ?? 0) > 0
        })
    }

    func progress(for project: Project) -> ProjectProgress {
        progressByProjectID[project.id] ?? ProjectProgress(totalScenes: 0, recordedScenes: 0, nextSceneNumber: 1)
    }

    struct ProjectProgress: Hashable {
        let totalScenes: Int
        let recordedScenes: Int
        let nextSceneNumber: Int
    }
    
    var recentProjects: [Project] {
        Array(projects.prefix(5))
    }
}
