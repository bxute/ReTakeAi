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

    /// Merge takes into a single video targeting a specific output aspect.
    /// - Important: Uses per-clip transforms:
    ///   - Wider-than-target clips -> **Zoom/Fill** (center crop)
    ///   - Narrower-than-target clips -> **Fit** (pillarbox/letterbox)
    func mergeScenes(
        _ takes: [Take],
        outputURL: URL,
        targetAspect: VideoAspect,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        try await mergeScenes(
            takes,
            outputURL: outputURL,
            targetRenderSize: targetAspect.exportRenderSize,
            progress: progress
        )
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
        let renderSize: CGSize = {
            if let targetRenderSize {
                return VideoMerger.roundRenderSize(targetRenderSize)
            }
            let first = takes[0]
            let defaultAspect: VideoAspect = (first.resolution.height >= first.resolution.width) ? .portrait9x16 : .landscape16x9
            return defaultAspect.exportRenderSize
        }()
        let targetAspectRatio = renderSize.width / max(renderSize.height, 1)
        
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
                    let oriented = VideoMerger.orientedSize(naturalSize: naturalSize, preferredTransform: preferredTransform)
                    let sourceAspectRatio = oriented.width / max(oriented.height, 1)
                    let mode = VideoMerger.layoutMode(sourceAspectRatio: sourceAspectRatio, targetAspectRatio: targetAspectRatio)
                    let transform = VideoMerger.buildTransform(
                        naturalSize: naturalSize,
                        preferredTransform: preferredTransform,
                        renderSize: renderSize,
                        mode: mode
                    )

                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
                    layerInstruction.setTransform(transform, at: currentTime)

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

    private static func roundRenderSize(_ size: CGSize) -> CGSize {
        // AVFoundation prefers even dimensions.
        let w = max(2, Int(size.width.rounded()))
        let h = max(2, Int(size.height.rounded()))
        return CGSize(width: w % 2 == 0 ? w : w + 1, height: h % 2 == 0 ? h : h + 1)
    }

    private static func orientedSize(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    private static func layoutMode(sourceAspectRatio: CGFloat, targetAspectRatio: CGFloat) -> VideoLayoutMode {
        // Wider-than-target => Zoom/Fill (center crop). Narrower-than-target => Fit (pillarbox/letterbox).
        if sourceAspectRatio > targetAspectRatio {
            return .aspectFill
        } else if sourceAspectRatio < targetAspectRatio {
            return .aspectFit
        } else {
            return .aspectFill
        }
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
    
    /// Merge takes with soft audio and video crossfades at scene boundaries
    func mergeScenesWithCrossfade(
        _ takes: [Take],
        outputURL: URL,
        targetAspect: VideoAspect,
        crossfadeDuration: Double = 0.5,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard !takes.isEmpty else {
            throw VideoMergerError.noTakes
        }

        // For single take, no crossfade needed
        if takes.count == 1 {
            return try await mergeScenes(takes, outputURL: outputURL, targetAspect: targetAspect, progress: progress)
        }

        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        let renderSize = targetAspect.exportRenderSize
        let targetAspectRatio = renderSize.width / max(renderSize.height, 1)

        var instructions: [AVMutableVideoCompositionInstruction] = []
        var audioMixParameters: [AVMutableAudioMixInputParameters] = []

        var currentTime = CMTime.zero
        let crossfadeTime = CMTime(seconds: crossfadeDuration, preferredTimescale: 600)

        for (index, take) in takes.enumerated() {
            let asset = AVAsset(url: take.fileURL)
            let duration = try await asset.load(.duration)

            // Video track
            if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                try compositionVideoTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetVideoTrack,
                    at: currentTime
                )

                if let compositionVideoTrack {
                    let preferredTransform = try await assetVideoTrack.load(.preferredTransform)
                    let naturalSize = try await assetVideoTrack.load(.naturalSize)
                    let oriented = VideoMerger.orientedSize(naturalSize: naturalSize, preferredTransform: preferredTransform)
                    let sourceAspectRatio = oriented.width / max(oriented.height, 1)
                    let mode = VideoMerger.layoutMode(sourceAspectRatio: sourceAspectRatio, targetAspectRatio: targetAspectRatio)
                    let transform = VideoMerger.buildTransform(
                        naturalSize: naturalSize,
                        preferredTransform: preferredTransform,
                        renderSize: renderSize,
                        mode: mode
                    )

                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
                    layerInstruction.setTransform(transform, at: currentTime)

                    // Video crossfade: fade out at end (except last scene)
                    if index < takes.count - 1 {
                        let fadeOutStart = CMTimeAdd(currentTime, CMTimeSubtract(duration, crossfadeTime))
                        layerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange(start: fadeOutStart, duration: crossfadeTime))
                    }

                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRange(start: currentTime, duration: duration)
                    instruction.layerInstructions = [layerInstruction]

                    instructions.append(instruction)
                }
            }

            // Audio track with crossfade
            if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try compositionAudioTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetAudioTrack,
                    at: currentTime
                )

                if let compositionAudioTrack {
                    let audioMixParams = AVMutableAudioMixInputParameters(track: compositionAudioTrack)

                    // Audio crossfade: fade out at end (except last scene)
                    if index < takes.count - 1 {
                        let fadeOutStart = CMTimeAdd(currentTime, CMTimeSubtract(duration, crossfadeTime))
                        audioMixParams.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: 0.0, timeRange: CMTimeRange(start: fadeOutStart, duration: crossfadeTime))
                    }

                    // Audio crossfade: fade in at start (except first scene)
                    if index > 0 {
                        audioMixParams.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 1.0, timeRange: CMTimeRange(start: currentTime, duration: crossfadeTime))
                    }

                    audioMixParameters.append(audioMixParams)
                }
            }

            currentTime = CMTimeAdd(currentTime, duration)

            let progressValue = Double(index + 1) / Double(takes.count)
            progress?(progressValue)
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoMergerError.cannotCreateExportSession
        }

        // Video composition
        if !instructions.isEmpty {
            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = instructions
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            videoComposition.renderSize = renderSize
            exportSession.videoComposition = videoComposition
        }

        // Audio mix
        if !audioMixParameters.isEmpty {
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = audioMixParameters
            exportSession.audioMix = audioMix
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        if let error = exportSession.error {
            throw VideoMergerError.exportFailed(error)
        }

        AppLogger.processing.info("Successfully merged \(takes.count) takes with crossfades")
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
