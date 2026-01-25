//
//  SceneBreakdownReviewViewModel.swift
//  ReTakeAi
//

import Foundation

@MainActor
@Observable
final class SceneBreakdownReviewViewModel {
    enum Mode: Hashable {
        /// Generate drafts from the current script and show them for review/edit.
        case generateFromScript(replaceExisting: Bool)
        /// Load existing scenes from storage and allow editing.
        case reviewExisting
    }

    var isLoading = false
    var errorMessage: String?
    var drafts: [GeneratedSceneDraft] = []
    var promptUsed: String?
    var projectDirection: AIDirection?
    var projectTitle: String = "Project"

    let projectID: UUID
    let mode: Mode

    private let projectStore = ProjectStore.shared
    private let sceneStore = SceneStore.shared
    private let openAIService = OpenAINarrationAndScenesService()

    init(projectID: UUID, mode: Mode) {
        self.projectID = projectID
        self.mode = mode
    }

    func load() async {
        errorMessage = nil

        guard let project = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            return
        }
        
        projectTitle = project.title
        projectDirection = project.aiDirection

        switch mode {
        case .reviewExisting:
            loadExisting(project: project)
        case .generateFromScript(let replaceExisting):
            await generateFromScript(project: project, replaceExisting: replaceExisting)
        }
    }

    private func loadExisting(project: Project) {
        let scenes = sceneStore.getScenes(for: project)
        drafts = scenes.sorted(by: { $0.orderIndex < $1.orderIndex }).map { scene in
            GeneratedSceneDraft(
                sourceSceneID: scene.id,
                orderIndex: scene.orderIndex,
                scriptText: scene.scriptText,
                expectedDurationSeconds: Int((scene.duration ?? 0).rounded()).clamped(to: 1...600),
                direction: scene.aiDirection ?? project.aiDirection
            )
        }
        promptUsed = nil
    }

    private func generateFromScript(project: Project, replaceExisting: Bool) async {
        let script = (project.script ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty else {
            errorMessage = "Please add a script first."
            drafts = []
            return
        }

        isLoading = true
        defer { isLoading = false }

#if DEBUG
        let hasExistingScenes = !self.sceneStore.getScenes(for: project).isEmpty
        AppLogger.ai.info("Scene breakdown: start (replaceExisting=\(replaceExisting), hasExisting=\(hasExistingScenes))")
#endif

        if !replaceExisting {
            let existing = sceneStore.getScenes(for: project)
            if !existing.isEmpty {
                errorMessage = "This project already has scenes."
                return
            }
        }

        let intent = project.scriptIntent ?? .explain
        let tone = project.toneMood ?? .professional
        let seconds = (project.expectedDurationSeconds ?? 30).clamped(to: 10...300)

        let inputs = SceneBreakdownGenerator.Inputs(
            projectTitle: project.title,
            script: script,
            intent: intent,
            toneMood: tone,
            expectedDurationSeconds: seconds
        )

        let prompt = SceneBreakdownGenerator.buildPrompt(inputs: inputs)

#if DEBUG
        let presence = OpenAIKeyProvider.debugKeyPresence()
        AppLogger.ai.info("Scene breakdown: key presence (bundle=\(presence.bundleHasKey), env=\(presence.environmentHasKey))")
#endif

        if let apiKey = OpenAIKeyProvider.apiKeyFromBundle() {
#if DEBUG
            AppLogger.ai.info("Scene breakdown: apiKey found, calling OpenAI")
#endif
            do {
                let combined = try await openAIService.generateNarrationAndScenes(
                    apiKey: apiKey,
                    projectTitle: inputs.projectTitle,
                    scriptOrDraft: inputs.script,
                    intent: inputs.intent,
                    toneMood: inputs.toneMood,
                    expectedDurationSeconds: inputs.expectedDurationSeconds
                )

                promptUsed = combined.promptUsed

                // Persist narration + direction metadata back to the project so it stays coherent.
                if var latest = projectStore.getProject(by: projectID) {
                    latest.script = combined.response.narration
                    latest.aiDirection = combined.response.direction
                    latest.aiSchemaVersion = combined.response.schemaVersion
                    latest.aiNarrationDurationSeconds = combined.response.durationSeconds
                    try? await projectStore.updateProjectAsync(latest)
                }
                
                projectDirection = combined.response.direction

                drafts = combined.response.scenes
                    .sorted(by: { $0.orderIndex < $1.orderIndex })
                    .enumerated()
                    .map { idx, s in
                        GeneratedSceneDraft(
                            orderIndex: idx,
                            scriptText: s.narration,
                            expectedDurationSeconds: Swift.max(1, s.expectedDurationSeconds),
                            direction: s.direction
                        )
                    }

                // Auto-persist AI generated scenes immediately.
                let saved = await saveReplacingScenes()
                if saved, let latest = projectStore.getProject(by: projectID) {
                    loadExisting(project: latest)
                }
#if DEBUG
                let count = self.drafts.count
                AppLogger.ai.info("Scene breakdown: OpenAI success (scenes=\(count))")
#endif
                return
            } catch {
                // Fallback: deterministic splitter
#if DEBUG
                AppLogger.ai.error("Scene breakdown: OpenAI failed, falling back. \(error.localizedDescription)")
#endif
            }
        } else {
#if DEBUG
            AppLogger.ai.error("Scene breakdown: OPENAI_API_KEY missing from Bundle, falling back")
#endif
        }

        let fallback = SceneBreakdownGenerator.generateDeterministic(inputs: inputs)
        promptUsed = fallback.promptUsed
        drafts = fallback.scenes
#if DEBUG
        AppLogger.ai.info("Scene breakdown: fallback produced drafts, auto-saving")
#endif
        let saved = await saveReplacingScenes()
        if saved, let latest = projectStore.getProject(by: projectID) {
            loadExisting(project: latest)
        }
#if DEBUG
        let count = self.drafts.count
        AppLogger.ai.info("Scene breakdown: fallback used (scenes=\(count))")
#endif
    }

    /// At least one non-empty scene is required
    var canSave: Bool {
        let nonEmptyDrafts = drafts.filter { !$0.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return !nonEmptyDrafts.isEmpty && nonEmptyDrafts.allSatisfy { $0.expectedDurationSeconds > 0 }
    }
    
    /// Add a new empty scene at the end
    func addNewEmptyScene() async {
        let newOrderIndex = (drafts.map { $0.orderIndex }.max() ?? -1) + 1
        let newDraft = GeneratedSceneDraft(
            orderIndex: newOrderIndex,
            scriptText: "",
            expectedDurationSeconds: 10
        )
        
        // Persist immediately
        guard var project = projectStore.getProject(by: projectID) else { return }
        
        do {
            var created = try sceneStore.createScene(projectID: project.id, orderIndex: newOrderIndex, scriptText: "")
            created.duration = 10
            try sceneStore.updateScene(created)
            project.sceneIDs.append(created.id)
            try await projectStore.updateProjectAsync(project)
            
            // Reload to get the new scene with proper sourceSceneID
            loadExisting(project: project)
        } catch {
            // Fallback: just add to local drafts
            drafts.append(newDraft)
        }
    }

    func saveReplacingScenes() async -> Bool {
        errorMessage = nil

        guard canSave else {
            errorMessage = "Please add at least one scene with narration."
            return false
        }

        guard var project = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // IMPORTANT: Do not delete old scene directories (they may contain takes).
            // We only detach them from the project by rewriting `sceneIDs`.
            project.sceneIDs.removeAll()

            // Filter out empty scenes and re-index
            let nonEmptyDrafts = drafts
                .filter { !$0.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted(by: { $0.orderIndex < $1.orderIndex })
            
            var newSceneIDs: [UUID] = []
            newSceneIDs.reserveCapacity(nonEmptyDrafts.count)

            for (idx, draft) in nonEmptyDrafts.enumerated() {
                var created = try sceneStore.createScene(projectID: project.id, orderIndex: idx, scriptText: draft.scriptText)
                created.duration = TimeInterval(draft.expectedDurationSeconds)
                created.aiDirection = draft.direction
                try sceneStore.updateScene(created)
                newSceneIDs.append(created.id)
            }

            project.sceneIDs = newSceneIDs
            if !newSceneIDs.isEmpty, project.status == .draft {
                project.status = .recording
            }

            try await projectStore.updateProjectAsync(project)
            return true
        } catch {
            errorMessage = "Failed to save scenes: \(error.localizedDescription)"
            return false
        }
    }

    func saveEditedDraft(_ draft: GeneratedSceneDraft) async -> Bool {
        errorMessage = nil

        guard let project = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            return false
        }

        let trimmed = draft.scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, draft.expectedDurationSeconds > 0 else {
            errorMessage = "Please enter narration and duration."
            return false
        }

        // If this draft maps to an existing scene, update it in place (preserves takes).
        if let sceneID = draft.sourceSceneID, var scene = sceneStore.getScene(sceneID: sceneID, projectID: project.id) {
            scene.scriptText = trimmed
            scene.duration = TimeInterval(draft.expectedDurationSeconds)
            scene.aiDirection = draft.direction
            do {
                try sceneStore.updateScene(scene)
                // Refresh draft list from storage to keep IDs consistent.
                let latestProject = projectStore.getProject(by: projectID) ?? project
                loadExisting(project: latestProject)
                return true
            } catch {
                errorMessage = "Failed to save scene: \(error.localizedDescription)"
                return false
            }
        }

        // Otherwise, it's an unsaved draft list (shouldn't happen after auto-save).
        // Fall back to replacing scenes without deleting old ones.
        return await saveReplacingScenes()
    }
    
    /// Delete a scene and reorder remaining scenes
    func deleteScene(_ draft: GeneratedSceneDraft) async {
        errorMessage = nil
        
        guard var project = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            return
        }
        
        // If this draft has a source scene, delete it from storage
        if let sceneID = draft.sourceSceneID,
           let scene = sceneStore.getScene(sceneID: sceneID, projectID: project.id) {
            // Remove from project's sceneIDs
            project.sceneIDs.removeAll { $0 == sceneID }
            
            // Delete the scene from store
            try? sceneStore.deleteScene(scene)
        }
        
        // Update project first
        try? await projectStore.updateProjectAsync(project)
        
        // Reload project to get updated sceneIDs
        guard let updatedProject = projectStore.getProject(by: projectID) else { return }
        
        // Reorder remaining scenes
        let remainingScenes = sceneStore.getScenes(for: updatedProject).sorted(by: { $0.orderIndex < $1.orderIndex })
        for (idx, var scene) in remainingScenes.enumerated() {
            if scene.orderIndex != idx {
                scene.orderIndex = idx
                try? sceneStore.updateScene(scene)
            }
        }
        
        // Reload drafts
        loadExisting(project: updatedProject)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}


