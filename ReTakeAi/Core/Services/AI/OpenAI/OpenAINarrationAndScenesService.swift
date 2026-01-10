//
//  OpenAINarrationAndScenesService.swift
//  ReTakeAi
//

import Foundation

struct OpenAINarrationAndScenesService {
    enum ValidationError: Swift.Error, Sendable {
        case invalidSchemaVersion(String)
        case invalidDuration(Double)
        case emptyNarration
        case emptyScenes
        case invalidScene(orderIndex: Int)
    }

    typealias Response = AINarrationAndScenesContract

    let client: OpenAIChatCompletionsClient

    init(client: OpenAIChatCompletionsClient = OpenAIChatCompletionsClient()) {
        self.client = client
    }

    func generateNarrationAndScenes(
        apiKey: String,
        projectTitle: String,
        scriptOrDraft: String,
        intent: ScriptIntent,
        toneMood: ScriptToneMood,
        expectedDurationSeconds: Int,
        maxCompletionTokens: Int? = 2400
    ) async throws -> (promptUsed: String, response: Response) {
        let duration = Swift.max(10, Swift.min(expectedDurationSeconds, 300))

        let promptUsed = """
        You are an assistant that rewrites a complete script into final spoken narration and breaks it into recordable scenes.

        Requirements:
        - Return JSON only, matching the schema exactly (no extra fields).
        - This is a rewrite: you MAY change wording from the source content to better fit the selected intent/tone and target duration.
        - narration must be spoken text only (no headings, no stage directions).
        - scenes[*].narration must be spoken text only for that scene (no headings, no stage directions).
        - Scenes must be consistent with the rewritten narration (do not preserve the original wording if you rewrote it).
        - Each scene should be short and recordable (one idea per scene).
        - Sum of scenes[*].expectedDurationSeconds should be approximately \(duration).
        - The overall tone should match the selected tone.

        Inputs:
        - Project title: "\(projectTitle)"
        - Intent: \(intent.rawValue)
        - Tone/Mood: \(toneMood.rawValue)
        - Target duration (seconds): \(duration)

        Source content to rewrite:
        \(scriptOrDraft)
        """

        let system = "You must output JSON only. No markdown. No extra text."

        let schema = OpenAIChatCompletionsRequest.JSONSchema(
            name: "narration_and_scenes_v1",
            strict: true,
            schema: .object(
                properties: [
                    "schema_version": .string(minLength: 3),
                    "duration_seconds": .number(minimum: 0.000_001),
                    "narration": .string(minLength: 1),
                    "direction": directionSchema(requireToneEnum: true),
                    "scenes": .array(
                        items: .object(
                            properties: [
                                "orderIndex": .integer(minimum: 0),
                                "narration": .string(minLength: 1),
                                "expectedDurationSeconds": .integer(minimum: 1),
                                // With strict schemas, all properties must be required.
                                "direction": directionSchema(requireToneEnum: true)
                            ],
                            required: ["orderIndex", "narration", "expectedDurationSeconds", "direction"],
                            additionalProperties: false
                        ),
                        minItems: 1
                    )
                ],
                required: ["schema_version", "duration_seconds", "narration", "direction", "scenes"],
                additionalProperties: false
            )
        )

        // Primary: gpt-5-mini (can be higher quality, but may burn tokens on reasoning).
        do {
            let request = OpenAIChatCompletionsRequest(
                model: "gpt-5-mini",
                messages: [
                    .init(role: "system", content: system),
                    .init(role: "user", content: promptUsed)
                ],
                // gpt-5-mini rejects non-default temperature/top_p in some accounts.
                temperature: nil,
                topP: nil,
                seed: nil,
                maxTokens: nil,
                maxCompletionTokens: maxCompletionTokens,
                responseFormat: .jsonSchema(schema)
            )

            let decoded: Response = try await client.sendJSON(apiKey: apiKey, requestBody: request, responseType: Response.self)
            try validate(decoded)
            return (promptUsed: promptUsed, response: decoded)
        } catch {
            // Fallback model: gpt-4o-mini tends to return actual JSON content rather than spending all tokens on reasoning.
            let fallbackRequest = OpenAIChatCompletionsRequest(
                model: "gpt-4o-mini",
                messages: [
                    .init(role: "system", content: system),
                    .init(role: "user", content: promptUsed)
                ],
                temperature: 0.0,
                topP: 1.0,
                seed: nil,
                maxTokens: 1200,
                maxCompletionTokens: nil,
                responseFormat: .jsonSchema(schema)
            )

            let decoded: Response = try await client.sendJSON(apiKey: apiKey, requestBody: fallbackRequest, responseType: Response.self)
            try validate(decoded)
            return (promptUsed: promptUsed, response: decoded)
        }
    }

    private func validate(_ response: Response) throws {
        guard response.schemaVersion == Response.schemaVersion else {
            throw ValidationError.invalidSchemaVersion(response.schemaVersion)
        }
        guard response.durationSeconds > 0, response.durationSeconds.isFinite else {
            throw ValidationError.invalidDuration(response.durationSeconds)
        }
        guard !response.narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyNarration
        }
        guard !response.scenes.isEmpty else {
            throw ValidationError.emptyScenes
        }
        for scene in response.scenes {
            guard scene.orderIndex >= 0,
                  scene.expectedDurationSeconds > 0,
                  !scene.narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidScene(orderIndex: scene.orderIndex)
            }
        }
    }

    private func directionSchema(requireToneEnum: Bool) -> OpenAIChatCompletionsRequest.Schema {
        // We represent `tone` as string in schema; `AIDirection.Tone` decoding will still fail on unknown values.
        // Keeping the schema simple avoids needing JSON Schema `enum` support in our encoder.
        .object(
            properties: [
                "tone": .string(minLength: requireToneEnum ? 1 : nil),
                "delivery": .string(minLength: 1),
                "actor_instructions": .string(minLength: 1)
            ],
            required: ["tone", "delivery", "actor_instructions"],
            additionalProperties: false
        )
    }
}


