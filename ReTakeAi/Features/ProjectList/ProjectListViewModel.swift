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
    
    private let projectStore = ProjectStore.shared
    
    init() {
        loadProjects()
    }
    
    func loadProjects() {
        projects = projectStore.projects
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
    
    var recentProjects: [Project] {
        Array(projects.prefix(5))
    }
}
