//
//  ExportedVideo.swift
//  ReTakeAi
//

import Foundation

struct ExportedVideo: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    let fileName: String
    let exportedAt: Date
    let aspect: VideoAspect
    let duration: TimeInterval
    let fileSize: Int64

    /// Reconstructs the full file URL using the current exports directory.
    /// This ensures the path is always valid even if iOS changes the app container.
    var fileURL: URL {
        FileStorageManager.shared.exportsDirectory(for: projectID)
            .appendingPathComponent(fileName)
    }
    
    init(
        id: UUID = UUID(),
        projectID: UUID,
        fileURL: URL,
        exportedAt: Date = Date(),
        aspect: VideoAspect,
        duration: TimeInterval,
        fileSize: Int64
    ) {
        self.id = id
        self.projectID = projectID
        self.fileName = fileURL.lastPathComponent
        self.exportedAt = exportedAt
        self.aspect = aspect
        self.duration = duration
        self.fileSize = fileSize
    }

    // Support decoding old exports that stored full fileURL
    private enum CodingKeys: String, CodingKey {
        case id, projectID, fileName, fileURL, exportedAt, aspect, duration, fileSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        aspect = try container.decode(VideoAspect.self, forKey: .aspect)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)

        // Try new format first (projectID + fileName)
        if let pid = try? container.decode(UUID.self, forKey: .projectID),
           let fn = try? container.decode(String.self, forKey: .fileName) {
            projectID = pid
            fileName = fn
        } else if let url = try? container.decode(URL.self, forKey: .fileURL) {
            // Fallback: old format stored full URL - extract fileName and guess projectID from path
            fileName = url.lastPathComponent
            // Path pattern: .../projects/<projectID>/exports/<fileName>
            let components = url.pathComponents
            if let exportsIndex = components.lastIndex(of: "exports"),
               exportsIndex > 0 {
                let projectIDString = components[exportsIndex - 1]
                projectID = UUID(uuidString: projectIDString) ?? UUID()
            } else {
                projectID = UUID()
            }
        } else {
            throw DecodingError.dataCorruptedError(forKey: .fileName, in: container, debugDescription: "Missing fileName or fileURL")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(aspect, forKey: .aspect)
        try container.encode(duration, forKey: .duration)
        try container.encode(fileSize, forKey: .fileSize)
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


