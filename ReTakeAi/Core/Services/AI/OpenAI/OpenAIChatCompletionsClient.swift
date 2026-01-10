//
//  OpenAIChatCompletionsClient.swift
//  ReTakeAi
//

import Foundation

struct OpenAIChatCompletionsClient {
    enum Error: Swift.Error, LocalizedError, Sendable {
        case invalidHTTPResponse
        case httpError(statusCode: Int, body: String)
        case missingContent
        case decodingFailed(rawContent: String, underlying: Swift.Error)

        var errorDescription: String? {
            switch self {
            case .invalidHTTPResponse:
                return "OpenAI: Invalid (non-HTTP) response."
            case .httpError(let statusCode, let body):
                if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "OpenAI: HTTP \(statusCode) (empty body)."
                }
                return "OpenAI: HTTP \(statusCode): \(body)"
            case .missingContent:
                return "OpenAI: Missing message content (empty content)."
            case .decodingFailed(let rawContent, let underlying):
                return "OpenAI: Failed to decode structured JSON. Underlying: \(underlying.localizedDescription). Raw: \(rawContent)"
            }
        }
    }

    let session: URLSession
    let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL = URL(string: "https://api.openai.com")!) {
        self.session = session
        self.baseURL = baseURL
    }

    private var shouldLogPayloadsInDebug: Bool {
#if DEBUG
        return ProcessInfo.processInfo.environment["OPENAI_DEBUG_LOG_PAYLOADS"] == "1"
#else
        return false
#endif
    }

    func sendJSON<T: Decodable>(
        apiKey: String,
        requestBody: OpenAIChatCompletionsRequest,
        responseType: T.Type = T.self
    ) async throws -> T {
        let url = baseURL.appendingPathComponent("/v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        request.httpBody = try encoder.encode(requestBody)

#if DEBUG
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            if shouldLogPayloadsInDebug {
                AppLogger.ai.info("OpenAI request body: \(bodyString, privacy: .public)")
            } else {
                AppLogger.ai.info("OpenAI request body (set OPENAI_DEBUG_LOG_PAYLOADS=1 to print): \(bodyString, privacy: .private(mask: .hash))")
            }
        } else {
            AppLogger.ai.info("OpenAI request body: <empty>")
        }
#endif

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Error.invalidHTTPResponse
        }

#if DEBUG
        let responseString = String(data: data, encoding: .utf8) ?? ""
        AppLogger.ai.info("OpenAI response status: \(http.statusCode)")
        if shouldLogPayloadsInDebug {
            AppLogger.ai.info("OpenAI response body: \(responseString, privacy: .public)")
        } else {
            AppLogger.ai.info("OpenAI response body (set OPENAI_DEBUG_LOG_PAYLOADS=1 to print): \(responseString, privacy: .private(mask: .hash))")
        }
#endif

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.httpError(statusCode: http.statusCode, body: body)
        }

        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(OpenAIChatCompletionsResponse.self, from: data)
        guard let raw = wrapper.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            throw Error.missingContent
        }

        // Some models return the JSON as a JSON-escaped string:
        // "{\"key\":\"value\"}". Unwrap that before decoding.
        let normalizedRaw: String = {
            if let rawData = raw.data(using: .utf8),
               let unwrapped = try? decoder.decode(String.self, from: rawData) {
                return unwrapped
            }
            return raw
        }()

        do {
            // Expect JSON-only output. Still try a safe extraction if something leaked.
            if let direct = normalizedRaw.data(using: .utf8), let decoded = try? decoder.decode(T.self, from: direct) {
                return decoded
            }
            if let extracted = Self.extractJSONObject(from: normalizedRaw),
               let data = extracted.data(using: .utf8) {
                return try decoder.decode(T.self, from: data)
            }
            if let extracted = Self.extractJSONArray(from: normalizedRaw),
               let data = extracted.data(using: .utf8) {
                return try decoder.decode(T.self, from: data)
            }
            throw Error.decodingFailed(rawContent: normalizedRaw, underlying: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not valid JSON")))
        } catch {
            throw Error.decodingFailed(rawContent: normalizedRaw, underlying: error)
        }
    }

    private static func extractJSONObject(from s: String) -> String? {
        guard let start = s.firstIndex(of: "{"),
              let end = s.lastIndex(of: "}") else { return nil }
        guard start < end else { return nil }
        return String(s[start...end])
    }

    private static func extractJSONArray(from s: String) -> String? {
        guard let start = s.firstIndex(of: "["),
              let end = s.lastIndex(of: "]") else { return nil }
        guard start < end else { return nil }
        return String(s[start...end])
    }
}


