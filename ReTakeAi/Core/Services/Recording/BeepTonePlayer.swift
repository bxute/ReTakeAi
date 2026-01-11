//
//  BeepTonePlayer.swift
//  ReTakeAi
//

import AVFoundation

/// Deterministic short beep tone that plays through the app's audio session.
/// Avoids reliance on `AudioServices*` system sounds (which can be suppressed on some devices/routes).
final class BeepTonePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?
    private var isConfigured = false

    init() {}

    func play() {
        configureIfNeeded()

        guard let buffer else { return }

        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: []) {
            // no-op
        }
        if !player.isPlaying {
            player.play()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        let sampleRate = max(8_000, AVAudioSession.sharedInstance().sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        guard let format else { return }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        buffer = makeBeepBuffer(format: format, frequencyHz: 880, durationSeconds: 0.08)
    }

    private func makeBeepBuffer(format: AVAudioFormat, frequencyHz: Double, durationSeconds: Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(max(1, Int(format.sampleRate * durationSeconds)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames

        guard let channelData = buffer.floatChannelData else { return nil }
        let samples = channelData[0]

        // Smooth envelope to avoid clicks
        let attackFrames = max(1, Int(Double(frames) * 0.05))
        let releaseFrames = max(1, Int(Double(frames) * 0.08))
        let twoPi = 2.0 * Double.pi

        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            var amp: Double = 0.6
            if i < attackFrames {
                amp *= Double(i) / Double(attackFrames)
            } else if i > Int(frames) - releaseFrames {
                amp *= Double(Int(frames) - i) / Double(releaseFrames)
            }
            let v = sin(twoPi * frequencyHz * t) * amp
            samples[i] = Float(v)
        }

        return buffer
    }
}


