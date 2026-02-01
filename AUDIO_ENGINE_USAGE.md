# Audio Engine Usage Guide

Quick reference for using the ReTakeAi Audio Engine

---

## Basic Usage

### 1. Process Audio with Default Preset

```swift
import AVFoundation

// Get audio engine
let engine = ReTakeAudioEngine.shared

// Use default Studio Voice preset
let result = try await engine.processWithDefaults(audioURL: myAudioFileURL)

// Result contains processed audio URL
print("Processed audio: \(result.processedURL)")
```

### 2. Process with Custom Preset

```swift
// Select a preset
let preset = DefaultPresets.podcastPro  // or .clearNarration, .cinematic, etc.

// Process with progress tracking
let result = try await engine.process(
    audioURL: myAudioFileURL,
    preset: preset,
    progress: { progress in
        print("Processing: \(Int(progress * 100))%")
    }
)

print("Original duration: \(result.originalDuration.seconds)s")
print("Processed duration: \(result.processedDuration.seconds)s")
```

---

## Available Presets

### Scene Processing Presets (Pass 1)

| Preset | Best For | Processing Level |
|--------|----------|------------------|
| `DefaultPresets.studioVoice` | General recording, warm sound | Light |
| `DefaultPresets.podcastPro` | Podcasts, consistent levels | Heavy |
| `DefaultPresets.clearNarration` | Voiceover, maximum clarity | Heavy |
| `DefaultPresets.cinematic` | Film, theatrical tone | Light |
| `DefaultPresets.cleanNatural` | Authentic, minimal processing | Very Light |
| `DefaultPresets.radioVoice` | Radio, aggressive sound | Very Heavy |

### Merge Presets (Pass 2 - Assembly)

| Preset | Best For | Trimming |
|--------|----------|----------|
| `DefaultPresets.cohesiveMaster` | General use, smooth transitions | Moderate |
| `DefaultPresets.tightPunchy` | Fast-paced, dynamic content | Heavy |
| `DefaultPresets.cinematicFlow` | Preserve pauses, gentle flow | None |
| `DefaultPresets.podcastStandard` | Standard podcast workflow | Moderate |

---

## Custom Processing

### Create Custom Preset

```swift
let customPreset = AudioPreset(
    name: "My Custom Preset",
    description: "Optimized for my voice",
    category: .custom,
    processingChain: [
        ProcessorConfig(processorID: "gate", enabled: true, parameters: [
            "threshold": .float(-45),
            "ratio": .float(4.0)
        ]),
        ProcessorConfig(processorID: "noiseReduction", enabled: true, parameters: [
            "strength": .float(0.6)
        ]),
        ProcessorConfig(processorID: "compression", enabled: true, parameters: [
            "ratio": .float(3.0),
            "threshold": .float(-18),
            "knee": .string("soft")
        ]),
        ProcessorConfig(processorID: "normalization", enabled: true, parameters: [
            "target": .float(-16.0)
        ])
    ],
    targetLoudness: -16.0,
    preserveDynamics: true
)

// Use custom preset
let result = try await engine.process(
    audioURL: myAudioFileURL,
    preset: customPreset,
    progress: { _ in }
)
```

---

## Processor Parameters

### GateProcessor
```swift
ProcessorConfig(processorID: "gate", parameters: [
    "threshold": .float(-40.0),  // dB: -60 to 0
    "ratio": .float(4.0),        // 1.0 to 10.0
    "attack": .float(0.01),      // seconds
    "release": .float(0.1)       // seconds
])
```

### NoiseReductionProcessor
```swift
ProcessorConfig(processorID: "noiseReduction", parameters: [
    "strength": .float(0.5)      // 0.0 (none) to 1.0 (maximum)
])
```

### CompressionProcessor
```swift
ProcessorConfig(processorID: "compression", parameters: [
    "ratio": .float(4.0),        // 1.0 to 20.0
    "threshold": .float(-20.0),  // dB: -60 to 0
    "attack": .float(0.005),     // seconds
    "release": .float(0.1),      // seconds
    "makeupGain": .float(0.0),   // dB: -20 to +20
    "knee": .string("soft")      // "soft" or "hard"
])
```

### DeEsserProcessor
```swift
ProcessorConfig(processorID: "deEsser", parameters: [
    "threshold": .float(-20.0),  // dB: -30 to 0
    "frequency": .float(6000.0), // Hz: 4000 to 10000
    "ratio": .float(4.0)         // 2.0 to 8.0
])
```

### PopRemovalProcessor
```swift
ProcessorConfig(processorID: "popRemoval", parameters: [
    "sensitivity": .float(0.5)   // 0.0 (low) to 1.0 (high)
])
```

### NormalizationProcessor
```swift
ProcessorConfig(processorID: "normalization", parameters: [
    "target": .float(-16.0),     // dB LUFS: -24 to -12
    "peakLimit": .float(-1.0)    // dBFS: -3 to 0
])
```

### ClickRemovalProcessor
```swift
ProcessorConfig(processorID: "clickRemoval", parameters: [:])
// No parameters - automatic detection
```

---

## Analysis & Quality Metrics

### Analyze Audio Before Processing

```swift
// Create context
let audioFile = try AVAudioFile(forReading: myAudioFileURL)
let context = AudioProcessingContext(audioFile: audioFile)

// Analyze
let analyzer = AudioAnalyzer()
try await analyzer.analyze(audioFile: audioFile, context: context)

// Check results
print("Average Level: \(context.averageLevel ?? 0) dB")
print("Peak Level: \(context.peakLevel ?? 0) dB")
print("Noise Floor: \(context.noiseFloor ?? 0) dB")
print("Dynamic Range: \(context.dynamicRange ?? 0) dB")
print("Silence Ranges: \(context.silenceRanges?.count ?? 0)")
```

### Get Quality Metrics After Processing

```swift
let result = try await engine.process(audioURL: url, preset: preset, progress: { _ in })

// Decode metrics
if let metricsString = result.qualityMetrics,
   let metricsData = Data(base64Encoded: metricsString),
   let metrics = try? JSONDecoder().decode(AudioQualityMetrics.self, from: metricsData) {

    print(metrics.generateReport())

    // Individual metrics
    print("Original Loudness: \(metrics.originalLoudness) LUFS")
    print("Processed Loudness: \(metrics.processedLoudness) LUFS")
    print("Noise Reduction: \(metrics.noiseReduction) dB")
    print("Meets LUFS Target: \(metrics.meetsLUFSTarget)")
}
```

---

## Manual Processing Chain

### Build and Execute Chain Manually

```swift
// Create context
let audioFile = try AVAudioFile(forReading: myAudioFileURL)
let context = AudioProcessingContext(audioFile: audioFile)

// Build chain
let chain = AudioProcessingChain(context: context)
chain.addProcessor(GateProcessor())
chain.addProcessor(NoiseReductionProcessor())
chain.addProcessor(CompressionProcessor())
chain.addProcessor(NormalizationProcessor())

// Load buffer
let fileHandler = AudioFileHandler()
let buffer = try fileHandler.readBuffer(from: audioFile)

// Process
let configs = [
    ProcessorConfig(processorID: "gate", enabled: true, parameters: ["threshold": .float(-40.0)]),
    ProcessorConfig(processorID: "noiseReduction", enabled: true, parameters: ["strength": .float(0.5)]),
    ProcessorConfig(processorID: "compression", enabled: true, parameters: ["ratio": .float(3.0)]),
    ProcessorConfig(processorID: "normalization", enabled: true, parameters: ["target": .float(-16.0)])
]

let processedBuffer = try await chain.process(
    buffer: buffer,
    configs: configs,
    progress: { progress in
        print("Chain progress: \(Int(progress * 100))%")
    }
)

// Write output
let outputURL = URL(fileURLWithPath: "/path/to/output.m4a")
try fileHandler.writeBuffer(processedBuffer, to: outputURL)
```

---

## Integration with AppEnvironment

### Add to AppEnvironment

```swift
// In AppEnvironment.swift
class AppEnvironment {
    static let shared = AppEnvironment()

    // Existing services...
    lazy var projectStore = ProjectStore()
    lazy var sceneStore = SceneStore()
    lazy var takeStore = TakeStore()

    // NEW: Audio engine
    lazy var audioEngine = ReTakeAudioEngine.shared
}
```

### Use in ViewModel

```swift
@MainActor
@Observable
class ExportViewModel {
    var isProcessing = false
    var progress: Double = 0.0

    func processAudio(take: Take) async throws {
        isProcessing = true
        defer { isProcessing = false }

        let engine = AppEnvironment.shared.audioEngine
        let preset = DefaultPresets.studioVoice

        let result = try await engine.process(
            audioURL: take.fileURL,
            preset: preset,
            progress: { [weak self] progress in
                Task { @MainActor in
                    self?.progress = progress
                }
            }
        )

        // Update take with processed audio
        var updatedTake = take
        updatedTake.processedAudioURL = result.processedURL
        try AppEnvironment.shared.takeStore.save(updatedTake)
    }
}
```

---

## Error Handling

```swift
do {
    let result = try await engine.process(
        audioURL: myAudioFileURL,
        preset: preset,
        progress: { _ in }
    )
    print("Success: \(result.processedURL)")

} catch AudioProcessingError.fileNotFound(let url) {
    print("File not found: \(url)")

} catch AudioProcessingError.invalidFormat(let format) {
    print("Invalid format: \(format)")

} catch AudioProcessingError.processingFailed(let processor, let reason) {
    print("Processing failed at \(processor): \(reason)")

} catch AudioProcessingError.insufficientMemory {
    print("Not enough memory to process audio")

} catch {
    print("Unknown error: \(error)")
}
```

---

## Performance Tips

### 1. Use Appropriate Preset
- **Light processing**: `cleanNatural` or `studioVoice`
- **Heavy processing**: `podcastPro` or `clearNarration`

### 2. Process in Background
```swift
Task.detached(priority: .background) {
    let result = try await engine.process(...)

    await MainActor.run {
        // Update UI
    }
}
```

### 3. Cache Processed Audio
The engine automatically saves processed audio to:
```
Documents/ReTakeAi/ProcessedAudio/
```

### 4. Monitor Progress
Always provide a progress callback to keep UI responsive:
```swift
let result = try await engine.process(
    audioURL: url,
    preset: preset,
    progress: { progress in
        DispatchQueue.main.async {
            self.progressBar.progress = Float(progress)
        }
    }
)
```

---

## Testing

### Run Unit Tests in Xcode

1. Open `ReTakeAi.xcodeproj`
2. Press `Cmd+U` or Product → Test
3. View results in Test Navigator (Cmd+6)

### Test Individual Processor

```swift
let processor = GateProcessor()
let context = AudioProcessingContext()

let testBuffer = createTestBuffer()  // Your test audio
let config = ProcessorConfig(processorID: "gate", parameters: [...])

let processed = try await processor.process(
    buffer: testBuffer,
    config: config,
    context: context
)

// Verify results
XCTAssertNotNil(processed)
```

---

## Common Issues & Solutions

### Issue: Audio sounds muffled after processing
**Solution**: Reduce noise reduction strength or de-essing threshold

### Issue: Audio clips/distorts
**Solution**: Lower compression ratio or increase normalization peakLimit

### Issue: Processing is slow
**Solution**: Use lighter preset or process in background thread

### Issue: Not enough noise reduction
**Solution**: Increase noise reduction strength or lower gate threshold

### Issue: Voice sounds unnatural
**Solution**: Use `cleanNatural` preset or reduce processing parameters

---

## Next Steps

1. **Integrate**: Add files to Xcode project
2. **Test**: Run with real recordings
3. **Tune**: Adjust preset parameters based on results
4. **Extend**: Add Phase 3 processors (EQ, Voice Enhancement, etc.)
5. **Optimize**: Profile and optimize hot paths

---

**Questions?** Check `AUDIO_ENGINE_DESIGN.md` for detailed design docs.
