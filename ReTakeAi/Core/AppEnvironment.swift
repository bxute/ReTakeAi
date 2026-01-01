//
//  AppEnvironment.swift
//  SceneFlow
//

import Foundation

@MainActor
class AppEnvironment {
    static let shared = AppEnvironment()
    
    let projectStore = ProjectStore.shared
    let sceneStore = SceneStore.shared
    let takeStore = TakeStore.shared
    let fileStorageManager = FileStorageManager.shared
    
    let cameraService = CameraService.shared
    let audioService = AudioService.shared
    let recordingController = RecordingController.shared
    
    var aiService: AIServiceProtocol = MockAIService()
    
    let recordingSession = RecordingSession()
    
    private init() {}
    
    func cleanup() {
        recordingController.cleanup()
        cameraService.cleanup()
        audioService.deactivateAudioSession()
    }
}
