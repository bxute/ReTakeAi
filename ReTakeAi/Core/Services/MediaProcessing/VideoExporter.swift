//
//  VideoExporter.swift
//  SceneFlow
//

import AVFoundation
import Photos

actor VideoExporter {
    static let shared = VideoExporter()
    
    private init() {}
    
    func exportVideo(
        from sourceURL: URL,
        to destinationURL: URL,
        preset: ExportPreset = .high
    ) async throws -> URL {
        let asset = AVAsset(url: sourceURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: preset.avPreset
        ) else {
            throw ExportError.cannotCreateSession
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw ExportError.exportFailed(error)
        }
        
        AppLogger.processing.info("Video exported successfully to: \(destinationURL.lastPathComponent)")
        return destinationURL
    }
    
    func exportToPhotoLibrary(videoURL: URL) async throws {
        let status = await PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let isAuthorized = if status == .authorized {
            true
        } else {
            await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
        }
        
        guard isAuthorized else {
            throw ExportError.photoLibraryAccessDenied
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
        
        AppLogger.processing.info("Video saved to photo library")
    }
    
    func exportWithProgress(
        from sourceURL: URL,
        to destinationURL: URL,
        preset: ExportPreset = .high
    ) -> AsyncThrowingStream<ExportProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let asset = AVAsset(url: sourceURL)
                
                guard let exportSession = AVAssetExportSession(
                    asset: asset,
                    presetName: preset.avPreset
                ) else {
                    continuation.finish(throwing: ExportError.cannotCreateSession)
                    return
                }
                
                exportSession.outputURL = destinationURL
                exportSession.outputFileType = .mov
                exportSession.shouldOptimizeForNetworkUse = true
                
                let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    let progress = Double(exportSession.progress)
                    continuation.yield(ExportProgress(progress: progress, status: .exporting))
                }
                
                await exportSession.export()
                
                timer.invalidate()
                
                if let error = exportSession.error {
                    continuation.finish(throwing: ExportError.exportFailed(error))
                } else {
                    continuation.yield(ExportProgress(progress: 1.0, status: .completed, outputURL: destinationURL))
                    continuation.finish()
                }
            }
        }
    }
}

enum ExportPreset {
    case low
    case medium
    case high
    case highest
    
    var avPreset: String {
        switch self {
        case .low: return AVAssetExportPreset640x480
        case .medium: return AVAssetExportPreset1280x720
        case .high: return AVAssetExportPreset1920x1080
        case .highest: return AVAssetExportPresetHighestQuality
        }
    }
}

struct ExportProgress {
    let progress: Double
    let status: ExportStatus
    var outputURL: URL?
    
    enum ExportStatus {
        case preparing
        case exporting
        case completed
    }
}

enum ExportError: LocalizedError {
    case cannotCreateSession
    case exportFailed(Error)
    case photoLibraryAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .cannotCreateSession:
            return "Cannot create export session"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .photoLibraryAccessDenied:
            return "Photo library access denied"
        }
    }
}
