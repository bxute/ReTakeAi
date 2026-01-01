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
    var exportedURL: URL?
    var errorMessage: String?
    var showingShareSheet = false
    
    let project: Project
    
    private let sceneStore = SceneStore.shared
    private let takeStore = TakeStore.shared
    private let videoMerger = VideoMerger.shared
    private let videoExporter = VideoExporter.shared
    private let fileManager = FileStorageManager.shared
    
    init(project: Project) {
        self.project = project
    }
    
    func exportVideo(preset: ExportPreset = .high) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil
        
        do {
            let scenes = sceneStore.getScenes(for: project)
            
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
            
            let exportDir = fileManager.exportsDirectory(for: project.id)
            let fileName = "export_\(Date().timeIntervalSince1970).mov"
            let outputURL = exportDir.appendingPathComponent(fileName)
            
            let mergedURL = try await videoMerger.mergeScenes(
                selectedTakes,
                outputURL: outputURL
            ) { progress in
                Task { @MainActor in
                    self.exportProgress = progress
                }
            }
            
            exportedURL = mergedURL
            exportProgress = 1.0
            
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
