//
//  OpenAISceneBreakdownService.swift
//  ReTakeAi
//

import Foundation

struct OpenAISceneBreakdownService {
    struct SceneBreakdownResponse: Decodable, Sendable {
        struct Scene: Decodable, Sendable {
            let orderIndex: Int
            let scriptText: String
            let expectedDurationSeconds: Int
        }
        let scenes: [Scene]
    }

    let client: OpenAIChatCompletionsClient

    init(client: OpenAIChatCompletionsClient = OpenAIChatCompletionsClient()) {
        self.client = client
    }

    func generateSceneBreakdown(
        apiKey: String,
        promptUsed: String,
        inputs: SceneBreakdownGenerator.Inputs,
        seed: Int? = 42,
        maxTokens: Int? = 1200
    ) async throws -> (promptUsed: String, drafts: [GeneratedSceneDraft]) {
        let system = """
        You must output JSON only. No markdown. No extra text.
        Return a single JSON object with this exact schema:
        {"scenes":[{"orderIndex":0,"scriptText":"...","expectedDurationSeconds":12}]}
        Rules:
        - No extra fields.
        - scriptText must be spoken text only for that scene.
        - expectedDurationSeconds must be an integer > 0.
        - Total expectedDurationSeconds across scenes should be approximately the target duration.
        """

        // Put the strictness and contract into the user content as well (helps some models).
        let user = SceneBreakdownGenerator.buildPrompt(inputs: inputs)

        let schema = OpenAIChatCompletionsRequest.JSONSchema(
            name: "scene_breakdown",
            strict: true,
            schema: .object(
                properties: [
                    "scenes": .array(
                        items: .object(
                            properties: [
                                "orderIndex": .integer(minimum: 0),
                                "scriptText": .string(minLength: 1),
                                "expectedDurationSeconds": .integer(minimum: 1)
                            ],
                            required: ["orderIndex", "scriptText", "expectedDurationSeconds"],
                            additionalProperties: false
                        ),
                        minItems: 1
                    )
                ],
                required: ["scenes"],
                additionalProperties: false
            )
        )

        let request = OpenAIChatCompletionsRequest(
            model: "gpt-5-mini",
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            temperature: 0.0,
            topP: 1.0,
            seed: seed,
            maxTokens: maxTokens,
            responseFormat: .jsonSchema(schema)
        )

        let decoded: SceneBreakdownResponse = try await client.sendJSON(
            apiKey: apiKey,
            requestBody: request,
            responseType: SceneBreakdownResponse.self
        )

        let drafts = decoded.scenes
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated()
            .map { idx, scene in
                GeneratedSceneDraft(
                    orderIndex: idx,
                    scriptText: scene.scriptText,
                    expectedDurationSeconds: Swift.max(1, scene.expectedDurationSeconds)
                )
            }

        return (promptUsed: promptUsed, drafts: drafts)
    }
}


