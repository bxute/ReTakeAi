//
//  SceneBreakdownGenerator.swift
//  ReTakeAi
//

import Foundation

struct SceneBreakdownGenerator {
    struct Inputs: Hashable {
        var projectTitle: String
        var script: String
        var intent: ScriptIntent
        var toneMood: ScriptToneMood
        var expectedDurationSeconds: Int
    }

    struct Result: Hashable {
        var promptUsed: String
        var scenes: [GeneratedSceneDraft]
    }

    static func buildPrompt(inputs: Inputs) -> String {
        """
        You are an assistant that converts a script into a list of video scenes for scene-by-scene recording.

        Requirements:
        - Output must be valid JSON only.
        - Output schema: [{"orderIndex":0,"scriptText":"...","expectedDurationSeconds":12}]
        - Each scene scriptText must be exact spoken text for that scene.
        - expectedDurationSeconds must be an integer and scenes should total ~\(inputs.expectedDurationSeconds)s.
        - Keep scenes short and recordable (one idea per scene).

        Context:
        - Project title: "\(inputs.projectTitle)"
        - Intent: "\(inputs.intent.rawValue)"
        - Tone/Mood: "\(inputs.toneMood.rawValue)"
        - Target duration (seconds): \(inputs.expectedDurationSeconds)

        Script:
        \(inputs.script)
        """
    }

    /// Deterministic fallback breakdown that does not require network calls.
    static func generateDeterministic(inputs: Inputs) -> Result {
        let normalized = inputs.script
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let rawParts: [String]
        if paragraphs.count >= 2 {
            rawParts = paragraphs
        } else {
            rawParts = splitIntoSentenceChunks(normalized, maxChunks: 6)
        }

        let sceneCount = max(1, rawParts.count)
        let durations = allocateDurations(total: inputs.expectedDurationSeconds, count: sceneCount)

        let scenes = zip(rawParts, durations).enumerated().map { idx, pair in
            let (text, seconds) = pair
            return GeneratedSceneDraft(
                orderIndex: idx,
                scriptText: text,
                expectedDurationSeconds: seconds
            )
        }

        return Result(promptUsed: buildPrompt(inputs: inputs), scenes: scenes)
    }

    private static func splitIntoSentenceChunks(_ text: String, maxChunks: Int) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Very lightweight sentence splitting.
        let separators = CharacterSet(charactersIn: ".!?")
        let sentences = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count >= 2 else { return [trimmed] }

        let chunks = min(maxChunks, max(2, Int(ceil(Double(sentences.count) / 2.0))))
        let per = Int(ceil(Double(sentences.count) / Double(chunks)))

        var out: [String] = []
        out.reserveCapacity(chunks)

        var i = 0
        while i < sentences.count {
            let end = min(sentences.count, i + per)
            let chunk = sentences[i..<end].joined(separator: ". ") + "."
            out.append(chunk.trimmingCharacters(in: .whitespacesAndNewlines))
            i = end
        }
        return out
    }

    private static func allocateDurations(total: Int, count: Int) -> [Int] {
        let totalClamped = max(10, min(total, 5 * 60))
        let countClamped = max(1, min(count, 20))

        let minPer = 5
        let base = max(minPer, totalClamped / countClamped)
        var durations = Array(repeating: base, count: countClamped)

        var remaining = totalClamped - (base * countClamped)
        var idx = 0
        while remaining > 0 {
            durations[idx] += 1
            remaining -= 1
            idx = (idx + 1) % countClamped
        }

        return durations
    }
}


