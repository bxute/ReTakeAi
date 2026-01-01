//
//  VideoMerger.swift
//  SceneFlow
//

import AVFoundation
import UIKit

actor VideoMerger {
    static let shared = VideoMerger()
    
    private init() {}
    
    private enum VideoLayoutMode {
        /// Fill the output frame, cropping if needed (no black bars).
        case aspectFill
        /// Fit inside the output frame, letterboxing if needed.
        case aspectFit
    }

    func mergeScenes(
        _ takes: [Take],
        outputURL: URL,
        targetRenderSize: CGSize? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard !takes.isEmpty else {
            throw VideoMergerError.noTakes
        }
        
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        // Build a videoComposition so orientation + layout are preserved per clip.
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var renderSize: CGSize? = targetRenderSize
        let layoutMode: VideoLayoutMode = .aspectFill
        
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

                if let compositionVideoTrack {
                    let preferredTransform = try await assetVideoTrack.load(.preferredTransform)
                    let naturalSize = try await assetVideoTrack.load(.naturalSize)

                    // Establish a fixed output canvas based on the first clip's oriented dimensions (unless provided).
                    if renderSize == nil {
                        let orientedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
                        let orientedSize = CGSize(width: abs(orientedRect.width), height: abs(orientedRect.height))
                        renderSize = VideoMerger.roundRenderSize(orientedSize)
                    }

                    let targetSize = renderSize ?? CGSize(width: 1080, height: 1920)
                    let transform = VideoMerger.buildTransform(
                        naturalSize: naturalSize,
                        preferredTransform: preferredTransform,
                        renderSize: targetSize,
                        mode: layoutMode
                    )

                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
                    layerInstruction.setTransform(transform, at: currentTime)
                    // Avoid any transform leaking into later time ranges.
                    layerInstruction.setOpacity(0.0, at: CMTimeAdd(currentTime, duration))

                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRange(start: currentTime, duration: duration)
                    instruction.layerInstructions = [layerInstruction]

                    instructions.append(instruction)
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
            videoComposition.renderSize = renderSize ?? CGSize(width: 1080, height: 1920)
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

    private static func roundRenderSize(_ size: CGSize) -> CGSize {
        // AVFoundation prefers even dimensions.
        let w = max(2, Int(size.width.rounded()))
        let h = max(2, Int(size.height.rounded()))
        return CGSize(width: w % 2 == 0 ? w : w + 1, height: h % 2 == 0 ? h : h + 1)
    }

    private static func buildTransform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        renderSize: CGSize,
        mode: VideoLayoutMode
    ) -> CGAffineTransform {
        // Start with the asset's preferredTransform (handles rotation/mirroring).
        var transform = preferredTransform

        // Compute the oriented bounds of the source after applying the transform.
        let sourceRect = CGRect(origin: .zero, size: naturalSize).applying(transform)

        // Move into positive coordinate space (origin at 0,0).
        transform = transform.translatedBy(x: -sourceRect.minX, y: -sourceRect.minY)

        let orientedSize = CGSize(width: abs(sourceRect.width), height: abs(sourceRect.height))
        guard orientedSize.width > 0, orientedSize.height > 0 else { return transform }

        let scaleX = renderSize.width / orientedSize.width
        let scaleY = renderSize.height / orientedSize.height
        let scale: CGFloat
        switch mode {
        case .aspectFill:
            scale = max(scaleX, scaleY)
        case .aspectFit:
            scale = min(scaleX, scaleY)
        }

        transform = transform.scaledBy(x: scale, y: scale)

        // Center the scaled content in the output frame.
        let scaledSize = CGSize(width: orientedSize.width * scale, height: orientedSize.height * scale)
        let tx = (renderSize.width - scaledSize.width) / 2.0
        let ty = (renderSize.height - scaledSize.height) / 2.0
        transform = transform.translatedBy(x: tx, y: ty)

        return transform
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
