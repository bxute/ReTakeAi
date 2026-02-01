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

        AppLogger.processing.info("🎬 Processing scene audio: \(inputVideoURL.lastPathComponent)")

        // Step 1: Extract audio from video
        let extractedAudioURL = try await extractAudio(from: inputVideoURL)
        defer { try? FileManager.default.removeItem(at: extractedAudioURL) }

        AppLogger.processing.info("  ✓ Extracted audio")

        // Step 2: Apply Dead Air Trimmer (if enabled)
        var currentAudioURL = extractedAudioURL
        var trimmedTimeRanges: [CMTimeRange] = []

        if let trimmerConfig = audioPreset["deadAirTrimmer"],
           trimmerConfig.enabled {
            let trimmedAudioURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("trimmed_\(UUID().uuidString).m4a")

            let processor = DeadAirTrimmerProcessor()
            let keptRanges = try await processor.processWithRanges(
                inputURL: currentAudioURL,
                outputURL: trimmedAudioURL,
                config: trimmerConfig.config
            )

            currentAudioURL = trimmedAudioURL
            trimmedTimeRanges = keptRanges

            let trimmedDuration = keptRanges.reduce(0.0) { $0 + CMTimeGetSeconds($1.duration) }
            AppLogger.processing.info("  ✓ Dead air trimmed → \(String(format: "%.2f", trimmedDuration))s")
        }

        // Step 3: Apply Silence Attenuator (if enabled)
        if let attenuatorConfig = audioPreset["silenceAttenuator"],
           attenuatorConfig.enabled {
            let attenuatedAudioURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("attenuated_\(UUID().uuidString).m4a")

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

            AppLogger.processing.info("  ✓ Silence attenuated")
        }

        // Step 4: Trim video to match audio (if dead air was trimmed)
        var finalVideoURL = inputVideoURL
        if !trimmedTimeRanges.isEmpty {
            let trimmedVideoURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("trimmed_video_\(UUID().uuidString).mov")

            try await trimVideo(
                inputVideoURL: inputVideoURL,
                outputVideoURL: trimmedVideoURL,
                keptRanges: trimmedTimeRanges
            )

            finalVideoURL = trimmedVideoURL

            AppLogger.processing.info("  ✓ Video trimmed to match audio")
        }

        // Step 5: Mux processed audio with video
        try await muxAudioWithVideo(
            videoURL: finalVideoURL,
            audioURL: currentAudioURL,
            outputURL: outputVideoURL
        )

        // Clean up temp files
        if currentAudioURL != extractedAudioURL {
            try? FileManager.default.removeItem(at: currentAudioURL)
        }
        if finalVideoURL != inputVideoURL {
            try? FileManager.default.removeItem(at: finalVideoURL)
        }

        AppLogger.processing.info("  ✓ Muxed audio + video → \(outputVideoURL.lastPathComponent)")

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

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: currentTime)
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = naturalSize

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

        // Create video composition to preserve transforms
        let videoComposition = AVMutableVideoComposition()
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let naturalSize = try await videoTrack.load(.naturalSize)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: finalDuration)
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = naturalSize

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw SceneAudioProcessorError.cannotCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        await exportSession.export()

        if let error = exportSession.error {
            throw SceneAudioProcessorError.exportFailed(error)
        }
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
