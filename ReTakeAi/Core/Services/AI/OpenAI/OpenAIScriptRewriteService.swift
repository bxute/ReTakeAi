//
//  OpenAIScriptRewriteService.swift
//  ReTakeAi
//

import Foundation

struct OpenAIScriptRewriteService {
    enum Error: Swift.Error, Sendable {
        case invalidSchemaVersion(String)
        case emptyNarration
        case nonPositiveDuration(Double)
    }

    struct Response: Decodable, Sendable {
        struct Direction: Decodable, Sendable {
            enum Tone: String, Decodable, Sendable {
                case professional = "Professional"
                case emotional = "Emotional"
                case energetic = "Energetic"
                case calm = "Calm"
                case cinematic = "Cinematic"
                case fun = "Fun"
                case serious = "Serious"
            }

            let tone: Tone
            let delivery: String
            let actorInstructions: String

            enum CodingKeys: String, CodingKey {
                case tone
                case delivery
                case actorInstructions = "actor_instructions"
            }
        }

        let schemaVersion: String
        let durationSeconds: Double
        let narration: String
        let direction: Direction

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case durationSeconds = "duration_seconds"
            case narration
            case direction
        }
    }

    let client: OpenAIChatCompletionsClient

    init(client: OpenAIChatCompletionsClient = OpenAIChatCompletionsClient()) {
        self.client = client
    }

    func rewriteScript(
        apiKey: String,
        projectTitle: String,
        existingDraftOrScript: String,
        intent: ScriptIntent,
        toneMood: ScriptToneMood,
        expectedDurationSeconds: Int,
        maxCompletionTokens: Int? = 900
    ) async throws -> (promptUsed: String, narration: String, durationSeconds: Double) {
        let duration = Swift.max(10, Swift.min(expectedDurationSeconds, 300))

        let promptUsed = """
        You are rewriting a video script for spoken narration.

        Return JSON only, strictly matching the schema. No extra fields.
        - narration must be spoken text only (no stage directions).
        - duration_seconds should be > 0 and reflect the target.

        Inputs:
        - Project title: "\(projectTitle)"
        - Intent: \(intent.rawValue)
        - Tone/Mood: \(toneMood.rawValue)
        - Target duration (seconds): \(duration)

        Existing script/draft to rewrite:
        \(existingDraftOrScript)
        """

        let system = """
        You must output JSON only. No markdown. No extra text.
        """

        let schema = OpenAIChatCompletionsRequest.JSONSchema(
            name: "script_rewrite_v1",
            strict: true,
            schema: .object(
                properties: [
                    "schema_version": .string(minLength: 3),
                    "duration_seconds": .number(minimum: 0.000_001),
                    "narration": .string(minLength: 1),
                    "direction": .object(
                        properties: [
                            "tone": .string(minLength: 1),
                            "delivery": .string(minLength: 1),
                            "actor_instructions": .string(minLength: 1)
                        ],
                        required: ["tone", "delivery", "actor_instructions"],
                        additionalProperties: false
                    )
                ],
                required: ["schema_version", "duration_seconds", "narration", "direction"],
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

        return (promptUsed: promptUsed, narration: decoded.narration, durationSeconds: decoded.durationSeconds)
    }

    private func validate(_ response: Response) throws {
        guard response.schemaVersion == "1.0" else {
            throw Error.invalidSchemaVersion(response.schemaVersion)
        }
        guard !response.narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Error.emptyNarration
        }
        guard response.durationSeconds > 0 else {
            throw Error.nonPositiveDuration(response.durationSeconds)
        }
    }
}


