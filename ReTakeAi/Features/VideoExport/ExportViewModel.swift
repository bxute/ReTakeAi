//
//  ExportViewModel.swift
//  SceneFlow
//

import Foundation

@MainActor
@Observable
class ExportViewModel {
    var isExporting = false
    var exportProgress: Double = 0
    var exportingStage: String = ""
    var exportedURL: URL?
    var errorMessage: String?
    var showingShareSheet = false

    // Audio processing
    var selectedAudioPreset: String = "Podcast Pro" // Default preset
    var audioProcessingEnabled: Bool = true

    // Video settings
    var selectedTransitionStyle: TransitionStyle = .hardCut

    let project: Project

    private let sceneStore = SceneStore.shared
    private let takeStore = TakeStore.shared
    private let videoMerger = VideoMerger.shared
    private let videoExporter = VideoExporter.shared
    private let fileManager = FileStorageManager.shared
    private let projectStore = ProjectStore.shared

    init(project: Project) {
        self.project = project
    }

    // Get all available audio presets
    var availablePresets: [String] {
        AudioPresets.allPresets.map { $0.name }
    }

    // Get selected preset configuration
    private func getAudioPresetConfig() -> [String: (enabled: Bool, config: ProcessorConfig)] {
        guard let preset = AudioPresets.allPresets.first(where: { $0.name == selectedAudioPreset }) else {
            return AudioPresets.podcastPro // Default fallback
        }
        return preset.preset
    }
    
    func exportVideo(preset: ExportPreset = .high) async {
        isExporting = true
        exportProgress = 0
        exportingStage = "Preparing..."
        errorMessage = nil

        do {
            let latestProject = projectStore.getProject(by: project.id) ?? project
            let scenes = sceneStore.getScenes(for: latestProject)

            guard !scenes.isEmpty else {
                throw ExportError.cannotCreateSession
            }

            let selectedTakes = scenes.compactMap { scene -> Take? in
                guard let selectedTakeID = scene.selectedTakeID else { return nil }
                let takes = takeStore.getTakes(for: scene)
                return takes.first { $0.id == selectedTakeID }
            }

            guard !selectedTakes.isEmpty else {
                errorMessage = "No takes selected. Please select takes for each scene."
                isExporting = false
                return
            }

            // Step 1: Process each scene with audio pipeline (if enabled)
            var processedTakes: [Take] = []
            var processedTakeURLs: [URL] = [] // For cleanup

            if audioProcessingEnabled {
                exportingStage = "Processing audio..."
                let audioPreset = getAudioPresetConfig()
                let sceneAudioProcessor = SceneAudioProcessor.shared

                for (index, take) in selectedTakes.enumerated() {
                    exportingStage = "Processing scene \(index + 1)/\(selectedTakes.count)..."
                    exportProgress = Double(index) / Double(selectedTakes.count) * 0.7 // 70% for audio processing

                    // Process this scene's audio
                    let processedVideoURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("processed_scene_\(index)_\(UUID().uuidString).mov")

                    do {
                        let processedURL = try await sceneAudioProcessor.processScene(
                            inputVideoURL: take.fileURL,
                            outputVideoURL: processedVideoURL,
                            audioPreset: audioPreset
                        )

                        // Create new take with processed video URL
                        var processedTake = take
                        processedTake.fileURL = processedURL
                        processedTakes.append(processedTake)
                        processedTakeURLs.append(processedURL)

                    } catch {
                        AppLogger.processing.warning("Failed to process scene \(index + 1): \(error). Using original.")
                        processedTakes.append(take) // Fallback to original
                    }
                }

                AppLogger.processing.info("✓ Processed \(processedTakes.count) scenes with audio pipeline")
            } else {
                // No audio processing - use original takes
                processedTakes = selectedTakes
            }

            // Step 2: Merge all processed scenes with transitions
            exportingStage = "Merging scenes..."
            exportProgress = 0.7

            let exportDir = fileManager.exportsDirectory(for: project.id)
            let fileName = "export_\(Date().timeIntervalSince1970).mov"
            let outputURL = exportDir.appendingPathComponent(fileName)

            let mergedURL: URL
            switch selectedTransitionStyle {
            case .hardCut:
                // No transitions - direct cuts
                mergedURL = try await videoMerger.mergeScenes(
                    processedTakes,
                    outputURL: outputURL,
                    targetAspect: latestProject.videoAspect
                ) { progress in
                    Task { @MainActor in
                        self.exportProgress = 0.7 + (progress * 0.3)
                        self.exportingStage = "Merging scenes... \(Int(progress * 100))%"
                    }
                }

            case .crossFade:
                // Cross fade transition
                mergedURL = try await videoMerger.mergeScenesWithCrossfade(
                    processedTakes,
                    outputURL: outputURL,
                    targetAspect: latestProject.videoAspect,
                    crossfadeDuration: 0.5
                ) { progress in
                    Task { @MainActor in
                        self.exportProgress = 0.7 + (progress * 0.3)
                        self.exportingStage = "Merging scenes... \(Int(progress * 100))%"
                    }
                }

            case .fadeInOut:
                // Fade to black transition
                mergedURL = try await videoMerger.mergeScenesWithFadeToBlack(
                    processedTakes,
                    outputURL: outputURL,
                    targetAspect: latestProject.videoAspect,
                    fadeDuration: 0.3
                ) { progress in
                    Task { @MainActor in
                        self.exportProgress = 0.7 + (progress * 0.3)
                        self.exportingStage = "Merging scenes... \(Int(progress * 100))%"
                    }
                }
            }

            // Clean up processed temp files
            for url in processedTakeURLs {
                try? FileManager.default.removeItem(at: url)
            }

            exportedURL = mergedURL
            exportProgress = 1.0
            exportingStage = "Complete!"

            // Save export metadata to project
            let totalDuration = processedTakes.reduce(0) { $0 + $1.duration }
            let fileSize = fileManager.fileSize(at: mergedURL)

            let exportedVideo = ExportedVideo(
                projectID: project.id,
                fileURL: mergedURL,
                aspect: latestProject.videoAspect,
                duration: totalDuration,
                fileSize: fileSize
            )

            var updatedProject = latestProject
            updatedProject.exports.append(exportedVideo)
            updatedProject.status = .exported
            try projectStore.updateProject(updatedProject)

            AppLogger.processing.info("Video exported successfully: \(fileName)")
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            AppLogger.processing.error("Export failed: \(error.localizedDescription)")
        }

        isExporting = false
    }
    
    func saveToPhotoLibrary() async {
        guard let url = exportedURL else { return }
        
        do {
            try await videoExporter.exportToPhotoLibrary(videoURL: url)
            AppLogger.processing.info("Video saved to photo library")
        } catch {
            errorMessage = "Failed to save to photo library: \(error.localizedDescription)"
        }
    }
    
    func shareVideo() {
        guard exportedURL != nil else { return }
        showingShareSheet = true
    }
    
    func canExport() -> Bool {
        let scenes = sceneStore.getScenes(for: project)
        return scenes.allSatisfy { $0.isComplete }
    }
    
    func getExportInfo() -> ExportInfo {
        let scenes = sceneStore.getScenes(for: project)
        let selectedTakes = scenes.compactMap { scene -> Take? in
            guard let selectedTakeID = scene.selectedTakeID else { return nil }
            let takes = takeStore.getTakes(for: scene)
            return takes.first { $0.id == selectedTakeID }
        }
        
        let totalDuration = selectedTakes.reduce(0) { $0 + $1.duration }
        let totalSize = selectedTakes.reduce(0) { $0 + $1.fileSize }
        
        return ExportInfo(
            sceneCount: scenes.count,
            totalDuration: totalDuration,
            estimatedSize: totalSize
        )
    }
}

struct ExportInfo {
    let sceneCount: Int
    let totalDuration: TimeInterval
    let estimatedSize: Int64

    var formattedDuration: String {
        totalDuration.formattedDuration
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file)
    }
}

// MARK: - Transition Style

enum TransitionStyle: String, CaseIterable, Identifiable {
    case hardCut = "Hard Cut"
    case crossFade = "Cross Fade"
    case fadeInOut = "Fade In/Out"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .hardCut:
            return "Direct cuts between scenes with no transition effect"
        case .crossFade:
            return "Smooth blend between scenes (audio and video fade simultaneously)"
        case .fadeInOut:
            return "Fade to black between scenes (fade out → black → fade in)"
        }
    }

    var icon: String {
        switch self {
        case .hardCut:
            return "scissors"
        case .crossFade:
            return "waveform.path"
        case .fadeInOut:
            return "circle.lefthalf.filled"
        }
    }
}
