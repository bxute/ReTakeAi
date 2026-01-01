//
//  Take.swift
//  SceneFlow
//

import Foundation

struct Take: Identifiable, Codable, Hashable {
    let id: UUID
    let sceneID: UUID
    var takeNumber: Int
    var recordedAt: Date
    var duration: TimeInterval
    var fileURL: URL
    var thumbnailURL: URL?
    var aiScore: Double?
    var aiNotes: String?
    var isSelected: Bool
    var fileSize: Int64
    var resolution: VideoResolution
    
    init(
        id: UUID = UUID(),
        sceneID: UUID,
        takeNumber: Int,
        recordedAt: Date = Date(),
        duration: TimeInterval,
        fileURL: URL,
        thumbnailURL: URL? = nil,
        aiScore: Double? = nil,
        aiNotes: String? = nil,
        isSelected: Bool = false,
        fileSize: Int64 = 0,
        resolution: VideoResolution = VideoResolution(width: 1920, height: 1080)
    ) {
        self.id = id
        self.sceneID = sceneID
        self.takeNumber = takeNumber
        self.recordedAt = recordedAt
        self.duration = duration
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.aiScore = aiScore
        self.aiNotes = aiNotes
        self.isSelected = isSelected
        self.fileSize = fileSize
        self.resolution = resolution
    }
}

struct VideoResolution: Codable, Hashable {
    let width: Int
    let height: Int
    
    var displayString: String {
        "\(width)×\(height)"
    }
}
