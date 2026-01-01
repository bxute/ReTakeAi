//
//  RecordingController.swift
//  SceneFlow
//

import AVFoundation
import UIKit

@MainActor
class RecordingController: NSObject, ObservableObject {
    static let shared = RecordingController()
    
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var currentRecordingURL: URL?
    
    private let cameraService = CameraService.shared
    private let audioService = AudioService.shared
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    private var recordingDelegate: RecordingDelegate?
    
    private override init() {
        super.init()
    }
    
    func setup() async throws {
        await cameraService.checkAuthorization()
        let audioAuthorized = await audioService.checkAuthorization()
        
        guard cameraService.isAuthorized && audioAuthorized else {
            throw RecordingError.notAuthorized
        }
        
        try audioService.configureAudioSession()
        try await cameraService.configureSession()
        
        cameraService.startSession()
        
        AppLogger.recording.info("Recording controller setup complete")
    }
    
    func startRecording() async throws -> URL {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }
        
        guard let session = cameraService.captureSession,
              let movieOutput = session.outputs.first(where: { $0 is AVCaptureMovieFileOutput }) as? AVCaptureMovieFileOutput else {
            throw RecordingError.outputNotConfigured
        }

        // Match recording orientation to current interface orientation (portrait/landscape).
        if let connection = movieOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = currentCaptureOrientation()
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(Constants.Recording.videoExtension)
        
        recordingDelegate = RecordingDelegate()
        movieOutput.startRecording(to: tempURL, recordingDelegate: recordingDelegate!)
        
        isRecording = true
        recordingStartTime = Date()
        currentRecordingURL = tempURL
        
        startTimer()
        audioService.startMonitoring()
        
        AppLogger.recording.info("Recording started: \(tempURL.lastPathComponent)")
        
        return tempURL
    }

    private func currentCaptureOrientation() -> AVCaptureVideoOrientation {
        let interfaceOrientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
        switch interfaceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .portrait
        }
    }
    
    func stopRecording() async throws -> URL {
        guard isRecording else {
            throw RecordingError.notRecording
        }
        
        guard let session = cameraService.captureSession,
              let movieOutput = session.outputs.first(where: { $0 is AVCaptureMovieFileOutput }) as? AVCaptureMovieFileOutput else {
            throw RecordingError.outputNotConfigured
        }
        
        guard let outputURL = currentRecordingURL else {
            throw RecordingError.noOutputURL
        }
        
        return await withCheckedContinuation { continuation in
            recordingDelegate?.onFinish = { url, error in
                if let error = error {
                    AppLogger.recording.error("Recording finished with error: \(error.localizedDescription)")
                }
                continuation.resume(returning: url)
            }
            
            movieOutput.stopRecording()
            
            Task { @MainActor in
                self.isRecording = false
                self.stopTimer()
                self.audioService.stopMonitoring()
                
                AppLogger.recording.info("Recording stopped: \(outputURL.lastPathComponent)")
            }
        }
    }
    
    private func startTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
    
    func cleanup() {
        // Keep the capture session reusable (per project) and avoid tearing down the pipeline
        // immediately after stopping a recording; full teardown can trigger noisy Fig asserts.
        if isRecording {
            Task {
                try? await stopRecording()
            }
        }

        stopTimer()
        audioService.deactivateAudioSession()
        cameraService.stopSession()

        AppLogger.recording.info("Recording controller cleaned up (session retained)")
    }
}

private class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    var onFinish: ((URL, Error?) -> Void)?
    
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        onFinish?(outputFileURL, error)
    }
}

enum RecordingError: LocalizedError {
    case notAuthorized
    case alreadyRecording
    case notRecording
    case outputNotConfigured
    case noOutputURL
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera or microphone access not authorized"
        case .alreadyRecording:
            return "Recording already in progress"
        case .notRecording:
            return "No recording in progress"
        case .outputNotConfigured:
            return "Movie output not configured"
        case .noOutputURL:
            return "No output URL available"
        }
    }
}
