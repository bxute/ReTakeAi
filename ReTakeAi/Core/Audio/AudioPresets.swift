//
//  AudioPresets.swift
//  ReTakeAi
//
//  Predefined audio processing presets
//

import Foundation

/// Collection of audio processing presets
struct AudioPresets {

    // MARK: - HPF Presets

    // Voice Frequency Reference:
    // - Male fundamentals: 85-180 Hz
    // - Female fundamentals: 165-255 Hz
    // - Rumble/AC hum: 20-60 Hz
    // Safe cutoff: 60-80 Hz (removes rumble, preserves all voice)

    /// Gentle HPF at 60 Hz - minimal filtering, preserves all voice (recommended for male voices)
    static let hpfGentle = ProcessorConfig([
        "cutoffFrequency": 60.0,
        "makeupGain": 3.0  // +3 dB makeup gain
    ])

    /// Standard HPF at 80 Hz - removes rumble while preserving voice
    static let hpfStandard = ProcessorConfig([
        "cutoffFrequency": 80.0,
        "makeupGain": 4.5  // +4.5 dB makeup gain
    ])

    /// Aggressive HPF at 100 Hz - for very noisy environments (may affect bass voice)
    static let hpfAggressive = ProcessorConfig([
        "cutoffFrequency": 100.0,
        "makeupGain": 6.0  // +6 dB makeup gain
    ])

    // MARK: - Voice Band-Pass Presets

    /// Wide voice range - preserves natural sound with breath
    static let voiceBandPassWide = ProcessorConfig([
        "lowCutoff": 70.0,
        "highCutoff": 5000.0,
        "order": 2
    ])

    /// Standard voice range - focused on voice fundamentals and harmonics
    static let voiceBandPassStandard = ProcessorConfig([
        "lowCutoff": 85.0,
        "highCutoff": 4000.0,
        "order": 2
    ])

    /// Narrow voice range - aggressive isolation, may sound muffled
    static let voiceBandPassNarrow = ProcessorConfig([
        "lowCutoff": 100.0,
        "highCutoff": 3500.0,
        "order": 2
    ])

    // MARK: - Voice EQ Presets

    /// Clarity preset - boost presence, reduce mud
    static let voiceEQClarity = ProcessorConfig([
        "preset": "clarity"
    ])

    /// Warmth preset - boost low-mids for warmth
    static let voiceEQWarmth = ProcessorConfig([
        "preset": "warmth"
    ])

    /// Broadcast preset - professional broadcast sound
    static let voiceEQBroadcast = ProcessorConfig([
        "preset": "broadcast"
    ])

    /// Podcast preset - balanced podcast sound
    static let voiceEQPodcast = ProcessorConfig([
        "preset": "podcast"
    ])

    // MARK: - Complete Voice Enhancement Presets

    /// Voice Clarity preset - complete enhancement pipeline for clear, prominent vocals
    static let vocalClarity: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "hpf": (true, hpfGentle),                           // Remove rumble
        "voiceBandPass": (true, voiceBandPassStandard),     // Isolate voice range
        "spectralNoiseReduction": (true, ProcessorConfig([
            "noiseProfileDuration": 0.5,
            "reductionAmount": 12.0,
            "smoothingFactor": 0.7
        ])),
        "adaptiveGate": (true, ProcessorConfig([
            "threshold": -40.0,
            "ratio": 10.0,
            "attack": 5.0,
            "release": 50.0,
            "kneeWidth": 6.0
        ])),
        "voiceEQ": (true, voiceEQClarity),
        "multiBandCompressor": (true, ProcessorConfig([
            "lowThreshold": -20.0,
            "lowRatio": 2.0,
            "midThreshold": -15.0,
            "midRatio": 3.0,
            "highThreshold": -12.0,
            "highRatio": 4.0,
            "attack": 5.0,
            "release": 100.0
        ])),
        "deEsser": (true, ProcessorConfig([
            "frequency": 7000.0,
            "threshold": -15.0,
            "ratio": 4.0,
            "bandwidth": 4000.0
        ])),
        "lufsNormalizer": (true, ProcessorConfig([
            "targetLUFS": -16.0,
            "truePeak": -1.0
        ]))
    ]

    /// Warm Vocals preset - warmer, more natural sound
    static let vocalWarmth: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "hpf": (true, hpfGentle),
        "voiceBandPass": (true, voiceBandPassWide),
        "spectralNoiseReduction": (true, ProcessorConfig([
            "noiseProfileDuration": 0.5,
            "reductionAmount": 10.0,
            "smoothingFactor": 0.8
        ])),
        "adaptiveGate": (true, ProcessorConfig([
            "threshold": -45.0,
            "ratio": 8.0,
            "attack": 10.0,
            "release": 100.0,
            "kneeWidth": 8.0
        ])),
        "voiceEQ": (true, voiceEQWarmth),
        "multiBandCompressor": (true, ProcessorConfig([
            "lowThreshold": -18.0,
            "lowRatio": 2.0,
            "midThreshold": -15.0,
            "midRatio": 2.5,
            "highThreshold": -12.0,
            "highRatio": 3.0,
            "attack": 10.0,
            "release": 150.0
        ])),
        "deEsser": (true, ProcessorConfig([
            "frequency": 7000.0,
            "threshold": -18.0,
            "ratio": 3.0,
            "bandwidth": 3500.0
        ])),
        "lufsNormalizer": (true, ProcessorConfig([
            "targetLUFS": -18.0,
            "truePeak": -1.0
        ]))
    ]

    /// Broadcast Voice preset - professional broadcast quality
    static let vocalBroadcast: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "hpf": (true, hpfStandard),
        "voiceBandPass": (true, voiceBandPassStandard),
        "spectralNoiseReduction": (true, ProcessorConfig([
            "noiseProfileDuration": 0.5,
            "reductionAmount": 15.0,
            "smoothingFactor": 0.6
        ])),
        "adaptiveGate": (true, ProcessorConfig([
            "threshold": -35.0,
            "ratio": 12.0,
            "attack": 3.0,
            "release": 40.0,
            "kneeWidth": 4.0
        ])),
        "voiceEQ": (true, voiceEQBroadcast),
        "multiBandCompressor": (true, ProcessorConfig([
            "lowThreshold": -22.0,
            "lowRatio": 3.0,
            "midThreshold": -15.0,
            "midRatio": 4.0,
            "highThreshold": -10.0,
            "highRatio": 5.0,
            "attack": 3.0,
            "release": 80.0
        ])),
        "deEsser": (true, ProcessorConfig([
            "frequency": 7000.0,
            "threshold": -12.0,
            "ratio": 5.0,
            "bandwidth": 4000.0
        ])),
        "lufsNormalizer": (true, ProcessorConfig([
            "targetLUFS": -16.0,
            "truePeak": -1.0
        ]))
    ]

    /// Podcast Voice preset - balanced podcast sound
    static let vocalPodcast: [String: (enabled: Bool, config: ProcessorConfig)] = [
        "hpf": (true, hpfGentle),
        "voiceBandPass": (true, voiceBandPassStandard),
        "spectralNoiseReduction": (true, ProcessorConfig([
            "noiseProfileDuration": 0.5,
            "reductionAmount": 12.0,
            "smoothingFactor": 0.75
        ])),
        "adaptiveGate": (true, ProcessorConfig([
            "threshold": -42.0,
            "ratio": 8.0,
            "attack": 8.0,
            "release": 80.0,
            "kneeWidth": 6.0
        ])),
        "voiceEQ": (true, voiceEQPodcast),
        "multiBandCompressor": (true, ProcessorConfig([
            "lowThreshold": -20.0,
            "lowRatio": 2.5,
            "midThreshold": -16.0,
            "midRatio": 3.0,
            "highThreshold": -12.0,
            "highRatio": 3.5,
            "attack": 8.0,
            "release": 120.0
        ])),
        "deEsser": (true, ProcessorConfig([
            "frequency": 7000.0,
            "threshold": -16.0,
            "ratio": 3.5,
            "bandwidth": 3800.0
        ])),
        "lufsNormalizer": (true, ProcessorConfig([
            "targetLUFS": -19.0,
            "truePeak": -1.0
        ]))
    ]
}
