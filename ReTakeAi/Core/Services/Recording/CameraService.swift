//
//  CameraService.swift
//  SceneFlow
//

import AVFoundation
import UIKit

@MainActor
class CameraService: NSObject, ObservableObject {
    static let shared = CameraService()
    
    @Published private(set) var isSessionConfigured = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var captureSession: AVCaptureSession?
    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?

    // AVCaptureSession start/stop should not run on the main thread.
    private let sessionQueue = DispatchQueue(label: "com.retakeai.camera.session", qos: .userInitiated)
    
    private override init() {
        super.init()
    }
    
    func checkAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
        
        AppLogger.recording.info("Camera authorization: \(self.isAuthorized)")
    }
    
    func configureSession() async throws {
        guard !isSessionConfigured else { return }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Configure video input first to know which camera we're using
        try configureVideoInput(for: session)
        
        // Apply resolution from settings with fallback
        let resolution = UserDefaults.standard.string(forKey: "recording_resolution") ?? "1080p"
        let preset = bestAvailablePreset(for: resolution, session: session)
        session.sessionPreset = preset
        
        try configureAudioInput(for: session)
        try configureMovieOutput(for: session)
        
        // Apply frame rate from settings
        let frameRate = UserDefaults.standard.integer(forKey: "recording_frameRate")
        if frameRate > 0 {
            applyFrameRate(frameRate, to: videoInput?.device)
        }
        
        session.commitConfiguration()
        
        self.captureSession = session
        self.isSessionConfigured = true
        
        AppLogger.recording.info("Camera session configured with preset: \(preset.rawValue) @ \(frameRate)fps")
    }
    
    private func bestAvailablePreset(for resolution: String, session: AVCaptureSession) -> AVCaptureSession.Preset {
        let preferred = sessionPreset(for: resolution)
        
        // Check if preferred preset is supported
        if session.canSetSessionPreset(preferred) {
            return preferred
        }
        
        // Fallback chain: 4K → 1080p → 720p → high
        let fallbacks: [AVCaptureSession.Preset] = [.hd1920x1080, .hd1280x720, .high]
        for fallback in fallbacks {
            if session.canSetSessionPreset(fallback) {
                AppLogger.recording.warning("Requested \(resolution) not supported, falling back to \(fallback.rawValue)")
                return fallback
            }
        }
        
        return .high
    }
    
    private func sessionPreset(for resolution: String) -> AVCaptureSession.Preset {
        switch resolution {
        case "720p": return .hd1280x720
        case "4K": return .hd4K3840x2160
        default: return .hd1920x1080 // 1080p
        }
    }
    
    private func applyFrameRate(_ fps: Int, to device: AVCaptureDevice?) {
        guard let device = device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Only apply frame rate if current format supports it (don't change format)
            let desiredFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
            let currentFormat = device.activeFormat
            
            for range in currentFormat.videoSupportedFrameRateRanges {
                if range.minFrameRate <= Double(fps) && range.maxFrameRate >= Double(fps) {
                    device.activeVideoMinFrameDuration = desiredFrameDuration
                    device.activeVideoMaxFrameDuration = desiredFrameDuration
                    device.unlockForConfiguration()
                    AppLogger.recording.info("Applied frame rate: \(fps) fps")
                    return
                }
            }
            
            device.unlockForConfiguration()
            AppLogger.recording.warning("Current format doesn't support \(fps) fps, using default")
        } catch {
            AppLogger.recording.error("Failed to set frame rate: \(error.localizedDescription)")
        }
    }
    
    private func configureVideoInput(for session: AVCaptureSession) throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.deviceNotFound
        }
        
        let videoInput = try AVCaptureDeviceInput(device: camera)
        
        guard session.canAddInput(videoInput) else {
            throw CameraError.cannotAddInput
        }
        
        session.addInput(videoInput)
        self.videoInput = videoInput
        
        try camera.lockForConfiguration()
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }
        if camera.isExposureModeSupported(.continuousAutoExposure) {
            camera.exposureMode = .continuousAutoExposure
        }
        camera.unlockForConfiguration()
    }
    
    private func configureAudioInput(for session: AVCaptureSession) throws {
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw CameraError.deviceNotFound
        }
        
        let audioInput = try AVCaptureDeviceInput(device: microphone)
        
        guard session.canAddInput(audioInput) else {
            throw CameraError.cannotAddInput
        }
        
        session.addInput(audioInput)
        self.audioInput = audioInput
    }
    
    private func configureMovieOutput(for session: AVCaptureSession) throws {
        let movieOutput = AVCaptureMovieFileOutput()
        
        guard session.canAddOutput(movieOutput) else {
            throw CameraError.cannotAddOutput
        }
        
        session.addOutput(movieOutput)
        
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        self.movieOutput = movieOutput
    }
    
    func startSession() {
        guard let session = captureSession, !session.isRunning else { return }

        sessionQueue.async {
            session.startRunning()
            AppLogger.recording.info("Camera session started")
        }
    }
    
    func stopSession() {
        guard let session = captureSession, session.isRunning else { return }

        sessionQueue.async {
            session.stopRunning()
            AppLogger.recording.info("Camera session stopped")
        }
    }
    
    func switchCamera() async throws {
        guard let session = captureSession,
              let currentInput = videoInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .front ? .back : .front
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            throw CameraError.deviceNotFound
        }
        
        let newInput = try AVCaptureDeviceInput(device: newCamera)
        
        guard session.canAddInput(newInput) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        
        session.addInput(newInput)
        self.videoInput = newInput
        
        // Reapply resolution (may need fallback for front camera)
        let resolution = UserDefaults.standard.string(forKey: "recording_resolution") ?? "1080p"
        let preset = bestAvailablePreset(for: resolution, session: session)
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }
        
        // Reapply frame rate
        let frameRate = UserDefaults.standard.integer(forKey: "recording_frameRate")
        if frameRate > 0 {
            applyFrameRate(frameRate, to: newCamera)
        }
        
        if let connection = movieOutput?.connection(with: .video) {
            connection.isVideoMirrored = (newPosition == .front)
        }
        
        session.commitConfiguration()
        
        AppLogger.recording.info("Switched to \(newPosition == .front ? "front" : "back") camera with preset: \(preset.rawValue)")
    }
    
    func cleanup() {
        stopSession()
        captureSession = nil
        videoInput = nil
        audioInput = nil
        movieOutput = nil
        isSessionConfigured = false
        
        AppLogger.recording.info("Camera service cleaned up")
    }
}

enum CameraError: LocalizedError {
    case deviceNotFound
    case cannotAddInput
    case cannotAddOutput
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Camera or microphone not found"
        case .cannotAddInput:
            return "Cannot add input to capture session"
        case .cannotAddOutput:
            return "Cannot add output to capture session"
        case .notAuthorized:
            return "Camera access not authorized"
        }
    }
}
