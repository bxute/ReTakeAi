//
//  OpenAIKeyProvider.swift
//  ReTakeAi
//

import Foundation

enum OpenAIKeyProvider {
    static func apiKeyFromBundle() -> String? {
        let secretKey = Secrets.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !secretKey.isEmpty { return secretKey }

        guard let value = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String else {
            return apiKeyFromEnvironment()
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return apiKeyFromEnvironment() }
        return trimmed
    }

    private static func apiKeyFromEnvironment() -> String? {
#if DEBUG
        if let value = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
#endif
        return nil
    }

#if DEBUG
    static func debugKeyPresence() -> (bundleHasKey: Bool, environmentHasKey: Bool) {
        let bundleValue = (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String) ?? ""
        let bundleHasKey = !bundleValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let envValue = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let environmentHasKey = !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return (bundleHasKey: bundleHasKey, environmentHasKey: environmentHasKey)
    }
#endif
}


