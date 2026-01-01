//
//  RecordingSession.swift
//  ReTakeAi
//

import Foundation
import AVFoundation

@MainActor
@Observable
class RecordingSession {
    var currentProject: Project?
    var currentScene: VideoScene?
    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0
    var captureSession: AVCaptureSession?
    var isSessionConfigured: Bool = false
    var errorMessage: String?
    
    func reset() {
        currentProject = nil
        currentScene = nil
        isRecording = false
        recordingDuration = 0
        errorMessage = nil
    }
}
