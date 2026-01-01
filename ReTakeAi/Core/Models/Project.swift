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
    
    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        script: String? = nil,
        sceneIDs: [UUID] = [],
        status: ProjectStatus = .draft
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.script = script
        self.sceneIDs = sceneIDs
        self.status = status
    }
    
    var projectFolderPath: URL {
        FileStorageManager.shared.projectDirectory(for: id)
    }
}

enum ProjectStatus: String, Codable {
    case draft
    case recording
    case completed
    case exported
}
