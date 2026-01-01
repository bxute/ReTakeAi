//
//  TakeStore.swift
//  ReTakeAi
//

import Foundation
import AVFoundation

class TakeStore: ObservableObject {
    static let shared = TakeStore()
    
    private let fileManager = FileStorageManager.shared
    private var takeCache: [UUID: [Take]] = [:]
    
    private init() {}
    
    func saveTake(
        videoURL: URL,
        sceneID: UUID,
        projectID: UUID,
        takeNumber: Int
    ) throws -> Take {
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration.seconds
        
        let destinationURL = try fileManager.saveTakeVideo(
            from: videoURL,
            sceneID: sceneID,
            projectID: projectID,
            takeNumber: takeNumber
        )
        
        let fileSize = fileManager.fileSize(at: destinationURL)
        let resolution = try getVideoResolution(from: asset)
        
        let take = Take(
            sceneID: sceneID,
            takeNumber: takeNumber,
            duration: duration,
            fileURL: destinationURL,
            fileSize: fileSize,
            resolution: resolution
        )
        
        var takes = takeCache[sceneID] ?? []
        takes.append(take)
        takeCache[sceneID] = takes
        
        AppLogger.storage.info("Saved take \(takeNumber) for scene")
        return take
    }
    
    func deleteTake(_ take: Take) throws {
        try fileManager.deleteTakeVideo(at: take.fileURL)
        
        if var takes = takeCache[take.sceneID] {
            takes.removeAll { $0.id == take.id }
            takeCache[take.sceneID] = takes
        }
        
        AppLogger.storage.info("Deleted take: \(take.id.uuidString)")
    }
    
    func getTakes(for scene: VideoScene) -> [Take] {
        if let cached = takeCache[scene.id] {
            return cached.sorted { $0.takeNumber < $1.takeNumber }
        }
        
        let takes = loadTakes(for: scene)
        takeCache[scene.id] = takes
        return takes.sorted { $0.takeNumber < $1.takeNumber }
    }
    
    func updateTakeScore(take: Take, score: Double, notes: String?) throws {
        var updatedTake = take
        updatedTake.aiScore = score
        updatedTake.aiNotes = notes
        
        if var takes = takeCache[take.sceneID] {
            if let index = takes.firstIndex(where: { $0.id == take.id }) {
                takes[index] = updatedTake
                takeCache[take.sceneID] = takes
            }
        }
    }
    
    private func loadTakes(for scene: VideoScene) -> [Take] {
        let takesDir = fileManager.takesDirectory(for: scene.id, projectID: scene.projectID)
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: takesDir,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        
        return files.compactMap { url -> Take? in
            guard url.pathExtension == Constants.Recording.videoExtension else { return nil }
            
            let asset = AVAsset(url: url)
            let duration = asset.duration.seconds
            let fileSize = fileManager.fileSize(at: url)
            
            let fileName = url.deletingPathExtension().lastPathComponent
            let takeNumberString = fileName.replacingOccurrences(of: Constants.Storage.takeFilePrefix, with: "")
            let takeNumber = Int(takeNumberString) ?? 1
            
            let resolution = (try? getVideoResolution(from: asset)) ?? VideoResolution(width: 1920, height: 1080)
            
            return Take(
                sceneID: scene.id,
                takeNumber: takeNumber,
                duration: duration,
                fileURL: url,
                fileSize: fileSize,
                resolution: resolution
            )
        }
    }
    
    private func getVideoResolution(from asset: AVAsset) throws -> VideoResolution {
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw NSError(domain: "TakeStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        let size = track.naturalSize.applying(track.preferredTransform)
        return VideoResolution(
            width: Int(abs(size.width)),
            height: Int(abs(size.height))
        )
    }
}
