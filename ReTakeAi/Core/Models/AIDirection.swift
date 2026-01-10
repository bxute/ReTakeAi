//
//  AIDirection.swift
//  ReTakeAi
//

import Foundation

struct AIDirection: Codable, Hashable, Sendable {
    var tone: Tone
    var delivery: String
    var actorInstructions: String

    enum CodingKeys: String, CodingKey {
        case tone
        case delivery
        case actorInstructions = "actor_instructions"
    }

    enum Tone: String, Codable, CaseIterable, Identifiable, Sendable {
        case professional = "Professional"
        case emotional = "Emotional"
        case energetic = "Energetic"
        case calm = "Calm"
        case cinematic = "Cinematic"
        case fun = "Fun"
        case serious = "Serious"

        var id: String { rawValue }

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            let raw = try c.decode(String.self)
            let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            switch normalized {
            case "professional": self = .professional
            case "emotional": self = .emotional
            case "energetic": self = .energetic
            case "calm": self = .calm
            case "cinematic": self = .cinematic
            case "fun": self = .fun
            case "serious": self = .serious
            default:
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown tone: \(raw)")
            }
        }
    }
}


