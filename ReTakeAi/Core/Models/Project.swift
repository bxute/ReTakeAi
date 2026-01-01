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
        case id, title, createdAt, updatedAt, script, sceneIDs, status, videoAspect, exports
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        script = try c.decodeIfPresent(String.self, forKey: .script)
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
