//
//  ExportedVideo.swift
//  ReTakeAi
//

import Foundation

struct ExportedVideo: Identifiable, Codable, Hashable {
    let id: UUID
    let fileURL: URL
    let exportedAt: Date
    let aspect: VideoAspect
    let duration: TimeInterval
    let fileSize: Int64
    
    init(
        id: UUID = UUID(),
        fileURL: URL,
        exportedAt: Date = Date(),
        aspect: VideoAspect,
        duration: TimeInterval,
        fileSize: Int64
    ) {
        self.id = id
        self.fileURL = fileURL
        self.exportedAt = exportedAt
        self.aspect = aspect
        self.duration = duration
        self.fileSize = fileSize
    }
    
    var formattedDate: String {
        exportedAt.formatted(date: .abbreviated, time: .shortened)
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var formattedDuration: String {
        duration.formattedDuration
    }
}

