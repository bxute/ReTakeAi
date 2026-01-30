# ReTakeAi Audio Engine - Design Document

## Overview

This document outlines the design and implementation plan for ReTakeAi's production-grade audio processing engine. The engine is designed to be modular, configurable, and preset-based, making professional audio processing accessible while maintaining flexibility.

## Goals & Requirements

### Must-Have Features (Priority 1)
- **Noise Reduction** - Remove background noise, hiss, hum, AC noise
- **Volume Normalization** - Consistent loudness across takes/scenes
- **Compression/Limiting** - Smooth dynamic range, prevent clipping
- **Voice Enhancement/Clarity** - Optimize frequency response for speech
- **De-essing** - Reduce harsh "S" and "T" sounds
- **Gate/Expander** - Remove silence and quiet background noise

### Must-Have Features (Priority 2)
- **EQ/Tone Shaping** - Adjustable frequency bands for warmth/brightness
- **Reverb Removal** - Clean up room echo and reflections
- **Loudness Standards** - Match broadcast levels (LUFS: -16, -23, -14)
- **Pop/Plosive Removal** - Remove "P" and "B" mouth sounds
- **Click/Mouth Noise Removal** - Clean up lip smacks, breaths

### Core Requirements
1. **Preset-Based System** - Multiple presets with different configurations
2. **Modular Architecture** - Easy to add/remove processors
3. **Dead Air Handling** - Smart pause management with specific rules:
   - **Within Scene**: Preserve natural pauses and timing
   - **Between Scenes**: Trim silence at scene boundaries
   - **Fully Configurable**: Start/end/mid-scene trimming options
4. **Audio/Video Sync Safety** - No drift when trimming
5. **Full-Merge Processing** - Process complete merged audio as one cohesive piece
6. **Smart Transitions** - No abrupt or mechanical cuts

## Architecture Overview

### Two-Pass Processing System

#### Pass 1: Scene-Level Processing
- Process each take independently
- Apply audio enhancement preset
- Preserve natural timing and pauses
- Output: Clean individual takes with timing info

#### Pass 2: Assembly & Full-Merge Processing
- Trim silence at scene boundaries (configurable)
- Apply smart transitions between scenes
- Process entire merged audio as single cohesive piece
- Maintain perfect audio/video sync
- Output: Professional final audio track

---

## Folder Structure

```
ReTakeAi/Core/Audio/
├── AudioEngine/
│   ├── ReTakeAudioEngine.swift          // Main orchestrator for per-take processing
│   ├── AudioProcessingChain.swift        // Pipeline manager for processor sequence
│   └── AudioProcessingContext.swift      // Shared state/buffers between processors
│
├── Processors/
│   ├── AudioProcessorProtocol.swift      // Base interface all processors implement
│   ├── NoiseReductionProcessor.swift     // Background noise removal
│   ├── NormalizationProcessor.swift      // Volume normalization
│   ├── CompressionProcessor.swift        // Dynamic range compression
│   ├── VoiceEnhancementProcessor.swift   // Speech frequency optimization
│   ├── DeEsserProcessor.swift            // Sibilance reduction
│   ├── GateProcessor.swift               // Noise gate / expander
│   ├── EQProcessor.swift                 // Parametric EQ
│   ├── ReverbRemovalProcessor.swift      // Room reflection removal
│   ├── LoudnessNormalizerProcessor.swift // LUFS-based normalization
│   ├── PopRemovalProcessor.swift         // Plosive removal
│   └── ClickRemovalProcessor.swift       // Mouth noise removal
│
├── Assembly/
│   ├── SceneAudioAssembler.swift         // Main orchestrator for merging
│   ├── DeadAirTrimmer.swift              // Configurable silence trimming
│   ├── AudioVideoSyncManager.swift       // Ensures perfect A/V sync
│   ├── TransitionEngine.swift            // Smart crossfades and blending
│   └── FullMergeProcessor.swift          // Pass 2: process complete merged audio
│
├── Presets/
│   ├── AudioPreset.swift                 // Per-take processing preset model
│   ├── MergePreset.swift                 // Assembly/merge preset model
│   ├── PresetManager.swift               // Load/save/manage presets
│   └── DefaultPresets.swift              // Built-in preset definitions
│
├── Models/
│   ├── AudioProcessingConfig.swift       // Per-processor configuration
│   ├── ProcessorParameters.swift         // Typed parameter definitions
│   ├── AudioQualityMetrics.swift         // Analysis results and quality metrics
│   ├── SceneAssemblyConfig.swift         // Assembly configuration
│   ├── TrimConfig.swift                  // Granular trimming control
│   └── SyncCompensation.swift            // Video adjustment tracking
│
└── Utilities/
    ├── AudioAnalyzer.swift               // Pre-analysis (noise profile, levels, etc.)
    ├── AudioFileHandler.swift            // I/O operations
    └── SilenceDetector.swift             // Silence detection utilities
```

---

## Processing Order

### Pass 1: Per-Take/Scene Processing (Preserve Timing)

```
1. AudioAnalyzer (Pre-scan)
   ↓ [Analyze noise floor, detect silence, get audio characteristics]

2. GateProcessor (light - just noise floor)
   ↓ [Initial silence suppression, set threshold above noise floor]

3. NoiseReductionProcessor
   ↓ [Remove background noise]

4. PopRemovalProcessor
   ↓ [Remove plosives]

5. ClickRemovalProcessor
   ↓ [Remove mouth noises]

6. DeEsserProcessor
   ↓ [Reduce harsh sibilance]

7. EQProcessor / VoiceEnhancementProcessor
   ↓ [Shape tone and frequency response]

8. CompressionProcessor
   ↓ [Smooth dynamics]

9. ReverbRemovalProcessor
   ↓ [Clean up room reflections]

10. NormalizationProcessor
   ↓ [Initial level matching]
```

**Key**: NO dead air trimming in Pass 1 - preserve authentic delivery and timing!

### Pass 2: Assembly & Full-Merge Processing

```
1. Load all processed takes from Pass 1

2. ANALYZE COMPLETE MERGED AUDIO (before trimming)
   - Global noise profile
   - Overall loudness curve
   - Scene-to-scene level variations
   - Pause/silence map across entire piece

3. INTELLIGENT TRIMMING with Sync Protection
   For each scene boundary:
     - Detect silence ranges
     - Apply trim configuration
     - Calculate sync compensation
     - Track video adjustments

4. SMART TRANSITIONS
   - Analyze frequency content at boundaries
   - Create context-aware crossfades
   - Match room tone characteristics
   - Blend frequencies smoothly

5. FULL-MERGE PROCESSING (Process as one piece!)
   - Adaptive dynamics across entire audio
   - Smooth level variations between scenes
   - Global EQ pass for cohesion
   - Master compression for consistency
   - Final loudness normalization (LUFS)
   - Subtle "audio glue" processing

6. FINAL QUALITY CHECK
   - Verify no sync drift
   - Check for clicks at transitions
   - Analyze loudness compliance
   - Generate quality report
```

---

## Key Models & Configurations

### 1. AudioProcessorProtocol

```swift
protocol AudioProcessorProtocol {
    /// Unique identifier for the processor type
    var processorID: String { get }

    /// Human-readable name
    var displayName: String { get }

    /// Process audio buffer with given configuration
    func process(
        buffer: AVAudioPCMBuffer,
        config: ProcessorConfig,
        context: AudioProcessingContext
    ) -> Result<AVAudioPCMBuffer, AudioProcessingError>

    /// Whether this processor modifies timing/duration
    var affectsTiming: Bool { get }

    /// Optional pre-analysis step
    func analyze(buffer: AVAudioPCMBuffer) -> ProcessorAnalysis?
}
```

### 2. TrimConfig (Fully Configurable)

```swift
struct TrimConfig: Codable {
    // Where to trim
    var trimSceneStarts: Bool = true
    var trimSceneEnds: Bool = true
    var trimMidScenePauses: Bool = false      // Within scene

    // Silence detection parameters
    var silenceThreshold: Float = -40         // dB
    var minimumSilenceDuration: TimeInterval = 0.3  // Ignore short pauses
    var maxPauseLength: TimeInterval? = 2.0   // Cap long pauses to this duration

    // Smart behavior
    var preserveNaturalBreaths: Bool = true
    var smartPauseReduction: Bool = true      // Shorten but don't remove
    var reductionFactor: Float = 0.5          // Reduce pauses by 50%

    // Per-scene overrides
    var sceneOverrides: [UUID: SceneTrimOverride]?
}

struct SceneTrimOverride: Codable {
    var sceneID: UUID
    var trimStart: Bool?                      // Override global setting
    var trimEnd: Bool?                        // Override global setting
    var preserveAllPauses: Bool?              // Keep dramatic pauses
}
```

### 3. SyncStrategy & Compensation

```swift
/// How to handle video sync when trimming audio
enum SyncStrategy: Codable {
    case trimBoth              // Trim video + audio together (visual cut)
    case volumeAutomation      // Use fades instead of trimming (no video cut)
    case speedCompensation     // Subtle video speed adjustment (1-5%, use sparingly)
    case visualTransition      // Add fade/dissolve to mask cut
}

struct SyncCompensation: Codable {
    var strategy: SyncStrategy
    var videoTrimRanges: [CMTimeRange]        // Ranges to cut from video
    var volumeEnvelope: [TimePoint: Float]?   // Volume automation points
    var visualTransitions: [VideoTransition]?  // Fade overlays

    /// Verify no sync drift
    var totalAudioDuration: TimeInterval
    var totalVideoDuration: TimeInterval
    var syncOffset: TimeInterval              // Should be ~0
}
```

### 4. SceneAssemblyConfig

```swift
struct SceneAssemblyConfig: Codable {
    // Trimming configuration
    var trimConfig: TrimConfig
    var syncStrategy: SyncStrategy

    // Transition style between scenes
    var transitionType: TransitionType = .smartCrossfade
    var transitionDuration: TimeInterval = 0.5

    // Full-merge processing (Pass 2)
    var enableFullMergeProcessing: Bool = true
    var fullMergePresetName: String = "Cohesive Master"

    // Analysis & optimization
    var analyzeCompleteAudio: Bool = true     // Global noise profile
    var adaptiveProcessing: Bool = true       // Context-aware adjustments
    var roomToneMatching: Bool = true         // Match ambience across scenes
}

enum TransitionType: Codable {
    case cut                    // No transition
    case crossfade             // Simple overlap
    case smartCrossfade        // Frequency-aware blending
    case fadeOutIn             // Gap between scenes
    case volumeDuck            // Lower first, raise second
    case roomToneBlend         // Use room tone for natural transition
}
```

### 5. AudioPreset (Per-Take Processing)

```swift
struct AudioPreset: Codable, Identifiable {
    var id: UUID
    var name: String
    var description: String
    var category: PresetCategory

    // Enabled processors (order matters!)
    var processingChain: [ProcessorConfig]

    // Global settings
    var targetLoudness: Float = -16.0  // LUFS
    var preserveDynamics: Bool = true
}

struct ProcessorConfig: Codable {
    var processorID: String
    var enabled: Bool
    var parameters: [String: ProcessorParameter]
}

enum ProcessorParameter: Codable {
    case float(Float)
    case int(Int)
    case bool(Bool)
    case string(String)
    case curve([CGPoint])  // For advanced EQ, compression curves
}
```

### 6. MergePreset (Assembly Processing)

```swift
struct MergePreset: Codable, Identifiable {
    var id: UUID
    var name: String
    var description: String

    // Assembly configuration
    var assemblyConfig: SceneAssemblyConfig

    // Full-merge processing settings
    var globalCompression: CompressionConfig?
    var globalEQ: EQConfig?
    var masterLimiter: LimiterConfig?
    var audioGlue: AudioGlueConfig?  // Saturation, parallel compression

    // Quality targets
    var targetLUFS: Float = -16.0
    var peakLimit: Float = -1.0  // dBFS
    var dynamicRange: Float = 8.0  // dB
}
```

---

## Smart Features & Algorithms

### 1. Context-Aware Transitions

The `TransitionEngine` analyzes both sides of a scene boundary:

```swift
// Analyze frequency content
scene1End = analyzeSpectrum(scene1, lastNSeconds: 0.5)
scene2Start = analyzeSpectrum(scene2, firstNSeconds: 0.5)

// Determine transition strategy
if scene1End.hasHighEnergy && scene2Start.hasDialogue {
    // Use quick fade to preserve attack of next scene
    transition = .quickFade(duration: 0.2)
} else if scene1End.hasLowRoomTone && scene2Start.hasLowRoomTone {
    // Match room tones and blend
    transition = .roomToneBlend(duration: 0.5)
} else {
    // Standard smart crossfade with frequency matching
    transition = .smartCrossfade(duration: 0.5)
}

// Apply frequency-matched crossfade
applyTransition(transition, matchingFrequencyBands: true)
```

### 2. Intelligent Pause Reduction (Not Removal!)

Instead of cutting silence completely, use time-stretching for natural sound:

```swift
// Original pause: 3 seconds
// Target: 0.8 seconds (73% reduction)

if trimConfig.smartPauseReduction {
    // Use time-stretching (preserves pitch and tone)
    stretchedPause = timeStretch(
        originalPause,
        fromDuration: 3.0,
        toDuration: 0.8,
        preservePitch: true,
        quality: .high
    )

    // Result: Still sounds like natural pause, just shorter
} else {
    // Hard cut (can sound unnatural)
    trimmedPause = cut(originalPause, to: 0.8)
}
```

### 3. Sync-Safe Processing

Every audio edit must track video impact:

```swift
// When trimming audio
let audioTrimRange = CMTimeRange(start: CMTime(seconds: 10.5), duration: CMTime(seconds: 0.5))

switch syncStrategy {
case .trimBoth:
    // Cut both audio and video at exact same timestamps
    let videoTrimRange = audioTrimRange  // Exact match
    applyTrim(audio: audioTrimRange, video: videoTrimRange)

case .volumeAutomation:
    // Keep video, fade audio
    let volumeCurve = createFadeCurve(for: audioTrimRange)
    applyVolumeFade(audio: volumeCurve, video: .noChange)

case .visualTransition:
    // Trim audio, add video dissolve to mask
    applyTrim(audio: audioTrimRange)
    addVideoTransition(.dissolve, at: audioTrimRange.start)
}

// Verify sync
assert(totalAudioDuration == totalVideoDuration, "Sync drift detected!")
```

### 4. Full-Merge Master Processing

Process entire merged audio as one cohesive piece:

```swift
// After scene assembly, before final export
func applyFullMergeProcessing(mergedAudio: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
    var audio = mergedAudio

    // 1. Global noise profile pass
    if config.analyzeCompleteAudio {
        let globalNoiseProfile = analyzeNoise(audio, consideringAllScenes: true)
        audio = applyGlobalNoiseReduction(audio, profile: globalNoiseProfile)
    }

    // 2. Adaptive dynamics across entire piece
    audio = applyAdaptiveCompression(audio, multiband: true)

    // 3. Smooth level variations between scenes
    audio = smoothSceneTransitions(audio, sceneMarkers: sceneTimestamps)

    // 4. Global EQ pass for cohesion
    audio = applyMasterEQ(audio, targetTone: .balanced)

    // 5. Master compression for consistency
    audio = applyMasterCompression(audio, ratio: 2.5, threshold: -12)

    // 6. Audio glue (subtle saturation, parallel compression)
    if config.audioGlue.enabled {
        audio = applySaturation(audio, amount: .subtle)
        audio = applyParallelCompression(audio, blend: 0.3)
    }

    // 7. Final loudness normalization
    audio = normalizeLoudness(audio, targetLUFS: -16.0)

    // 8. Peak limiting (safety)
    audio = applyLimiter(audio, ceiling: -1.0)

    return audio
}
```

---

## Built-in Presets

### Scene Processing Presets (Pass 1)

#### 1. Studio Voice
```swift
AudioPreset(
    name: "Studio Voice",
    description: "Warm, professional, minimal processing",
    processingChain: [
        .gate(threshold: -45, ratio: 4),
        .noiseReduction(strength: .medium),
        .popRemoval(sensitivity: .medium),
        .deEsser(threshold: -20, frequency: 6000),
        .eq(preset: .warmVoice),  // Boost 200Hz, cut 3kHz harshness
        .compression(ratio: 2.5, threshold: -18, knee: .soft),
        .normalization(target: -16)
    ]
)
```

#### 2. Podcast Pro
```swift
AudioPreset(
    name: "Podcast Pro",
    description: "Broadcast-ready, heavy compression for consistent levels",
    processingChain: [
        .gate(threshold: -50, ratio: 6),
        .noiseReduction(strength: .heavy),
        .popRemoval(sensitivity: .high),
        .clickRemoval(enabled: true),
        .deEsser(threshold: -18, frequency: 7000),
        .eq(preset: .radioVoice),  // Presence boost, low cut
        .compression(ratio: 4.0, threshold: -15, knee: .hard),
        .loudnessNormalization(target: -16, truePeak: -1.0)
    ]
)
```

#### 3. Clear Narration
```swift
AudioPreset(
    name: "Clear Narration",
    description: "Maximum clarity and intelligibility",
    processingChain: [
        .gate(threshold: -48, ratio: 5),
        .noiseReduction(strength: .maximum),
        .popRemoval(sensitivity: .high),
        .clickRemoval(enabled: true),
        .deEsser(threshold: -20, frequency: 6500),
        .eq(preset: .clarity),  // Mid boost, notch harsh frequencies
        .voiceEnhancement(preset: .maximum),
        .compression(ratio: 3.0, threshold: -16, knee: .soft),
        .reverbRemoval(strength: .medium),
        .normalization(target: -16)
    ]
)
```

#### 4. Cinematic
```swift
AudioPreset(
    name: "Cinematic",
    description: "Rich, theatrical tone with depth",
    processingChain: [
        .gate(threshold: -42, ratio: 3),
        .noiseReduction(strength: .light),
        .popRemoval(sensitivity: .medium),
        .deEsser(threshold: -22, frequency: 5500),
        .eq(preset: .cinematic),  // Deep low end, smooth highs
        .compression(ratio: 2.0, threshold: -20, knee: .soft),
        .reverbRemoval(strength: .light),  // Keep some room
        .normalization(target: -18)  // More dynamic range
    ]
)
```

#### 5. Clean & Natural
```swift
AudioPreset(
    name: "Clean & Natural",
    description: "Light touch, preserve authenticity",
    processingChain: [
        .gate(threshold: -40, ratio: 2),
        .noiseReduction(strength: .light),
        .popRemoval(sensitivity: .low),
        .deEsser(threshold: -24, frequency: 6000),
        .eq(preset: .neutral),  // Minimal shaping
        .compression(ratio: 1.8, threshold: -22, knee: .soft),
        .normalization(target: -16)
    ]
)
```

#### 6. Radio Voice
```swift
AudioPreset(
    name: "Radio Voice",
    description: "Classic radio sound, heavy processing",
    processingChain: [
        .gate(threshold: -52, ratio: 8),
        .noiseReduction(strength: .heavy),
        .popRemoval(sensitivity: .high),
        .clickRemoval(enabled: true),
        .deEsser(threshold: -16, frequency: 7500),
        .eq(preset: .radioClassic),  // Aggressive presence peak
        .compression(ratio: 5.0, threshold: -12, knee: .hard),
        .loudnessNormalization(target: -14, truePeak: -0.5)
    ]
)
```

### Merge Processing Presets (Pass 2)

#### 1. Cohesive Master (Default)
```swift
MergePreset(
    name: "Cohesive Master",
    description: "Smooth, professional, natural transitions",
    assemblyConfig: SceneAssemblyConfig(
        trimConfig: TrimConfig(
            trimSceneStarts: true,
            trimSceneEnds: true,
            trimMidScenePauses: false,
            smartPauseReduction: false
        ),
        syncStrategy: .volumeAutomation,  // Safest
        transitionType: .smartCrossfade,
        transitionDuration: 0.5,
        enableFullMergeProcessing: true,
        roomToneMatching: true
    ),
    globalCompression: .adaptive(ratio: 2.0),
    globalEQ: .gentle,
    masterLimiter: .broadcast(ceiling: -1.0),
    audioGlue: .subtle,
    targetLUFS: -16.0
)
```

#### 2. Tight & Punchy
```swift
MergePreset(
    name: "Tight & Punchy",
    description: "Fast-paced, minimal pauses, quick cuts",
    assemblyConfig: SceneAssemblyConfig(
        trimConfig: TrimConfig(
            trimSceneStarts: true,
            trimSceneEnds: true,
            trimMidScenePauses: true,
            maxPauseLength: 1.0,
            smartPauseReduction: true,
            reductionFactor: 0.6
        ),
        syncStrategy: .trimBoth,  // Visual cuts OK
        transitionType: .cut,
        enableFullMergeProcessing: true
    ),
    globalCompression: .aggressive(ratio: 4.0),
    masterLimiter: .maximum(ceiling: -0.5),
    targetLUFS: -14.0  // Louder
)
```

#### 3. Cinematic Flow
```swift
MergePreset(
    name: "Cinematic Flow",
    description: "Preserve dramatic pauses, gentle transitions",
    assemblyConfig: SceneAssemblyConfig(
        trimConfig: TrimConfig(
            trimSceneStarts: false,  // Keep scene starts
            trimSceneEnds: false,    // Keep scene ends
            trimMidScenePauses: false
        ),
        syncStrategy: .volumeAutomation,
        transitionType: .fadeOutIn,
        transitionDuration: 1.0,  // Longer transitions
        enableFullMergeProcessing: true
    ),
    globalCompression: .gentle(ratio: 1.8),
    globalEQ: .warmCinematic,
    audioGlue: .vintage,
    targetLUFS: -18.0  // More dynamic
)
```

#### 4. Podcast Standard
```swift
MergePreset(
    name: "Podcast Standard",
    description: "Industry-standard podcast processing",
    assemblyConfig: SceneAssemblyConfig(
        trimConfig: TrimConfig(
            trimSceneStarts: true,
            trimSceneEnds: true,
            trimMidScenePauses: true,
            maxPauseLength: 1.5,
            smartPauseReduction: true
        ),
        syncStrategy: .volumeAutomation,
        transitionType: .crossfade,
        transitionDuration: 0.3,
        enableFullMergeProcessing: true
    ),
    globalCompression: .podcast(ratio: 3.5),
    masterLimiter: .broadcast(ceiling: -1.0),
    targetLUFS: -16.0
)
```

---

## Integration with Existing Code

### 1. Integration with VideoMerger

The existing `VideoMerger.swift` workflow becomes:

```swift
class VideoMerger {
    let audioEngine = ReTakeAudioEngine.shared
    let audioAssembler = SceneAudioAssembler.shared

    func mergeScenes(
        project: Project,
        scenes: [VideoScene],
        audioPreset: AudioPreset,
        mergePreset: MergePreset
    ) async throws -> URL {

        // 1. Process each take's audio (Pass 1)
        var processedTakes: [UUID: URL] = [:]
        for scene in scenes {
            guard let selectedTakeID = scene.selectedTakeID,
                  let take = getTake(selectedTakeID) else { continue }

            let processedAudio = try await audioEngine.process(
                audioURL: take.fileURL,
                preset: audioPreset
            )
            processedTakes[take.id] = processedAudio
        }

        // 2. Assemble and process complete audio (Pass 2)
        let finalAudio = try await audioAssembler.assemble(
            takes: processedTakes,
            sceneOrder: scenes.map { $0.id },
            mergePreset: mergePreset
        )

        // 3. Merge video tracks (existing logic)
        let mergedVideo = try await mergeVideoTracks(scenes: scenes)

        // 4. Apply sync compensation if needed
        let syncedVideo = try await applySyncCompensation(
            video: mergedVideo,
            compensation: finalAudio.syncCompensation
        )

        // 5. Combine processed audio with synced video
        let finalURL = try await combineAudioVideo(
            video: syncedVideo,
            audio: finalAudio.url
        )

        return finalURL
    }
}
```

### 2. Integration with RecordingController

Optionally process audio in real-time during recording (preview):

```swift
class RecordingController {
    var liveProcessing: Bool = false
    var previewPreset: AudioPreset?

    func setupAudioSession() {
        // Existing audio session setup...

        // Optional: Add live processing chain
        if liveProcessing, let preset = previewPreset {
            addLiveProcessingChain(preset: preset)
        }
    }

    private func addLiveProcessingChain(preset: AudioPreset) {
        // Use AVAudioEngine for real-time processing
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Add processor nodes based on preset
        // (Lightweight processing only - full processing happens in Pass 1)
    }
}
```

### 3. New UI Components Needed

```swift
// Settings/PresetSelectionView.swift
struct AudioPresetSelectionView: View {
    @Binding var selectedPreset: AudioPreset
    let presets = PresetManager.shared.audioPresets

    var body: some View {
        List(presets) { preset in
            PresetRow(preset: preset, isSelected: selectedPreset.id == preset.id)
                .onTapGesture { selectedPreset = preset }
        }
    }
}

// Settings/MergePresetSelectionView.swift
struct MergePresetSelectionView: View {
    @Binding var selectedPreset: MergePreset
    let presets = PresetManager.shared.mergePresets

    var body: some View {
        List(presets) { preset in
            MergePresetRow(preset: preset, isSelected: selectedPreset.id == preset.id)
                .onTapGesture { selectedPreset = preset }
        }
    }
}

// Features/VideoExport/AudioProcessingPreview.swift
struct AudioProcessingPreview: View {
    let originalURL: URL
    let processedURL: URL

    var body: some View {
        VStack {
            Text("Before/After Comparison")

            HStack {
                AudioPlayerView(url: originalURL, label: "Original")
                AudioPlayerView(url: processedURL, label: "Processed")
            }

            WaveformComparisonView(original: originalURL, processed: processedURL)
        }
    }
}
```

### 4. Project Model Updates

Add audio preset tracking to `Project`:

```swift
struct Project: Codable, Identifiable {
    // Existing properties...

    // Audio processing settings
    var audioPresetID: UUID?  // Selected AudioPreset
    var mergePresetID: UUID?  // Selected MergePreset
    var lastProcessedDate: Date?
    var audioProcessingMetrics: AudioQualityMetrics?
}
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create folder structure
- [ ] Implement `AudioProcessorProtocol`
- [ ] Implement `AudioProcessingContext`
- [ ] Implement `AudioProcessingChain`
- [ ] Create base models (configs, parameters, etc.)
- [ ] Implement `AudioAnalyzer`
- [ ] Implement `SilenceDetector`

### Phase 2: Core Processors (Week 2-3)
- [ ] Implement `GateProcessor`
- [ ] Implement `NoiseReductionProcessor`
- [ ] Implement `NormalizationProcessor`
- [ ] Implement `CompressionProcessor`
- [ ] Implement `DeEsserProcessor`
- [ ] Implement `PopRemovalProcessor`
- [ ] Implement `ClickRemovalProcessor`
- [ ] Unit tests for each processor

### Phase 3: Advanced Processors (Week 3-4)
- [ ] Implement `EQProcessor`
- [ ] Implement `VoiceEnhancementProcessor`
- [ ] Implement `ReverbRemovalProcessor`
- [ ] Implement `LoudnessNormalizerProcessor`
- [ ] Unit tests for each processor

### Phase 4: Scene Processing Engine (Week 4-5)
- [ ] Implement `ReTakeAudioEngine`
- [ ] Implement preset system (`AudioPreset`, `PresetManager`)
- [ ] Create default presets
- [ ] Integration tests
- [ ] Test with real takes

### Phase 5: Assembly System (Week 5-6)
- [ ] Implement `DeadAirTrimmer`
- [ ] Implement `AudioVideoSyncManager`
- [ ] Implement `TransitionEngine`
- [ ] Implement `SceneAudioAssembler`
- [ ] Create merge presets
- [ ] Integration tests

### Phase 6: Full-Merge Processing (Week 6-7)
- [ ] Implement `FullMergeProcessor`
- [ ] Implement context-aware transition algorithms
- [ ] Implement intelligent pause reduction
- [ ] Implement master processing chain
- [ ] End-to-end testing

### Phase 7: Integration (Week 7-8)
- [ ] Integrate with `VideoMerger`
- [ ] Integrate with `RecordingController` (optional live preview)
- [ ] Update `Project` model
- [ ] Create UI components for preset selection
- [ ] Create before/after preview UI
- [ ] User testing and refinement

### Phase 8: Polish & Optimization (Week 8-9)
- [ ] Performance optimization
- [ ] Error handling and recovery
- [ ] Logging and diagnostics
- [ ] Documentation
- [ ] Final testing

---

## Technical Considerations

### 1. DSP Library Choice

**Option A: AVAudioEngine (Apple Native)**
- ✅ Built-in, no dependencies
- ✅ Good performance on Apple hardware
- ✅ Real-time capable
- ❌ Limited advanced processing
- ❌ Moderate quality

**Option B: Third-Party (Superpowered, AudioKit)**
- ✅ Higher quality processing
- ✅ More advanced features
- ✅ Cross-platform (if needed)
- ❌ Additional dependency
- ❌ Licensing costs (Superpowered)

**Option C: Hybrid Approach** (Recommended)
- Use AVAudioEngine for basic processing (gate, EQ, compression)
- Use specialized algorithms for advanced features (noise reduction, reverb removal)
- Integrate AI-based processing for maximum quality (OpenAI, Dolby.io)

### 2. Performance & Memory

- Process audio in chunks (avoid loading entire file)
- Use background threads for processing
- Cache processed audio to avoid reprocessing
- Provide progress callbacks for long operations
- Memory-map large files when possible

### 3. Error Handling

```swift
enum AudioProcessingError: LocalizedError {
    case fileNotFound(URL)
    case invalidFormat(String)
    case processingFailed(processor: String, reason: String)
    case syncDriftDetected(offset: TimeInterval)
    case insufficientMemory
    case hardwareUnavailable

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Audio file not found: \(url.lastPathComponent)"
        case .invalidFormat(let format):
            return "Unsupported audio format: \(format)"
        case .processingFailed(let processor, let reason):
            return "Failed to process with \(processor): \(reason)"
        case .syncDriftDetected(let offset):
            return "Audio/video sync drift detected: \(offset)s"
        case .insufficientMemory:
            return "Not enough memory to process audio"
        case .hardwareUnavailable:
            return "Audio hardware unavailable"
        }
    }
}
```

### 4. Quality Metrics

Track and report quality metrics:

```swift
struct AudioQualityMetrics: Codable {
    // Input analysis
    var originalLoudness: Float        // LUFS
    var originalDynamicRange: Float    // dB
    var originalNoiseFloor: Float      // dB
    var originalPeakLevel: Float       // dBFS

    // Processing results
    var processedLoudness: Float
    var processedDynamicRange: Float
    var processedNoiseFloor: Float
    var processedPeakLevel: Float

    // Quality indicators
    var noiseReduction: Float          // dB reduction
    var clippingEvents: Int
    var silencePercentage: Float       // % of audio
    var processingTime: TimeInterval

    // Compliance
    var meetsLUFSTarget: Bool
    var meetsBroadcastStandards: Bool

    func generateReport() -> String {
        """
        Audio Processing Report
        ----------------------
        Input:
          - Loudness: \(originalLoudness) LUFS
          - Dynamic Range: \(originalDynamicRange) dB
          - Noise Floor: \(originalNoiseFloor) dB

        Output:
          - Loudness: \(processedLoudness) LUFS \(meetsLUFSTarget ? "✓" : "✗")
          - Dynamic Range: \(processedDynamicRange) dB
          - Noise Floor: \(processedNoiseFloor) dB
          - Noise Reduction: \(noiseReduction) dB

        Processing Time: \(processingTime)s
        """
    }
}
```

---

## Testing Strategy

### Unit Tests
- Test each processor independently with synthetic audio
- Test with various sample rates (44.1kHz, 48kHz)
- Test with mono and stereo audio
- Test edge cases (silence, clipping, extreme levels)

### Integration Tests
- Test complete processing chains
- Test preset application
- Test scene assembly with real takes
- Test sync compensation accuracy

### Quality Tests
- A/B comparison with professional tools (Audacity, Adobe Audition)
- Subjective listening tests with users
- Automated quality metrics validation
- Broadcast standards compliance testing

### Performance Tests
- Measure processing time for various audio lengths
- Memory usage profiling
- Concurrent processing stress tests
- Real-time processing capability tests

---

## Future Enhancements

### V2 Features
- AI-based noise profiling and removal
- Automatic preset selection based on audio analysis
- Voice cloning/enhancement (subtle)
- Multi-language optimization
- Adaptive loudness (scene-aware)
- Custom preset creation UI
- Batch processing for multiple projects
- Audio restoration for degraded recordings

### Advanced Features
- Machine learning-based audio quality prediction
- Automatic scene segmentation from audio
- Speaker diarization (multi-speaker scenes)
- Music ducking (if background music added)
- Acoustic environment matching across scenes
- Real-time collaboration (cloud processing)

---

## Notes & Considerations

1. **Latency**: Real-time processing adds latency - only use lightweight processing during recording
2. **Battery**: Heavy processing drains battery - warn users or process on AC power
3. **Storage**: Processed audio files require storage - implement cleanup/cache management
4. **Presets**: Allow users to create custom presets in future versions
5. **Undo**: Implement non-destructive processing - keep originals
6. **Preview**: Always show before/after for user approval
7. **Defaults**: Choose safe defaults that work for 80% of cases
8. **Education**: Provide tooltips/help for technical terms
9. **Accessibility**: Ensure UI is accessible for hearing-impaired users
10. **Compliance**: Respect audio format licensing (AAC, MP3, etc.)

---

## References & Resources

### Documentation
- [AVAudioEngine Documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [Core Audio Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/)
- [ITU BS.1770 (LUFS Standard)](https://www.itu.int/rec/R-REC-BS.1770/)
- [EBU R128 (Broadcast Loudness)](https://tech.ebu.ch/docs/r/r128.pdf)

### Tools for Reference
- iZotope RX (industry standard audio repair)
- Adobe Audition (audio editing)
- Auphonic (automatic audio post-production)
- Descript (AI-powered audio editing)

### DSP Libraries
- [AudioKit](https://audiokit.io/) - Open-source audio DSP
- [Superpowered](https://superpowered.com/) - Commercial audio engine
- [SoX](http://sox.sourceforge.net/) - Command-line audio processing

---

## End of Design Document

This document should be treated as a living specification. Update it as implementation progresses and requirements evolve.

**Last Updated**: 2025-01-30
**Version**: 1.0
**Author**: Design Team
