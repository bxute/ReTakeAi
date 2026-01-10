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
    }
}


