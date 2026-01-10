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

    struct Response: Decodable, Sendable {
        struct Scene: Decodable, Sendable {
            let orderIndex: Int
            let scriptText: String
            let expectedDurationSeconds: Int
            let direction: AIDirection?

            enum CodingKeys: String, CodingKey {
                case orderIndex
                case scriptText
                case expectedDurationSeconds
                case direction
            }
        }

        let schemaVersion: String
        let durationSeconds: Double
        let narration: String
        let direction: AIDirection
        let scenes: [Scene]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case durationSeconds = "duration_seconds"
            case narration
            case direction
            case scenes
        }
    }

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
        maxCompletionTokens: Int? = 1400
    ) async throws -> (promptUsed: String, response: Response) {
        let duration = Swift.max(10, Swift.min(expectedDurationSeconds, 300))

        let promptUsed = """
        You are an assistant that rewrites a complete script into final spoken narration and breaks it into recordable scenes.

        Requirements:
        - Return JSON only, matching the schema exactly (no extra fields).
        - narration must be spoken text only (no headings, no stage directions).
        - scenes[*].scriptText must be spoken text only for that scene.
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
                                "scriptText": .string(minLength: 1),
                                "expectedDurationSeconds": .integer(minimum: 1),
                                // Per-scene direction is optional (still validated if present).
                                "direction": directionSchema(requireToneEnum: true)
                            ],
                            required: ["orderIndex", "scriptText", "expectedDurationSeconds"],
                            additionalProperties: false
                        ),
                        minItems: 1
                    )
                ],
                required: ["schema_version", "duration_seconds", "narration", "direction", "scenes"],
                additionalProperties: false
            )
        )

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
            maxCompletionTokens: maxCompletionTokens,
            responseFormat: .jsonSchema(schema)
        )

        let decoded: Response = try await client.sendJSON(apiKey: apiKey, requestBody: request, responseType: Response.self)
        try validate(decoded)
        return (promptUsed: promptUsed, response: decoded)
    }

    private func validate(_ response: Response) throws {
        guard response.schemaVersion == "1.0" else {
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
                  !scene.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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


