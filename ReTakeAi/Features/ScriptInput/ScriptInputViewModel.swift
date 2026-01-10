//
//  ScriptInputViewModel.swift
//  ReTakeAi
//

import Foundation

@MainActor
@Observable
class ScriptInputViewModel {
    var scriptText: String = ""
    var isGeneratingScenes = false
    var errorMessage: String?
    var generatedScenes: [SceneScript] = []
    
    let projectID: UUID
    
    private let projectStore = ProjectStore.shared
    private let sceneStore = SceneStore.shared
    private let aiService: AIServiceProtocol = MockAIService()
    
    @ObservationIgnored private var autosaveDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastAutosavedText: String = ""
    
    init(project: Project) {
        self.projectID = project.id
        self.scriptText = project.script ?? ""
        self.lastAutosavedText = self.scriptText
    }
    
    @discardableResult
    func saveScript() -> Bool {
        guard var latestProject = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            return false
        }
        
        latestProject.script = scriptText
        
        do {
            try projectStore.updateProject(latestProject)
            AppLogger.ui.info("Script saved")
            lastAutosavedText = scriptText
            return true
        } catch {
            errorMessage = "Failed to save script: \(error.localizedDescription)"
            return false
        }
    }
    
    func scheduleAutoSave(after seconds: TimeInterval = 2.0) {
        autosaveDebounceTask?.cancel()
        autosaveDebounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            
            let trimmed = self.scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastTrimmed = self.lastAutosavedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed != lastTrimmed else { return }
            
            do {
                guard var latestProject = self.projectStore.getProject(by: self.projectID) else {
                    self.errorMessage = "Project not found"
                    return
                }
                latestProject.script = self.scriptText
                try await self.projectStore.updateProjectAsync(latestProject)
                self.lastAutosavedText = self.scriptText
                AppLogger.ui.info("Script autosaved")
            } catch {
                self.errorMessage = "Failed to autosave script: \(error.localizedDescription)"
            }
        }
    }
    
    func cancelAutoSave() {
        autosaveDebounceTask?.cancel()
        autosaveDebounceTask = nil
    }
    
    func generateScenes() async {
        guard !scriptText.isEmpty else {
            errorMessage = "Please enter a script first"
            return
        }
        
        isGeneratingScenes = true
        errorMessage = nil
        
        do {
            generatedScenes = try await aiService.generateScenes(from: scriptText)
            AppLogger.ui.info("Generated \(self.generatedScenes.count) scenes")
        } catch {
            errorMessage = "Failed to generate scenes: \(error.localizedDescription)"
            AppLogger.ui.error("Scene generation failed: \(error.localizedDescription)")
        }
        
        isGeneratingScenes = false
    }
    
    func confirmScenes() async -> Bool {
        guard !generatedScenes.isEmpty else { return false }
        
        do {
            _ = saveScript()
            
            guard var currentProject = projectStore.getProject(by: projectID) else {
                errorMessage = "Project not found"
                return false
            }
            
            for sceneScript in generatedScenes {
                let scene = try sceneStore.createScene(
                    projectID: projectID,
                    orderIndex: sceneScript.orderIndex,
                    scriptText: sceneScript.scriptText
                )
                
                // Update local project reference
                currentProject.sceneIDs.append(scene.id)
            }
            
            // Save the project with all scene IDs at once
            currentProject.status = .recording
            try projectStore.updateProject(currentProject)
            
            AppLogger.ui.info("Confirmed and saved \(self.generatedScenes.count) scenes")
            return true
        } catch {
            errorMessage = "Failed to save scenes: \(error.localizedDescription)"
            return false
        }
    }
    
    var canGenerateScenes: Bool {
        !scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var hasGeneratedScenes: Bool {
        !generatedScenes.isEmpty
    }
    
}
