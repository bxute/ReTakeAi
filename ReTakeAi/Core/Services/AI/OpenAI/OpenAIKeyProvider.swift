//
//  OpenAIKeyProvider.swift
//  ReTakeAi
//

import Foundation

enum OpenAIKeyProvider {
    static func apiKeyFromBundle() -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}


