//
//  OpenAIChatCompletionsModels.swift
//  ReTakeAi
//

import Foundation

struct OpenAIChatCompletionsRequest: Encodable, Sendable {
    struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable, Sendable {
        let type: String
        let jsonSchema: JSONSchema?

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }

        static func jsonObject() -> ResponseFormat {
            ResponseFormat(type: "json_object", jsonSchema: nil)
        }

        static func jsonSchema(_ schema: JSONSchema) -> ResponseFormat {
            ResponseFormat(type: "json_schema", jsonSchema: schema)
        }
    }

    struct JSONSchema: Encodable, Sendable {
        let name: String
        let strict: Bool
        let schema: Schema
    }

    indirect enum Schema: Encodable, Sendable {
        case object(properties: [String: Schema], required: [String], additionalProperties: Bool)
        case array(items: Schema, minItems: Int?)
        case string(minLength: Int?)
        case integer(minimum: Int?)
        case number(minimum: Double?)
        case boolean

        private enum CodingKeys: String, CodingKey {
            case type
            case properties
            case required
            case additionalProperties
            case items
            case minItems
            case minLength
            case minimum
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .object(let properties, let required, let additionalProperties):
                try c.encode("object", forKey: .type)
                try c.encode(properties, forKey: .properties)
                try c.encode(required, forKey: .required)
                try c.encode(additionalProperties, forKey: .additionalProperties)

            case .array(let items, let minItems):
                try c.encode("array", forKey: .type)
                try c.encode(items, forKey: .items)
                try c.encodeIfPresent(minItems, forKey: .minItems)

            case .string(let minLength):
                try c.encode("string", forKey: .type)
                try c.encodeIfPresent(minLength, forKey: .minLength)

            case .integer(let minimum):
                try c.encode("integer", forKey: .type)
                try c.encodeIfPresent(minimum, forKey: .minimum)

            case .number(let minimum):
                try c.encode("number", forKey: .type)
                try c.encodeIfPresent(minimum, forKey: .minimum)

            case .boolean:
                try c.encode("boolean", forKey: .type)
            }
        }
    }

    let model: String
    let messages: [Message]
    let temperature: Double?
    let topP: Double?
    let seed: Int?
    /// For many models.
    let maxTokens: Int?
    /// Some newer models (including gpt-5-mini) require `max_completion_tokens` instead of `max_tokens`.
    let maxCompletionTokens: Int?
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case seed
        case maxTokens = "max_tokens"
        case maxCompletionTokens = "max_completion_tokens"
        case responseFormat = "response_format"
    }
}

struct OpenAIChatCompletionsResponse: Decodable, Sendable {
    struct Choice: Decodable, Sendable {
        struct Message: Decodable, Sendable {
            let content: String?
        }
        let message: Message
    }

    let choices: [Choice]
}


