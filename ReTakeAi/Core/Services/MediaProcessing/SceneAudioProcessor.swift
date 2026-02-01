//
//  SceneAudioProcessor.swift
//  ReTakeAi
//
//  Processes audio for individual video scenes
//  Pipeline: Extract Audio → Dead Air Trim → Silence Attenuate → Mux back with video
//

import Foundation
import AVFoundation

actor SceneAudioProcessor {
    static let shared = SceneAudioProcessor()

    private init() {}

    /// Process a single scene video with audio pipeline
    /// - Parameters:
    ///   - inputVideoURL: Source video file
    ///   - outputVideoURL: Destination for processed video
    ///   - audioPreset: Dead Air Trimmer + Silence Attenuator configuration
    /// - Returns: URL of processed video with enhanced audio
    func processScene(
        inputVideoURL: URL,
        outputVideoURL: URL,
        audioPreset: [String: (enabled: Bool, config: ProcessorConfig)]
    ) async throws -> URL {

        AppLogger.processing.info("🎧 [SceneAudio] ========================================")
        AppLogger.processing.info("🎧 [SceneAudio] Processing: \(inputVideoURL.lastPathComponent)")
        AppLogger.processing.info("🎧 [SceneAudio] Output: \(outputVideoURL.lastPathComponent)")

        // Verify input file
        let inputExists = FileManager.default.fileExists(atPath: inputVideoURL.path)
        let inputSize = (try? FileManager.default.attributesOfItem(atPath: inputVideoURL.path)[.size] as? Int64) ?? 0
        AppLogger.processing.info("🎧 [SceneAudio] Input file: exists=\(inputExists), size=\(inputSize) bytes")
        
        // Check input tracks
        AppLogger.processing.info("🎧 [SceneAudio] Loading input asset tracks...")
        let inputAsset = AVAsset(url: inputVideoURL)
        let inputVideoTracks: [AVAssetTrack]
        let inputAudioTracks: [AVAssetTrack]
        do {
            inputVideoTracks = try await inputAsset.loadTracks(withMediaType: .video)
            inputAudioTracks = try await inputAsset.loadTracks(withMediaType: .audio)
            AppLogger.processing.info("🎧 [SceneAudio] Input tracks - video: \(inputVideoTracks.count), audio: \(inputAudioTracks.count)")
        } catch {
            AppLogger.processing.error("🎧 [SceneAudio] ✗ Failed to load input tracks: \(error)")
            throw error
        }
        
        // Step 1: Extract audio from video
        AppLogger.processing.info("🎧 [SceneAudio] Step 1: Extracting audio...")
        let extractedAudioURL: URL
        do {
            extractedAudioURL = try await extractAudio(from: inputVideoURL)
            let extractedSize = (try? FileManager.default.attributesOfItem(atPath: extractedAudioURL.path)[.size] as? Int64) ?? 0
            AppLogger.processing.info("🎧 [SceneAudio] Step 1 ✓ Extracted audio: \(extractedSize) bytes")
        } catch {
            AppLogger.processing.error("🎧 [SceneAudio] Step 1 ✗ Extract audio failed: \(error)")
            throw error
        }
        defer { try? FileManager.default.removeItem(at: extractedAudioURL) }

        // Step 2: Apply Dead Air Trimmer (if enabled)
        var currentAudioURL = extractedAudioURL
        var trimmedTimeRanges: [CMTimeRange] = []

        if let trimmerConfig = audioPreset["deadAirTrimmer"],
           trimmerConfig.enabled {
            AppLogger.processing.info("🎧 [SceneAudio] Step 2: Applying Dead Air Trimmer...")
            let trimmedAudioURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("trimmed_\(UUID().uuidString).m4a")

            do {
                let processor = DeadAirTrimmerProcessor()
                let keptRanges = try await processor.processWithRanges(
                    inputURL: currentAudioURL,
                    outputURL: trimmedAudioURL,
                    config: trimmerConfig.config
                )

                currentAudioURL = trimmedAudioURL
                trimmedTimeRanges = keptRanges

                let trimmedDuration = keptRanges.reduce(0.0) { $0 + CMTimeGetSeconds($1.duration) }
                AppLogger.processing.info("🎧 [SceneAudio] Step 2 ✓ Dead air trimmed → \(String(format: "%.2f", trimmedDuration))s, \(keptRanges.count) ranges")
                
                // Log each range for debugging
                for (i, range) in keptRanges.enumerated() {
                    let start = CMTimeGetSeconds(range.start)
                    let dur = CMTimeGetSeconds(range.duration)
                    AppLogger.processing.info("🎧 [SceneAudio]   Range \(i): start=\(String(format: "%.2f", start))s, duration=\(String(format: "%.2f", dur))s")
                }
            } catch {
                AppLogger.processing.error("🎧 [SceneAudio] Step 2 ✗ Dead Air Trimmer failed: \(error)")
                throw error
            }
        } else {
            AppLogger.processing.info("🎧 [SceneAudio] Step 2: Skipped (Dead Air Trimmer disabled)")
        }

        // Step 3: Apply Silence Attenuator (if enabled)
        if let attenuatorConfig = audioPreset["silenceAttenuator"],
           attenuatorConfig.enabled {
            AppLogger.processing.info("🎧 [SceneAudio] Step 3: Applying Silence Attenuator...")
            let attenuatedAudioURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("attenuated_\(UUID().uuidString).m4a")

            do {
                let processor = SilenceAttenuatorProcessor()
                try await processor.process(
                    inputURL: currentAudioURL,
                    outputURL: attenuatedAudioURL,
                    config: attenuatorConfig.config
                )

                // Clean up previous temp file if not original
                if currentAudioURL != extractedAudioURL {
                    try? FileManager.default.removeItem(at: currentAudioURL)
                }

                currentAudioURL = attenuatedAudioURL
                let attenuatedSize = (try? FileManager.default.attributesOfItem(atPath: attenuatedAudioURL.path)[.size] as? Int64) ?? 0
                AppLogger.processing.info("🎧 [SceneAudio] Step 3 ✓ Silence attenuated: \(attenuatedSize) bytes")
            } catch {
                AppLogger.processing.error("🎧 [SceneAudio] Step 3 ✗ Silence Attenuator failed: \(error)")
                throw error
            }
        } else {
            AppLogger.processing.info("🎧 [SceneAudio] Step 3: Skipped (Silence Attenuator disabled)")
        }

        // Step 4: Trim video to match audio (if dead air was trimmed)
        var finalVideoURL = inputVideoURL
        if !trimmedTimeRanges.isEmpty {
            AppLogger.processing.info("🎧 [SceneAudio] Step 4: Trimming video to match audio (\(trimmedTimeRanges.count) ranges)...")
            let trimmedVideoURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("trimmed_video_\(UUID().uuidString).mov")

            do {
                try await trimVideo(
                    inputVideoURL: inputVideoURL,
                    outputVideoURL: trimmedVideoURL,
                    keptRanges: trimmedTimeRanges
                )

                finalVideoURL = trimmedVideoURL
                let trimmedVideoSize = (try? FileManager.default.attributesOfItem(atPath: trimmedVideoURL.path)[.size] as? Int64) ?? 0
                AppLogger.processing.info("🎧 [SceneAudio] Step 4 ✓ Video trimmed: \(trimmedVideoSize) bytes")
            } catch {
                AppLogger.processing.error("🎧 [SceneAudio] Step 4 ✗ Video trim failed: \(error)")
                throw error
            }
        } else {
            AppLogger.processing.info("🎧 [SceneAudio] Step 4: Skipped (no trimming needed)")
        }

        // Step 5: Mux processed audio with video
        AppLogger.processing.info("🎧 [SceneAudio] Step 5: Muxing audio with video...")
        AppLogger.processing.info("🎧 [SceneAudio]   Video source: \(finalVideoURL.lastPathComponent)")
        AppLogger.processing.info("🎧 [SceneAudio]   Audio source: \(currentAudioURL.lastPathComponent)")
        
        do {
            try await muxAudioWithVideo(
                videoURL: finalVideoURL,
                audioURL: currentAudioURL,
                outputURL: outputVideoURL
            )

            // Verify output
            let outputExists = FileManager.default.fileExists(atPath: outputVideoURL.path)
            let outputSize = (try? FileManager.default.attributesOfItem(atPath: outputVideoURL.path)[.size] as? Int64) ?? 0
            AppLogger.processing.info("🎧 [SceneAudio] Step 5 ✓ Muxed: exists=\(outputExists), size=\(outputSize) bytes")
            
            // Check output tracks
            let outputAsset = AVAsset(url: outputVideoURL)
            let outputVideoTracks = try await outputAsset.loadTracks(withMediaType: .video)
            let outputAudioTracks = try await outputAsset.loadTracks(withMediaType: .audio)
            AppLogger.processing.info("🎧 [SceneAudio] Output tracks - video: \(outputVideoTracks.count), audio: \(outputAudioTracks.count)")
        } catch {
            AppLogger.processing.error("🎧 [SceneAudio] Step 5 ✗ Mux failed: \(error)")
            throw error
        }

        // Clean up temp files
        if currentAudioURL != extractedAudioURL {
            try? FileManager.default.removeItem(at: currentAudioURL)
        }
        if finalVideoURL != inputVideoURL {
            try? FileManager.default.removeItem(at: finalVideoURL)
        }

        AppLogger.processing.info("🎧 [SceneAudio] ✓ Scene processing complete!")

        return outputVideoURL
    }

    // MARK: - Private Helpers

    /// Extract audio track from video file
    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let audioTrack = audioTracks.first else {
            throw SceneAudioProcessorError.noAudioTrack
        }

        let composition = AVMutableComposition()
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw SceneAudioProcessorError.cannotCreateComposition
        }

        let duration = try await asset.load(.duration)
        try compositionAudioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: audioTrack,
            at: .zero
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("extracted_\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw SceneAudioProcessorError.cannotCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if let error = exportSession.error {
            throw SceneAudioProcessorError.exportFailed(error)
        }

        return outputURL
    }

    /// Trim video to keep only specified time ranges
    private func trimVideo(
        inputVideoURL: URL,
        outputVideoURL: URL,
        keptRanges: [CMTimeRange]
    ) async throws {
        let asset = AVAsset(url: inputVideoURL)
        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw SceneAudioProcessorError.cannotCreateComposition
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw SceneAudioProcessorError.noVideoTrack
        }

        // Build video composition with kept ranges
        var currentTime = CMTime.zero
        for range in keptRanges {
            try compositionVideoTrack.insertTimeRange(
                range,
                of: videoTrack,
                at: currentTime
            )
            currentTime = CMTimeAdd(currentTime, range.duration)
        }

        // Create video composition to preserve transforms
        let videoComposition = AVMutableVideoComposition()
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        // Calculate oriented size (accounts for rotation)
        let orientedSize = orientedVideoSize(naturalSize: naturalSize, preferredTransform: preferredTransform)
        
        // Build transform that positions content correctly in the oriented render size
        let transform = buildOrientedTransform(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            renderSize: orientedSize
        )

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(transform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: currentTime)
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = orientedSize

        // Export trimmed video
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw SceneAudioProcessorError.cannotCreateExportSession
        }

        exportSession.outputURL = outputVideoURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        await exportSession.export()

        if let error = exportSession.error {
            throw SceneAudioProcessorError.exportFailed(error)
        }
    }

    /// Mux processed audio with video (replacing original audio)
    /// Simple approach: Just combine tracks without video composition
    /// The video track already has correct orientation from trimVideo
    private func muxAudioWithVideo(
        videoURL: URL,
        audioURL: URL,
        outputURL: URL
    ) async throws {
        let videoAsset = AVAsset(url: videoURL)
        let audioAsset = AVAsset(url: audioURL)

        let composition = AVMutableComposition()

        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw SceneAudioProcessorError.cannotCreateComposition
        }

        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw SceneAudioProcessorError.noVideoTrack
        }

        let videoDuration = try await videoAsset.load(.duration)
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )
        
        // Preserve the video's preferred transform
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = preferredTransform

        // Add audio track
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw SceneAudioProcessorError.cannotCreateComposition
        }

        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw SceneAudioProcessorError.noAudioTrack
        }

        let audioDuration = try await audioAsset.load(.duration)
        let finalDuration = min(videoDuration, audioDuration)

        try compositionAudioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: finalDuration),
            of: audioTrack,
            at: .zero
        )

        // Export WITHOUT video composition - let AVFoundation handle transforms naturally
        // The composition track's preferredTransform will be respected
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw SceneAudioProcessorError.cannotCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        // NOTE: No videoComposition set - simpler and avoids double-transform issues

        await exportSession.export()

        if let error = exportSession.error {
            throw SceneAudioProcessorError.exportFailed(error)
        }
    }
    
    // MARK: - Transform Helpers
    
    /// Calculate the oriented video size after applying preferredTransform
    private func orientedVideoSize(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }
    
    /// Build a transform that correctly positions content in the oriented render size
    private func buildOrientedTransform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        renderSize: CGSize
    ) -> CGAffineTransform {
        // Calculate the transformed rect to find where content ends up
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        
        // Start with the preferred transform (handles rotation)
        var result = preferredTransform
        
        // Translate to move content to origin (0,0) - handles negative coordinates from rotation
        let translateToOrigin = CGAffineTransform(translationX: -transformedRect.minX, y: -transformedRect.minY)
        result = result.concatenating(translateToOrigin)
        
        return result
    }
}

enum SceneAudioProcessorError: LocalizedError {
    case noAudioTrack
    case noVideoTrack
    case cannotCreateComposition
    case cannotCreateExportSession
    case exportFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "Video has no audio track"
        case .noVideoTrack:
            return "No video track found"
        case .cannotCreateComposition:
            return "Cannot create composition"
        case .cannotCreateExportSession:
            return "Cannot create export session"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        }
    }
}
