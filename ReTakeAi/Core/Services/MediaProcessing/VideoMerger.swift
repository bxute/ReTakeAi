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
                    layerInstruction.setTransform(transform, at: .zero)

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
        // Calculate the oriented bounds after applying preferredTransform
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let orientedWidth = abs(transformedRect.width)
        let orientedHeight = abs(transformedRect.height)

        guard orientedWidth > 0, orientedHeight > 0 else {
            return preferredTransform
        }

        // Calculate scale to fit/fill the render size
        let scaleX = renderSize.width / orientedWidth
        let scaleY = renderSize.height / orientedHeight
        let scale: CGFloat
        switch mode {
        case .aspectFill:
            scale = max(scaleX, scaleY)
        case .aspectFit:
            scale = min(scaleX, scaleY)
        }

        // Build transform using explicit concatenation in output coordinate space:
        // 1. Apply preferredTransform (rotation/orientation)
        // 2. Translate to move content to origin (0,0)
        // 3. Scale to fit render size
        // 4. Translate to center in render frame

        // Step 1: Start with preferredTransform
        var result = preferredTransform

        // Step 2: Translate to origin (in output space, so we concatenate AFTER)
        let translateToOrigin = CGAffineTransform(translationX: -transformedRect.minX, y: -transformedRect.minY)
        result = result.concatenating(translateToOrigin)

        // Step 3: Scale
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        result = result.concatenating(scaleTransform)

        // Step 4: Center in render frame
        let scaledWidth = orientedWidth * scale
        let scaledHeight = orientedHeight * scale
        let tx = (renderSize.width - scaledWidth) / 2.0
        let ty = (renderSize.height - scaledHeight) / 2.0
        let centerTransform = CGAffineTransform(translationX: tx, y: ty)
        result = result.concatenating(centerTransform)

        return result
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
