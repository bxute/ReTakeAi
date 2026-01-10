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

    let projectID: UUID
    let mode: Mode

    private let projectStore = ProjectStore.shared
    private let sceneStore = SceneStore.shared
    private let openAIService = OpenAISceneBreakdownService()

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
                orderIndex: scene.orderIndex,
                scriptText: scene.scriptText,
                expectedDurationSeconds: Int((scene.duration ?? 0).rounded()).clamped(to: 1...600)
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

        if let apiKey = OpenAIKeyProvider.apiKeyFromBundle() {
            do {
                let response = try await openAIService.generateSceneBreakdown(
                    apiKey: apiKey,
                    promptUsed: prompt,
                    inputs: inputs
                )
                promptUsed = response.promptUsed
                drafts = response.drafts
                return
            } catch {
                // Fallback: deterministic splitter
            }
        }

        let fallback = SceneBreakdownGenerator.generateDeterministic(inputs: inputs)
        promptUsed = fallback.promptUsed
        drafts = fallback.scenes
    }

    var canSave: Bool {
        !drafts.isEmpty && drafts.allSatisfy { !$0.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.expectedDurationSeconds > 0 }
    }

    func saveReplacingScenes() async -> Bool {
        errorMessage = nil

        guard canSave else {
            errorMessage = "Please fix empty scenes before saving."
            return false
        }

        guard var project = projectStore.getProject(by: projectID) else {
            errorMessage = "Project not found"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Delete existing scene directories.
            let existingScenes = sceneStore.getScenes(for: project)
            for scene in existingScenes {
                try sceneStore.deleteScene(scene)
            }

            project.sceneIDs.removeAll()

            // Create new scenes.
            let sortedDrafts = drafts.sorted(by: { $0.orderIndex < $1.orderIndex })
            var newSceneIDs: [UUID] = []
            newSceneIDs.reserveCapacity(sortedDrafts.count)

            for (idx, draft) in sortedDrafts.enumerated() {
                var created = try sceneStore.createScene(projectID: project.id, orderIndex: idx, scriptText: draft.scriptText)
                created.duration = TimeInterval(draft.expectedDurationSeconds)
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
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}


