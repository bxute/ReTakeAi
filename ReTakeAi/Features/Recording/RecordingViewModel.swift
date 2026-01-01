//
//  RecordingViewModel.swift
//  ReTakeAi
//

import Foundation
import AVFoundation

@MainActor
@Observable
class RecordingViewModel {
    var currentScene: VideoScene?
    var currentProject: Project?
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var showTeleprompter = true
    var errorMessage: String?
    var isSetupComplete = false
    var captureSession: AVCaptureSession?
    
    private var currentRecordingURL: URL?
    
    private let recordingController = RecordingController.shared
    private let cameraService = CameraService.shared
    private let sceneStore = SceneStore.shared
    private let takeStore = TakeStore.shared
    private let projectStore = ProjectStore.shared
    
    init() {}
    
    func setup(project: Project, scene: VideoScene) async {
        currentProject = project
        currentScene = scene
        
        do {
            try await recordingController.setup()
            captureSession = cameraService.captureSession
            isSetupComplete = true
            AppLogger.ui.info("Recording setup complete")
        } catch {
            errorMessage = "Failed to setup recording: \(error.localizedDescription)"
            AppLogger.ui.error("Recording setup failed: \(error.localizedDescription)")
        }
    }
    
    func startRecording() async {
        guard let scene = currentScene else { return }
        
        do {
            currentRecordingURL = try await recordingController.startRecording()
            isRecording = true
            
            startMonitoringDuration()
            
            AppLogger.ui.info("Started recording for scene \(scene.orderIndex)")
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            AppLogger.ui.error("Start recording failed: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() async {
        guard let scene = currentScene,
              let project = currentProject else { return }
        
        do {
            let videoURL = try await recordingController.stopRecording()
            isRecording = false
            stopMonitoringDuration()
            
            let takes = takeStore.getTakes(for: scene)
            let takeNumber = takes.count + 1
            
            let take = try takeStore.saveTake(
                videoURL: videoURL,
                sceneID: scene.id,
                projectID: project.id,
                takeNumber: takeNumber
            )
            
            try sceneStore.addTake(take, to: scene)
            
            await generateThumbnail(for: take)
            
            AppLogger.ui.info("Saved take \(takeNumber) for scene \(scene.orderIndex)")
        } catch {
            errorMessage = "Failed to stop recording: \(error.localizedDescription)"
            AppLogger.ui.error("Stop recording failed: \(error.localizedDescription)")
        }
    }
    
    func cancelRecording() async {
        if isRecording {
            do {
                _ = try await recordingController.stopRecording()
                isRecording = false
                stopMonitoringDuration()
                
                if let url = currentRecordingURL,
                   FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                }
                
                AppLogger.ui.info("Recording cancelled")
            } catch {
                errorMessage = "Failed to cancel recording: \(error.localizedDescription)"
            }
        }
    }
    
    func switchCamera() async {
        do {
            try await cameraService.switchCamera()
            AppLogger.ui.info("Camera switched")
        } catch {
            errorMessage = "Failed to switch camera: \(error.localizedDescription)"
        }
    }
    
    func toggleTeleprompter() {
        showTeleprompter.toggle()
    }
    
    private func startMonitoringDuration() {
        Task {
            while isRecording {
                recordingDuration = recordingController.recordingDuration
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
    
    private func stopMonitoringDuration() {
        recordingDuration = 0
    }
    
    private func generateThumbnail(for take: Take) async {
        do {
            let thumbnailURL = take.fileURL
                .deletingPathExtension()
                .appendingPathExtension("jpg")
            
            _ = try await ThumbnailGenerator.shared.saveThumbnail(
                from: take.fileURL,
                to: thumbnailURL
            )
        } catch {
            AppLogger.ui.error("Failed to generate thumbnail: \(error.localizedDescription)")
        }
    }
    
    func cleanup() {
        recordingController.cleanup()
        isSetupComplete = false
    }
}
