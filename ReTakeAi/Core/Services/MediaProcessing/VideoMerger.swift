//
//  VideoMerger.swift
//  SceneFlow
//

import AVFoundation
import UIKit

actor VideoMerger {
    static let shared = VideoMerger()
    
    private init() {}
    
    func mergeScenes(
        _ takes: [Take],
        outputURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard !takes.isEmpty else {
            throw VideoMergerError.noTakes
        }
        
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        // Build a videoComposition so orientation (preferredTransform) is preserved per clip.
        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var renderSize = CGSize(width: 1920, height: 1080)
        
        var currentTime = CMTime.zero
        let totalTakes = takes.count
        
        for (index, take) in takes.enumerated() {
            let asset = AVAsset(url: take.fileURL)
            let duration = try await asset.load(.duration)
            
            if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                try compositionVideoTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetVideoTrack,
                    at: currentTime
                )

                let preferredTransform = try await assetVideoTrack.load(.preferredTransform)
                let naturalSize = try await assetVideoTrack.load(.naturalSize)
                let transformedSize = naturalSize.applying(preferredTransform)
                let absSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

                // Pick a renderSize that can contain all clips; keep max dimensions.
                renderSize = CGSize(width: max(renderSize.width, absSize.width), height: max(renderSize.height, absSize.height))

                if let compositionVideoTrack {
                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)

                    // Fix translation so the transformed frame is in positive coordinate space.
                    var transform = preferredTransform
                    if transformedSize.width < 0 { transform = transform.translatedBy(x: -transformedSize.width, y: 0) }
                    if transformedSize.height < 0 { transform = transform.translatedBy(x: 0, y: -transformedSize.height) }

                    layerInstruction.setTransform(transform, at: currentTime)

                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRange(start: currentTime, duration: duration)
                    instruction.layerInstructions = [layerInstruction]

                    instructions.append(instruction)
                    layerInstructions.append(layerInstruction)
                }
            }
            
            if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try compositionAudioTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetAudioTrack,
                    at: currentTime
                )
            }
            
            currentTime = CMTimeAdd(currentTime, duration)
            
            let progressValue = Double(index + 1) / Double(totalTakes)
            progress?(progressValue)
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoMergerError.cannotCreateExportSession
        }

        if !instructions.isEmpty {
            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = instructions
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            videoComposition.renderSize = renderSize
            exportSession.videoComposition = videoComposition
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw VideoMergerError.exportFailed(error)
        }
        
        AppLogger.processing.info("Successfully merged \(totalTakes) takes")
        return outputURL
    }
    
    func mergeWithProgress(
        _ takes: [Take],
        outputURL: URL
    ) -> AsyncThrowingStream<MergeProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await mergeScenes(takes, outputURL: outputURL) { progress in
                        continuation.yield(MergeProgress(progress: progress, status: .merging))
                    }
                    
                    continuation.yield(MergeProgress(progress: 1.0, status: .completed, outputURL: result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

struct MergeProgress {
    let progress: Double
    let status: MergeStatus
    var outputURL: URL?
    
    enum MergeStatus {
        case preparing
        case merging
        case exporting
        case completed
    }
}

enum VideoMergerError: LocalizedError {
    case noTakes
    case cannotCreateExportSession
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noTakes:
            return "No takes to merge"
        case .cannotCreateExportSession:
            return "Cannot create export session"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        }
    }
}
