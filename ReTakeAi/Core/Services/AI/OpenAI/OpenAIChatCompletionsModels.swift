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
    }

    let model: String
    let messages: [Message]
    let temperature: Double?
    let topP: Double?
    let seed: Int?
    let maxOutputTokens: Int?
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case seed
        case maxOutputTokens = "max_output_tokens"
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


