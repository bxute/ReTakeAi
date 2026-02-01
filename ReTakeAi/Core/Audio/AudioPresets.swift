//
//  AudioPresets.swift
//  ReTakeAi
//
//  Predefined audio processing presets
//

import Foundation

/// Collection of audio processing presets for Dead Air Trimmer + Silence Attenuator
struct AudioPresets {

    // MARK: - Combined Presets (Dead Air Trimmer + Silence Attenuator)

    /// Natural Voice - Gentle trimming with subtle silence reduction
    /// Best for: Conversational videos, interviews, casual content
    /// Characteristics: Preserves natural pauses, minimal processing
    static let naturalVoice: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "deadAirTrimmer": (true, ProcessorConfig([
            "trimStart": true,
            "trimEnd": true,
            "trimMid": false,
            "startBuffer": 0.5,              // Keep 0.5s before voice (natural)
            "endBuffer": 0.5,                // Keep 0.5s after voice
            "minDeadAirDuration": 2.0,       // Only remove pauses > 2s
            "maxMidPauseDuration": 2.0,      // Not used (trimMid disabled)
            "minSustainedVoiceDuration": 0.05 // Catch almost all voice
        ])),
        "silenceAttenuator": (true, ProcessorConfig([
            "frameSize": 0.020,
            "attenuation": -3.0,             // Gentle -3 dB reduction
            "thresholdOffset": 6.0,          // Conservative (less aggressive)
            "attackTime": 0.015,             // Slow attack (15ms)
            "releaseTime": 0.250             // Slow release (250ms)
        ]))
    ]

    /// Podcast Pro - Balanced for spoken word content
    /// Best for: Podcasts, tutorials, educational content
    /// Characteristics: Clean pauses, clear voice, professional sound
    static let podcastPro: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "deadAirTrimmer": (true, ProcessorConfig([
            "trimStart": true,
            "trimEnd": true,
            "trimMid": false,
            "startBuffer": 0.25,             // Standard 0.25s buffer
            "endBuffer": 0.25,
            "minDeadAirDuration": 1.0,       // Remove pauses > 1s
            "maxMidPauseDuration": 1.5,
            "minSustainedVoiceDuration": 0.1 // Standard voice detection
        ])),
        "silenceAttenuator": (true, ProcessorConfig([
            "frameSize": 0.020,
            "attenuation": -5.0,             // Standard -5 dB reduction
            "thresholdOffset": 8.0,          // Balanced threshold
            "attackTime": 0.012,             // Standard attack (12ms)
            "releaseTime": 0.200             // Standard release (200ms)
        ]))
    ]

    /// Quick Edit - Aggressive trimming for fast-paced content
    /// Best for: Social media, vlogs, fast cuts, energetic content
    /// Characteristics: Tight timing, removes all excess air, punchy
    static let quickEdit: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "deadAirTrimmer": (true, ProcessorConfig([
            "trimStart": true,
            "trimEnd": true,
            "trimMid": true,                 // Also trim mid-scene pauses
            "startBuffer": 0.1,              // Minimal buffer (0.1s)
            "endBuffer": 0.1,
            "minDeadAirDuration": 0.5,       // Remove pauses > 0.5s
            "maxMidPauseDuration": 1.0,      // Compress mid pauses to 1s
            "minSustainedVoiceDuration": 0.15 // Stricter voice detection
        ])),
        "silenceAttenuator": (true, ProcessorConfig([
            "frameSize": 0.020,
            "attenuation": -6.0,             // Aggressive -6 dB reduction
            "thresholdOffset": 10.0,         // Higher threshold (more aggressive)
            "attackTime": 0.010,             // Fast attack (10ms)
            "releaseTime": 0.150             // Fast release (150ms)
        ]))
    ]

    /// Studio Clean - Maximum cleanup for professional sound
    /// Best for: Professional videos, voiceovers, announcements
    /// Characteristics: Pristine silence, tight edits, broadcast quality
    static let studioClean: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "deadAirTrimmer": (true, ProcessorConfig([
            "trimStart": true,
            "trimEnd": true,
            "trimMid": true,
            "startBuffer": 0.15,             // Tight but safe buffer
            "endBuffer": 0.15,
            "minDeadAirDuration": 0.7,       // Remove pauses > 0.7s
            "maxMidPauseDuration": 1.2,      // Compress mid pauses to 1.2s
            "minSustainedVoiceDuration": 0.2 // Very strict (only clear speech)
        ])),
        "silenceAttenuator": (true, ProcessorConfig([
            "frameSize": 0.020,
            "attenuation": -8.0,             // Maximum -8 dB reduction
            "thresholdOffset": 12.0,         // Very high threshold
            "attackTime": 0.008,             // Very fast attack (8ms)
            "releaseTime": 0.180             // Moderately fast release (180ms)
        ]))
    ]

    /// Minimal Touch - Very light processing for clean recordings
    /// Best for: Studio recordings, professional mic setups, low-noise environments
    /// Characteristics: Preserves all natural pauses, barely touches the audio
    static let minimalTouch: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "deadAirTrimmer": (true, ProcessorConfig([
            "trimStart": true,
            "trimEnd": true,
            "trimMid": false,                // Never trim mid-scene pauses
            "startBuffer": 1.0,              // Keep full 1.0s before voice
            "endBuffer": 1.0,                // Keep full 1.0s after voice
            "minDeadAirDuration": 3.0,       // Only remove pauses > 3s (very long)
            "maxMidPauseDuration": 2.0,      // Not used (trimMid disabled)
            "minSustainedVoiceDuration": 0.03 // Catch almost everything (30ms)
        ])),
        "silenceAttenuator": (true, ProcessorConfig([
            "frameSize": 0.020,
            "attenuation": -2.0,             // Minimal -2 dB reduction
            "thresholdOffset": 4.0,          // Very conservative threshold
            "attackTime": 0.020,             // Very slow attack (20ms)
            "releaseTime": 0.300             // Very slow release (300ms)
        ]))
    ]

    /// Ultra Aggressive - Maximum cleanup for noisy/problematic audio
    /// Best for: Noisy environments, distant mic, lots of background noise
    /// Characteristics: Removes everything possible, very tight timing
    static let ultraAggressive: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "deadAirTrimmer": (true, ProcessorConfig([
            "trimStart": true,
            "trimEnd": true,
            "trimMid": true,                 // Trim all long pauses
            "startBuffer": 0.05,             // Absolute minimum buffer (50ms)
            "endBuffer": 0.05,               // Absolute minimum buffer (50ms)
            "minDeadAirDuration": 0.3,       // Remove pauses > 0.3s (very sensitive)
            "maxMidPauseDuration": 0.8,      // Compress mid pauses to 0.8s
            "minSustainedVoiceDuration": 0.25 // Very strict (250ms minimum)
        ])),
        "silenceAttenuator": (true, ProcessorConfig([
            "frameSize": 0.020,
            "attenuation": -12.0,            // Extreme -12 dB reduction
            "thresholdOffset": 15.0,         // Very aggressive threshold
            "attackTime": 0.005,             // Ultra-fast attack (5ms)
            "releaseTime": 0.100             // Ultra-fast release (100ms)
        ]))
    ]

    // MARK: - Preset Helpers

    /// Get list of all available preset names
    static let allPresets: [(name: String, preset: [String: (enabled: Bool, config: ProcessorConfig)])] = [
        ("Minimal Touch", minimalTouch),
        ("Natural Voice", naturalVoice),
        ("Podcast Pro", podcastPro),
        ("Quick Edit", quickEdit),
        ("Studio Clean", studioClean),
        ("Ultra Aggressive", ultraAggressive)
    ]

    /// Get preset description
    static func description(for presetName: String) -> String {
        switch presetName {
        case "Minimal Touch":
            return "Very light processing for clean recordings. Preserves natural pauses and audio character."
        case "Natural Voice":
            return "Gentle trimming with subtle silence reduction. Best for conversational videos and interviews."
        case "Podcast Pro":
            return "Balanced for spoken word content. Clean pauses and professional sound."
        case "Quick Edit":
            return "Aggressive trimming for fast-paced content. Perfect for social media and vlogs."
        case "Studio Clean":
            return "Maximum cleanup for professional sound. Pristine silence and broadcast quality."
        case "Ultra Aggressive":
            return "Extreme cleanup for noisy environments. Removes everything possible with very tight timing."
        default:
            return "Custom preset"
        }
    }
}
