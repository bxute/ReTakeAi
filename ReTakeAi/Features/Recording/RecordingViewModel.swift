//
//  RecordingViewModel.swift
//  ReTakeAi
//

import Foundation
import AVFoundation
import UIKit
import AudioToolbox

@MainActor
@Observable
class RecordingViewModel {
    enum Phase: Equatable {
        case initializing
        case ready
        case setup
        case finalCountdown(number: Int) // 3,2,1
        case recording
        case completed
    }

    var currentScene: VideoScene?
    var currentProject: Project?
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var errorMessage: String?
    var isSetupComplete = false
    var captureSession: AVCaptureSession?
    var phase: Phase = .initializing
    var setupSecondsRemaining: Int = 0
    var remainingSeconds: Int = 0
    var expectedSeconds: Int = 0
    var preferences: TeleprompterPreferences = TeleprompterPreferencesStore.load()
    
    private var currentRecordingURL: URL?
    private var flowTask: Task<Void, Never>?
    private var skipRequested = false
    
    private let recordingController = RecordingController.shared
    private let cameraService = CameraService.shared
    private let sceneStore = SceneStore.shared
    private let takeStore = TakeStore.shared
    private let projectStore = ProjectStore.shared
    
    init() {}
    
    func setup(project: Project, scene: VideoScene) async {
        currentProject = project
        currentScene = scene
        errorMessage = nil
        preferences = TeleprompterPreferencesStore.load()
        
        do {
            try await recordingController.setup()
            captureSession = cameraService.captureSession
            isSetupComplete = true
            AppLogger.ui.info("Recording setup complete")
            phase = .ready
        } catch {
            errorMessage = "Failed to setup recording: \(error.localizedDescription)"
            AppLogger.ui.error("Recording setup failed: \(error.localizedDescription)")
            isSetupComplete = false
            captureSession = nil
        }
    }

    func retrySetup() async {
        guard let project = currentProject, let scene = currentScene else { return }
        await setup(project: project, scene: scene)
    }

    func beginRecordingTimer() {
        guard isSetupComplete, captureSession != nil else { return }
        startGuidedFlowIfNeeded()
    }

    func startNow() {
        skipRequested = true
    }

    private func startGuidedFlowIfNeeded() {
        guard flowTask == nil else { return }
        guard let project = currentProject, let scene = currentScene else { return }

        expectedSeconds = Int(scene.duration ?? TimeInterval(project.expectedDurationSeconds ?? 30))
        expectedSeconds = max(1, expectedSeconds)

        skipRequested = false
        phase = .setup
        setupSecondsRemaining = preferences.setupCountdown.rawValue
        remainingSeconds = expectedSeconds

        flowTask = Task { [weak self] in
            guard let self else { return }
            await self.runGuidedFlow()
        }
    }

    private func runGuidedFlow() async {
        // Calm setup phase (shows "Recording starts in Xs" while > 3s remain)
        if setupSecondsRemaining > 0 {
            while setupSecondsRemaining > 3 && !skipRequested {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                setupSecondsRemaining = max(0, setupSecondsRemaining - 1)
            }
            if skipRequested {
                setupSecondsRemaining = 3
            }
        }

        // Final countdown 3-2-1 (or shorter if setup countdown < 3)
        if preferences.setupCountdown.rawValue > 0 {
            let startNumber = max(1, min(3, setupSecondsRemaining))
            for n in stride(from: startNumber, through: 1, by: -1) {
                phase = .finalCountdown(number: n)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        // Start recording automatically
        phase = .recording
        if preferences.startBeepEnabled {
            playBeep()
        }
        await startRecording()

        // Auto-stop when expected duration finishes (if enabled)
        if preferences.autoStopEnabled {
            remainingSeconds = expectedSeconds
            // Teleprompter ends at expected duration
            while remainingSeconds > 0 && isRecording {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remainingSeconds = max(0, remainingSeconds - 1)
            }
            // Silent buffer of +1s (no UI indicators)
            if isRecording {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if isRecording {
                await stopRecording()
            }
        }

        // Completed UI phase
        phase = .completed
    }

    private func playBeep() {
        // System "Tock" sound.
        AudioServicesPlaySystemSound(1104)
    }
    
    func startRecording() async {
        guard isSetupComplete, captureSession != nil else {
            errorMessage = "Camera is not ready yet. Please wait for setup to complete."
            return
        }
        guard let scene = currentScene else { return }
        await updateProjectAspectFromCurrentOrientationIfNeeded()
        
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

    private func updateProjectAspectFromCurrentOrientationIfNeeded() async {
        guard let project = currentProject else { return }
        guard var latest = projectStore.getProject(by: project.id) else { return }

        let io = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
        let desired: VideoAspect = io.isLandscape ? .landscape16x9 : .portrait9x16

        if latest.videoAspect != desired {
            latest.videoAspect = desired
            do {
                try projectStore.updateProject(latest)
                currentProject = latest
            } catch {
                AppLogger.ui.error("Failed to update project video aspect: \(error.localizedDescription)")
            }
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

            // Auto-select the first take as "best" so the scene is considered complete.
            if scene.selectedTakeID == nil {
                try sceneStore.selectTake(take, for: scene)
            }

            // Ensure the project is no longer shown as draft once any recording happens.
            if project.status == .draft {
                if var latest = projectStore.getProject(by: project.id) {
                    latest.status = .recording
                    try projectStore.updateProject(latest)
                }
            }
            
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
        flowTask?.cancel()
        flowTask = nil
        recordingController.cleanup()
        isSetupComplete = false
        // Keep captureSession reference; controller retains a reusable session configuration.
    }
}
