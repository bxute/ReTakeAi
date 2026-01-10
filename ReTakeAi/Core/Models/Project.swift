//
//  Project.swift
//  SceneFlow
//

import Foundation

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var script: String?
    var scriptIntent: ScriptIntent?
    /// Expected total video duration (seconds). Used for generation guidance and pacing.
    var expectedDurationSeconds: Int?
    var toneMood: ScriptToneMood?
    /// Latest AI direction metadata for the project's narration (if generated).
    var aiDirection: AIDirection?
    /// Schema version of the last AI generation response (if provided).
    var aiSchemaVersion: String?
    /// Duration suggested by AI for the narration (seconds).
    var aiNarrationDurationSeconds: Double?
    var sceneIDs: [UUID]
    var status: ProjectStatus
    var videoAspect: VideoAspect
    var exports: [ExportedVideo]
    
    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        script: String? = nil,
        scriptIntent: ScriptIntent? = nil,
        expectedDurationSeconds: Int? = nil,
        toneMood: ScriptToneMood? = nil,
        aiDirection: AIDirection? = nil,
        aiSchemaVersion: String? = nil,
        aiNarrationDurationSeconds: Double? = nil,
        sceneIDs: [UUID] = [],
        status: ProjectStatus = .draft,
        videoAspect: VideoAspect = .portrait9x16,
        exports: [ExportedVideo] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.script = script
        self.scriptIntent = scriptIntent
        self.expectedDurationSeconds = expectedDurationSeconds
        self.toneMood = toneMood
        self.aiDirection = aiDirection
        self.aiSchemaVersion = aiSchemaVersion
        self.aiNarrationDurationSeconds = aiNarrationDurationSeconds
        self.sceneIDs = sceneIDs
        self.status = status
        self.videoAspect = videoAspect
        self.exports = exports
    }
    
    var projectFolderPath: URL {
        FileStorageManager.shared.projectDirectory(for: id)
    }

    // Backwards-compatible decoding with defaults for older on-disk projects.
    enum CodingKeys: String, CodingKey {
        case id, title, createdAt, updatedAt, script, scriptIntent, expectedDurationSeconds, toneMood, aiDirection, aiSchemaVersion, aiNarrationDurationSeconds, sceneIDs, status, videoAspect, exports
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        script = try c.decodeIfPresent(String.self, forKey: .script)
        scriptIntent = try c.decodeIfPresent(ScriptIntent.self, forKey: .scriptIntent)
        expectedDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .expectedDurationSeconds)
        toneMood = try c.decodeIfPresent(ScriptToneMood.self, forKey: .toneMood)
        aiDirection = try c.decodeIfPresent(AIDirection.self, forKey: .aiDirection)
        aiSchemaVersion = try c.decodeIfPresent(String.self, forKey: .aiSchemaVersion)
        aiNarrationDurationSeconds = try c.decodeIfPresent(Double.self, forKey: .aiNarrationDurationSeconds)
        sceneIDs = try c.decodeIfPresent([UUID].self, forKey: .sceneIDs) ?? []
        status = try c.decodeIfPresent(ProjectStatus.self, forKey: .status) ?? .draft
        videoAspect = try c.decodeIfPresent(VideoAspect.self, forKey: .videoAspect) ?? .portrait9x16
        exports = try c.decodeIfPresent([ExportedVideo].self, forKey: .exports) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(script, forKey: .script)
        try c.encodeIfPresent(scriptIntent, forKey: .scriptIntent)
        try c.encodeIfPresent(expectedDurationSeconds, forKey: .expectedDurationSeconds)
        try c.encodeIfPresent(toneMood, forKey: .toneMood)
        try c.encodeIfPresent(aiDirection, forKey: .aiDirection)
        try c.encodeIfPresent(aiSchemaVersion, forKey: .aiSchemaVersion)
        try c.encodeIfPresent(aiNarrationDurationSeconds, forKey: .aiNarrationDurationSeconds)
        try c.encode(sceneIDs, forKey: .sceneIDs)
        try c.encode(status, forKey: .status)
        try c.encode(videoAspect, forKey: .videoAspect)
        try c.encode(exports, forKey: .exports)
    }
}

enum ProjectStatus: String, Codable {
    case draft
    case recording
    case completed
    case exported
}
