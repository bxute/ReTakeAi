//
//  AIServiceProtocol.swift
//  SceneFlow
//

import Foundation

protocol AIServiceProtocol {
    func generateScenes(from script: String) async throws -> [SceneScript]
    func scoreTake(videoURL: URL, sceneScript: String) async throws -> TakeScore
    func provideFeedback(videoURL: URL, sceneScript: String) async throws -> DirectorFeedback
}

struct SceneScript: Identifiable, Codable {
    let id: UUID
    let orderIndex: Int
    let scriptText: String
    let estimatedDuration: TimeInterval?
    let notes: String?
    
    init(
        id: UUID = UUID(),
        orderIndex: Int,
        scriptText: String,
        estimatedDuration: TimeInterval? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.scriptText = scriptText
        self.estimatedDuration = estimatedDuration
        self.notes = notes
    }
}

struct TakeScore: Codable {
    let score: Double
    let confidence: Double
    let breakdown: ScoreBreakdown
    
    struct ScoreBreakdown: Codable {
        let audioQuality: Double
        let visualQuality: Double
        let pacing: Double
        let clarity: Double
    }
}

struct DirectorFeedback: Codable {
    let overallAssessment: String
    let strengths: [String]
    let improvements: [String]
    let technicalNotes: String?
    let suggestedRetake: Bool
}

class MockAIService: AIServiceProtocol {
    func generateScenes(from script: String) async throws -> [SceneScript] {
        let paragraphs = script
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        return paragraphs.enumerated().map { index, text in
            SceneScript(
                orderIndex: index,
                scriptText: text,
                estimatedDuration: nil,
                notes: nil
            )
        }
    }
    
    func scoreTake(videoURL: URL, sceneScript: String) async throws -> TakeScore {
        return TakeScore(
            score: 75.0,
            confidence: 0.5,
            breakdown: TakeScore.ScoreBreakdown(
                audioQuality: 75,
                visualQuality: 75,
                pacing: 75,
                clarity: 75
            )
        )
    }
    
    func provideFeedback(videoURL: URL, sceneScript: String) async throws -> DirectorFeedback {
        return DirectorFeedback(
            overallAssessment: "Good take! Consider another if you want to try a different approach.",
            strengths: ["Clear delivery", "Good framing"],
            improvements: ["Could vary pacing slightly"],
            technicalNotes: nil,
            suggestedRetake: false
        )
    }
}
