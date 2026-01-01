//
//  FileStorageManager.swift
//  SceneFlow
//

import Foundation

class FileStorageManager {
    static let shared = FileStorageManager()
    
    private let fileManager = FileManager.default
    
    private init() {
        createDirectoryStructure()
    }
    
    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var appDirectory: URL {
        documentsDirectory.appendingPathComponent(Constants.Storage.appDirectoryName)
    }
    
    var projectsDirectory: URL {
        appDirectory.appendingPathComponent(Constants.Storage.projectsDirectoryName)
    }
    
    var cacheDirectory: URL {
        appDirectory.appendingPathComponent(Constants.Storage.cacheDirectoryName)
    }
    
    func projectDirectory(for projectID: UUID) -> URL {
        projectsDirectory.appendingPathComponent(projectID.uuidString)
    }
    
    func scenesDirectory(for projectID: UUID) -> URL {
        projectDirectory(for: projectID).appendingPathComponent(Constants.Storage.scenesDirectoryName)
    }
    
    func sceneDirectory(for sceneID: UUID, projectID: UUID) -> URL {
        scenesDirectory(for: projectID).appendingPathComponent(sceneID.uuidString)
    }
    
    func takesDirectory(for sceneID: UUID, projectID: UUID) -> URL {
        sceneDirectory(for: sceneID, projectID: projectID)
            .appendingPathComponent(Constants.Storage.takesDirectoryName)
    }
    
    func exportsDirectory(for projectID: UUID) -> URL {
        projectDirectory(for: projectID).appendingPathComponent(Constants.Storage.exportsDirectoryName)
    }
    
    private func createDirectoryStructure() {
        let directories = [appDirectory, projectsDirectory, cacheDirectory]
        
        for directory in directories {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                AppLogger.storage.error("Failed to create directory: \(directory.path) - \(error.localizedDescription)")
            }
        }
    }
    
    func createProjectDirectory(for projectID: UUID) throws {
        let projectDir = projectDirectory(for: projectID)
        let scenesDir = scenesDirectory(for: projectID)
        let exportsDir = exportsDirectory(for: projectID)
        
        try fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: scenesDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportsDir, withIntermediateDirectories: true)
    }
    
    func createSceneDirectory(for sceneID: UUID, projectID: UUID) throws {
        let sceneDir = sceneDirectory(for: sceneID, projectID: projectID)
        let takesDir = takesDirectory(for: sceneID, projectID: projectID)
        
        try fileManager.createDirectory(at: sceneDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: takesDir, withIntermediateDirectories: true)
    }
    
    func deleteProject(projectID: UUID) throws {
        let projectDir = projectDirectory(for: projectID)
        try fileManager.removeItem(at: projectDir)
        AppLogger.storage.info("Deleted project directory: \(projectID.uuidString)")
    }
    
    func deleteScene(sceneID: UUID, projectID: UUID) throws {
        let sceneDir = sceneDirectory(for: sceneID, projectID: projectID)
        try fileManager.removeItem(at: sceneDir)
        AppLogger.storage.info("Deleted scene directory: \(sceneID.uuidString)")
    }
    
    func saveTakeVideo(from tempURL: URL, sceneID: UUID, projectID: UUID, takeNumber: Int) throws -> URL {
        let takesDir = takesDirectory(for: sceneID, projectID: projectID)
        let fileName = "\(Constants.Storage.takeFilePrefix)\(String(format: "%03d", takeNumber)).\(Constants.Recording.videoExtension)"
        let destinationURL = takesDir.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.moveItem(at: tempURL, to: destinationURL)
        AppLogger.storage.info("Saved take video: \(fileName)")
        
        return destinationURL
    }
    
    func deleteTakeVideo(at url: URL) throws {
        try fileManager.removeItem(at: url)
        AppLogger.storage.info("Deleted take video: \(url.lastPathComponent)")
    }
    
    func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }
    
    func listProjects() -> [UUID] {
        guard let contents = try? fileManager.contentsOfDirectory(at: projectsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return contents.compactMap { url -> UUID? in
            UUID(uuidString: url.lastPathComponent)
        }
    }

    func listSceneIDs(projectID: UUID) -> [UUID] {
        let dir = scenesDirectory(for: projectID)
        guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return contents.compactMap { url in
            UUID(uuidString: url.lastPathComponent)
        }
    }
    
    func totalStorageUsed() -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: appDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
}
