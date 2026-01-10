//
//  AINarrationAndScenesContract.swift
//  ReTakeAi
//

import Foundation

/// Frozen contract for combined AI generation:
/// - full narration
/// - global direction
/// - per-scene narration + duration + direction
struct AINarrationAndScenesContract: Codable, Hashable, Sendable {
    static let schemaVersion: String = "1.0"

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

    struct Scene: Codable, Hashable, Sendable {
        let orderIndex: Int
        /// Per-scene spoken narration.
        let narration: String
        let expectedDurationSeconds: Int
        let direction: AIDirection

        enum CodingKeys: String, CodingKey {
            case orderIndex
            case narration
            case expectedDurationSeconds
            case direction
        }
    }
}


