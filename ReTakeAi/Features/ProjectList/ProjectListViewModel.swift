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
            let completed = scenes.filter { $0.isComplete }.count
            let total = scenes.count
            let next = scenes.first(where: { !$0.isComplete })?.orderIndex ?? scenes.first?.orderIndex ?? 0
            
            let hasScript = !(project.script ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isRecordComplete = total > 0 && completed == total
            let hasExport = !project.exports.isEmpty
            
            return (project.id, ProjectProgress(
                totalScenes: total,
                recordedScenes: recorded,
                completedScenes: completed,
                nextSceneNumber: next + 1,
                hasScript: hasScript,
                isRecordComplete: isRecordComplete,
                hasExport: hasExport
            ))
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

    func createProject(
        title: String,
        scriptIntent: ScriptIntent?,
        expectedDurationSeconds: Int?,
        toneMood: ScriptToneMood?
    ) {
        do {
            var project = try projectStore.createProject(title: title, script: nil)
            project.scriptIntent = scriptIntent
            project.expectedDurationSeconds = expectedDurationSeconds
            project.toneMood = toneMood
            try projectStore.updateProject(project)
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
        // Selection logic:
        // 1. Only consider projects that are NOT exported
        // 2. Prefer projects with recording in progress (some scenes recorded, not all complete)
        // 3. If none match, select most recently edited non-exported project with scenes
        // 4. If all projects are exported, return nil
        
        // Projects are already sorted by updatedAt (most recent first)
        let nonExported = projects.filter { project in
            guard let progress = progressByProjectID[project.id] else { return false }
            return !progress.hasExport
        }
        
        // First priority: projects with recording in progress
        if let inProgress = nonExported.first(where: { project in
            progressByProjectID[project.id]?.isRecordingInProgress == true
        }) {
            return inProgress
        }
        
        // Second priority: most recently edited non-exported project with scenes
        if let withScenes = nonExported.first(where: { project in
            (progressByProjectID[project.id]?.totalScenes ?? 0) > 0
        }) {
            return withScenes
        }
        
        return nil
    }

    func progress(for project: Project) -> ProjectProgress {
        progressByProjectID[project.id] ?? ProjectProgress(
            totalScenes: 0,
            recordedScenes: 0,
            completedScenes: 0,
            nextSceneNumber: 1,
            hasScript: false,
            isRecordComplete: false,
            hasExport: false
        )
    }

    struct ProjectProgress: Hashable {
        let totalScenes: Int
        let recordedScenes: Int
        let completedScenes: Int
        let nextSceneNumber: Int
        let hasScript: Bool
        let isRecordComplete: Bool
        let hasExport: Bool
        
        /// Recording is in progress if at least one scene is recorded but not all are complete
        var isRecordingInProgress: Bool {
            totalScenes > 0 && recordedScenes > 0 && !isRecordComplete
        }
    }
    
    var recentProjects: [Project] {
        Array(projects.prefix(5))
    }
}
