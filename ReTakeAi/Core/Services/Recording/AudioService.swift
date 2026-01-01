//
//  AudioService.swift
//  SceneFlow
//

import AVFoundation

class AudioService {
    static let shared = AudioService()
    
    private init() {}
    
    func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        try audioSession.setCategory(
            .playAndRecord,
            mode: .videoRecording,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        
        try audioSession.setActive(true)
        
        AppLogger.recording.info("Audio session configured")
    }
    
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            AppLogger.recording.info("Audio session deactivated")
        } catch {
            AppLogger.recording.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    func checkAuthorization() async -> Bool {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }
    
    func startMonitoring() {
        AppLogger.recording.info("Audio monitoring started")
    }
    
    func stopMonitoring() {
        AppLogger.recording.info("Audio monitoring stopped")
    }
}
