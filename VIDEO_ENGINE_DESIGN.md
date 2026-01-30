# ReTakeAi Video Processing Engine - Design Document

## Overview

This document outlines the design and implementation plan for ReTakeAi's production-grade video processing pipeline. The engine handles compression, color grading, transitions, and quality enhancements in a modular, preset-based architecture that integrates seamlessly with the audio processing engine.

## Goals & Requirements

### Must-Have Features (Priority 1)
- **Video Compression** - Intelligent encoding with quality/size balance
- **Color Grading** - Professional color correction and cinematic looks
- **Scene Transitions** - Smooth, configurable transitions between scenes
- **Aspect Ratio Handling** - Convert and maintain proper framing
- **Quality Optimization** - Automatic exposure, sharpness adjustments

### Must-Have Features (Priority 2)
- **Video Stabilization** - Smooth handheld footage
- **Denoise** - Reduce low-light grain and noise
- **LUT Support** - Apply custom color lookup tables
- **Speed Control** - Slow motion, time-lapse per scene
- **Text Overlays** - Titles, captions, watermarks

### Advanced Features (Priority 3)
- **Dynamic Color Matching** - Consistent look across scenes
- **Auto-Exposure Balancing** - Match brightness across scenes
- **Motion Blur** - Smooth speed changes
- **HDR Processing** - High dynamic range optimization
- **AI-Based Enhancement** - ML-powered quality improvements

### Core Requirements
1. **Preset-Based System** - Multiple video style presets
2. **Modular Architecture** - Easy to add/remove processors
3. **Two-Pass System** - Scene-level + assembly processing (like audio)
4. **Perfect A/V Sync** - Must work with audio processing pipeline
5. **Performance** - Efficient rendering with progress tracking
6. **Quality Control** - Configurable quality/speed tradeoffs

---

## Architecture Overview

### Two-Pass Processing System

Similar to the audio engine, video processing follows a two-pass approach:

#### Pass 1: Scene-Level Processing (Individual Takes)
- Color grade each take independently
- Apply quality enhancements (denoise, sharpen, stabilization)
- Preserve original timing
- Output: Processed individual takes

#### Pass 2: Assembly & Master Processing (Complete Video)
- Apply transitions between scenes
- Color match across scenes for consistency
- Master color grading pass
- Final compression and encoding
- Sync with processed audio
- Output: Professional final video

---

## Folder Structure

```
ReTakeAi/Core/Video/
├── VideoEngine/
│   ├── ReTakeVideoEngine.swift          // Main orchestrator for per-take processing
│   ├── VideoProcessingChain.swift        // Pipeline manager for processor sequence
│   ├── VideoProcessingContext.swift      // Shared state/buffers between processors
│   └── VideoRenderEngine.swift           // Handles actual rendering/encoding
│
├── Processors/
│   ├── VideoProcessorProtocol.swift      // Base interface all processors implement
│   │
│   ├── ColorGrading/
│   │   ├── ColorGraderProcessor.swift    // Main color grading
│   │   ├── LUTProcessor.swift            // LUT application
│   │   ├── ColorCorrectionProcessor.swift // Basic corrections
│   │   ├── WhiteBalanceProcessor.swift   // Temperature/tint
│   │   └── ColorMatcherProcessor.swift   // Scene-to-scene matching
│   │
│   ├── QualityEnhancement/
│   │   ├── DenoiseProcessor.swift        // Noise reduction
│   │   ├── SharpenProcessor.swift        // Sharpness enhancement
│   │   ├── StabilizationProcessor.swift  // Video stabilization
│   │   ├── ExposureProcessor.swift       // Brightness/contrast
│   │   └── DynamicRangeProcessor.swift   // HDR optimization
│   │
│   ├── Transform/
│   │   ├── AspectRatioProcessor.swift    // Aspect conversion
│   │   ├── CropProcessor.swift           // Crop and zoom
│   │   ├── RotationProcessor.swift       // Rotation and flip
│   │   ├── ScaleProcessor.swift          // Resolution scaling
│   │   └── SpeedProcessor.swift          // Time remapping
│   │
│   ├── Composition/
│   │   ├── TransitionProcessor.swift     // Apply transitions
│   │   ├── OverlayProcessor.swift        // Text, graphics overlays
│   │   ├── WatermarkProcessor.swift      // Watermark application
│   │   └── TitleProcessor.swift          // Title cards
│   │
│   └── Encoding/
│       ├── CompressionProcessor.swift    // Video compression
│       ├── CodecSelector.swift           // Optimal codec selection
│       └── BitrateOptimizer.swift        // Quality/size balance
│
├── Assembly/
│   ├── SceneVideoAssembler.swift         // Main orchestrator for merging
│   ├── TransitionEngine.swift            // Smart transition application
│   ├── ColorMatchingEngine.swift         // Cross-scene color matching
│   ├── MasterGradingEngine.swift         // Final color pass
│   └── AVSyncManager.swift               // Audio/video synchronization
│
├── Presets/
│   ├── VideoPreset.swift                 // Per-take processing preset
│   ├── MasterPreset.swift                // Assembly/merge preset
│   ├── TransitionPreset.swift            // Transition style definitions
│   ├── PresetManager.swift               // Load/save/manage presets
│   └── DefaultPresets.swift              // Built-in preset definitions
│
├── Models/
│   ├── VideoProcessingConfig.swift       // Per-processor configuration
│   ├── ProcessorParameters.swift         // Typed parameter definitions
│   ├── VideoQualityMetrics.swift         // Analysis results
│   ├── ColorGradingConfig.swift          // Color grading settings
│   ├── TransitionConfig.swift            // Transition configuration
│   ├── CompressionConfig.swift           // Encoding settings
│   └── SceneAssemblyConfig.swift         // Assembly configuration
│
├── Analysis/
│   ├── VideoAnalyzer.swift               // Pre-analysis (exposure, color, motion)
│   ├── ColorAnalyzer.swift               // Color distribution analysis
│   ├── MotionAnalyzer.swift              // Motion and stability analysis
│   └── QualityAnalyzer.swift             // Quality metrics calculation
│
└── Utilities/
    ├── LUTLoader.swift                   // Load .cube, .3dl LUT files
    ├── ColorSpaceConverter.swift         // Color space transformations
    ├── FrameExtractor.swift              // Extract frames for processing
    └── MetadataExtractor.swift           // Video metadata parsing
```

---

## Processing Order

### Pass 1: Per-Take/Scene Processing

```
1. VideoAnalyzer (Pre-scan)
   ↓ [Analyze exposure, color balance, motion, quality metrics]

2. StabilizationProcessor (if enabled)
   ↓ [Smooth camera motion - do this first before other processing]

3. DenoiseProcessor
   ↓ [Remove grain and noise - especially for low-light footage]

4. ExposureProcessor
   ↓ [Correct brightness, contrast, shadows, highlights]

5. WhiteBalanceProcessor
   ↓ [Fix color temperature and tint]

6. ColorCorrectionProcessor
   ↓ [Basic color adjustments - saturation, vibrance, hue]

7. LUTProcessor / ColorGraderProcessor
   ↓ [Apply cinematic look or LUT]

8. DynamicRangeProcessor
   ↓ [Optimize for HDR or SDR]

9. SharpenProcessor
   ↓ [Enhance details - ALWAYS after grading]

10. AspectRatioProcessor (if needed)
   ↓ [Convert aspect ratio with smart crop/letterbox]
```

**Key**: Scene-level processing focuses on making each take look its best independently.

### Pass 2: Assembly & Master Processing

```
1. Load all processed takes from Pass 1

2. ANALYZE COMPLETE VIDEO (before assembly)
   - Overall color distribution across scenes
   - Exposure variations scene-to-scene
   - Motion characteristics
   - Quality metrics

3. COLOR MATCHING (Consistency across scenes)
   - Analyze reference scene (or use first scene)
   - Match color balance across all scenes
   - Balance exposure levels
   - Smooth color transitions

4. SCENE ASSEMBLY with Transitions
   For each scene boundary:
     - Determine transition type (from config)
     - Calculate optimal transition duration
     - Apply transition with frame blending
     - Ensure smooth visual flow

5. MASTER COLOR GRADING (Optional)
   - Global color pass for final look
   - Fine-tune overall tone
   - Apply master LUT if specified
   - Adjust for target platform (web, broadcast, cinema)

6. COMPOSITION
   - Add titles/text overlays
   - Apply watermarks
   - Insert title cards

7. SYNC WITH AUDIO
   - Combine with processed audio from AudioEngine
   - Verify perfect sync (no drift)
   - Apply volume visualization (optional)

8. FINAL ENCODING
   - Select optimal codec (H.264, HEVC, ProRes)
   - Apply compression with quality preset
   - Optimize bitrate for target platform
   - Generate multiple resolutions (if needed)

9. QUALITY CHECK
   - Verify no frame drops
   - Check A/V sync accuracy
   - Analyze final quality metrics
   - Generate quality report
```

---

## Key Models & Configurations

### 1. VideoProcessorProtocol

```swift
protocol VideoProcessorProtocol {
    /// Unique identifier for the processor type
    var processorID: String { get }

    /// Human-readable name
    var displayName: String { get }

    /// Process video asset with given configuration
    func process(
        asset: AVAsset,
        config: ProcessorConfig,
        context: VideoProcessingContext,
        progress: @escaping (Double) -> Void
    ) async throws -> AVAsset

    /// Whether this processor is GPU-accelerated
    var usesGPU: Bool { get }

    /// Estimated processing time multiplier (1.0 = realtime)
    var performanceMultiplier: Double { get }

    /// Whether this processor modifies timing/duration
    var affectsTiming: Bool { get }

    /// Optional pre-analysis step
    func analyze(asset: AVAsset) async -> ProcessorAnalysis?
}
```

### 2. ColorGradingConfig

```swift
struct ColorGradingConfig: Codable {
    // Basic adjustments
    var exposure: Float = 0.0           // -2.0 to +2.0 stops
    var contrast: Float = 1.0           // 0.5 to 2.0
    var highlights: Float = 0.0         // -100 to +100
    var shadows: Float = 0.0            // -100 to +100
    var whites: Float = 0.0             // -100 to +100
    var blacks: Float = 0.0             // -100 to +100

    // Color adjustments
    var temperature: Float = 0.0        // -100 to +100 (cool to warm)
    var tint: Float = 0.0               // -100 to +100 (green to magenta)
    var saturation: Float = 1.0         // 0.0 to 2.0
    var vibrance: Float = 0.0           // -100 to +100

    // Advanced
    var hueShift: Float = 0.0           // -180 to +180 degrees
    var lutName: String?                 // Optional LUT file
    var lookPreset: LookPreset?         // Cinematic look preset

    // Per-color channel adjustments
    var redAdjustment: ColorChannelAdjustment?
    var greenAdjustment: ColorChannelAdjustment?
    var blueAdjustment: ColorChannelAdjustment?
}

struct ColorChannelAdjustment: Codable {
    var gain: Float = 1.0               // 0.0 to 2.0
    var gamma: Float = 1.0              // 0.5 to 2.0
    var lift: Float = 0.0               // -1.0 to 1.0
}

enum LookPreset: String, Codable {
    case natural        // Minimal grading
    case cinematic      // Film-like look
    case vibrant        // Punchy colors
    case muted          // Desaturated, moody
    case warmGolden     // Warm tones, golden hour
    case coolCinematic  // Cool, teal/orange
    case vintage        // Retro film look
    case blackAndWhite  // Monochrome
    case custom         // User-defined
}
```

### 3. TransitionConfig

```swift
struct TransitionConfig: Codable {
    // Transition type
    var type: TransitionType = .crossfade
    var duration: TimeInterval = 0.5

    // Transition parameters
    var easing: EasingFunction = .easeInOut
    var direction: TransitionDirection? // For wipes, slides
    var color: CodableColor?            // For fade to color

    // Per-scene overrides
    var sceneOverrides: [UUID: SceneTransitionOverride]?

    // Smart behavior
    var autoAdjustDuration: Bool = true  // Based on scene content
    var matchMotion: Bool = false        // Motion-matched transitions
}

enum TransitionType: String, Codable {
    case cut                // No transition
    case crossfade         // Standard dissolve
    case fadeToBlack       // Fade out, fade in
    case fadeToWhite       // Fade out, fade in (white)
    case wipeLeft          // Wipe left to right
    case wipeRight         // Wipe right to left
    case wipeUp            // Wipe up
    case wipeDown          // Wipe down
    case slideLeft         // Slide transition left
    case slideRight        // Slide transition right
    case zoom              // Zoom transition
    case blur              // Blur transition
    case custom            // Custom Core Image filter
}

enum EasingFunction: String, Codable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case easeInQuad
    case easeOutQuad
    case easeInCubic
    case easeOutCubic
}

enum TransitionDirection: String, Codable {
    case leftToRight
    case rightToLeft
    case topToBottom
    case bottomToTop
}

struct SceneTransitionOverride: Codable {
    var fromSceneID: UUID
    var toSceneID: UUID
    var transitionType: TransitionType?
    var duration: TimeInterval?
}
```

### 4. CompressionConfig

```swift
struct CompressionConfig: Codable {
    // Quality preset
    var quality: CompressionQuality = .high

    // Codec selection
    var codec: VideoCodec = .h264
    var profile: String?  // e.g., "High", "Main", "Baseline" for H.264

    // Bitrate control
    var bitrateMode: BitrateMode = .variableBitrate
    var targetBitrate: Int?  // bps (e.g., 5_000_000 = 5 Mbps)
    var maxBitrate: Int?

    // Resolution
    var outputResolution: OutputResolution = .original
    var maxWidth: Int?
    var maxHeight: Int?

    // Frame rate
    var frameRate: Int = 30  // fps
    var preserveOriginalFrameRate: Bool = true

    // Advanced
    var keyFrameInterval: Int = 30  // GOP size
    var enableHardwareAcceleration: Bool = true
    var passes: Int = 1  // 1-pass or 2-pass encoding
}

enum CompressionQuality: String, Codable {
    case low        // Smaller file, lower quality
    case medium     // Balanced
    case high       // Larger file, better quality
    case maximum    // Near-lossless
    case custom     // User-defined bitrate
}

enum VideoCodec: String, Codable {
    case h264       // Most compatible (H.264/AVC)
    case hevc       // Better compression (H.265/HEVC)
    case prores     // Production quality (large files)
    case vp9        // Google's codec
    case av1        // Future-proof, best compression
}

enum BitrateMode: String, Codable {
    case constantBitrate    // CBR - consistent size
    case variableBitrate    // VBR - better quality
    case constrainedVBR     // CVBR - VBR with max limit
}

enum OutputResolution: String, Codable {
    case original       // Keep source resolution
    case sd480p        // 640x480
    case hd720p        // 1280x720
    case hd1080p       // 1920x1080
    case uhd4k         // 3840x2160
    case custom        // User-defined
}
```

### 5. VideoPreset (Per-Take Processing)

```swift
struct VideoPreset: Codable, Identifiable {
    var id: UUID
    var name: String
    var description: String
    var category: PresetCategory

    // Processing chain (order matters!)
    var processingChain: [ProcessorConfig]

    // Color grading configuration
    var colorGrading: ColorGradingConfig?

    // Quality enhancements
    var enableStabilization: Bool = false
    var enableDenoise: Bool = false
    var enableSharpen: Bool = false
    var enableAutoExposure: Bool = false

    // Performance
    var prioritizeSpeed: Bool = false  // vs quality
}

enum PresetCategory: String, Codable {
    case professional
    case social
    case broadcast
    case cinematic
    case vintage
    case custom
}
```

### 6. MasterPreset (Assembly Processing)

```swift
struct MasterPreset: Codable, Identifiable {
    var id: UUID
    var name: String
    var description: String

    // Assembly configuration
    var transitionConfig: TransitionConfig
    var compressionConfig: CompressionConfig

    // Color matching
    var enableColorMatching: Bool = true
    var colorMatchingStrategy: ColorMatchingStrategy = .autoBalance

    // Master grading
    var masterGrading: ColorGradingConfig?
    var masterLUT: String?  // Applied to entire video

    // Composition
    var titleCard: TitleCardConfig?
    var watermark: WatermarkConfig?
    var endCard: EndCardConfig?

    // Output settings
    var outputFormat: OutputFormat = .mp4
    var multipleResolutions: [OutputResolution]?  // Generate multiple sizes
}

enum ColorMatchingStrategy: String, Codable {
    case none               // No matching
    case autoBalance        // Auto-balance exposure and color
    case matchToFirst       // Match all to first scene
    case matchToReference   // Match all to specified scene
    case smoothTransitions  // Gradual color shifts
}

enum OutputFormat: String, Codable {
    case mp4        // Most common
    case mov        // QuickTime
    case m4v        // iTunes compatible
    case webm       // Web optimized
}
```

### 7. SceneAssemblyConfig

```swift
struct SceneAssemblyConfig: Codable {
    // Transition configuration
    var transitionConfig: TransitionConfig

    // Color matching
    var colorMatchingStrategy: ColorMatchingStrategy
    var referenceSceneID: UUID?  // For matchToReference strategy

    // Master processing
    var enableMasterGrading: Bool = true
    var masterGradingPreset: String = "Balanced"

    // Composition elements
    var addTitleCard: Bool = false
    var addWatermark: Bool = false
    var addEndCard: Bool = false

    // Quality control
    var verifySync: Bool = true
    var generatePreview: Bool = false  // Low-res preview first
}
```

### 8. Quality Enhancement Configs

```swift
struct StabilizationConfig: Codable {
    var strength: Float = 0.7           // 0.0 to 1.0
    var cropAmount: Float = 0.1         // 0.0 to 0.2 (crop for stabilization)
    var smoothing: Float = 0.8          // 0.0 to 1.0
    var method: StabilizationMethod = .gyro  // Use gyro data if available
}

enum StabilizationMethod: String, Codable {
    case gyro       // Use device motion data (best)
    case optical    // Vision-based tracking
    case hybrid     // Both
}

struct DenoiseConfig: Codable {
    var strength: Float = 0.5           // 0.0 to 1.0
    var temporal: Bool = true           // Multi-frame denoising
    var preserveDetail: Bool = true     // Balance noise vs sharpness
}

struct SharpenConfig: Codable {
    var amount: Float = 0.3             // 0.0 to 1.0
    var radius: Float = 1.0             // 0.5 to 3.0
    var threshold: Float = 0.0          // 0.0 to 1.0 (avoid halos)
    var maskLuminance: Bool = true      // Sharpen detail, not noise
}
```

---

## Smart Features & Algorithms

### 1. Intelligent Color Matching Across Scenes

```swift
class ColorMatchingEngine {
    /// Match colors across all scenes for consistency
    func matchScenes(
        scenes: [ProcessedVideoScene],
        strategy: ColorMatchingStrategy
    ) async throws -> [ProcessedVideoScene] {

        switch strategy {
        case .autoBalance:
            // Analyze all scenes
            let colorProfiles = scenes.map { analyzeColorProfile($0) }
            let averageProfile = calculateAverageProfile(colorProfiles)

            // Balance each scene toward average
            return scenes.map { scene in
                adjustToProfile(scene, target: averageProfile)
            }

        case .matchToFirst:
            // Use first scene as reference
            let referenceProfile = analyzeColorProfile(scenes[0])

            return scenes.map { scene in
                matchToReference(scene, reference: referenceProfile)
            }

        case .smoothTransitions:
            // Gradual color shifts between scenes
            var matched = [ProcessedVideoScene]()
            for i in 0..<scenes.count {
                if i == 0 {
                    matched.append(scenes[i])
                } else {
                    // Blend color profile with previous scene
                    let blended = blendColorProfiles(
                        from: matched[i-1],
                        to: scenes[i],
                        ratio: 0.3  // 30% influence from previous
                    )
                    matched.append(blended)
                }
            }
            return matched
        }
    }

    private func analyzeColorProfile(_ scene: ProcessedVideoScene) -> ColorProfile {
        // Extract representative frames
        let frames = extractKeyFrames(scene, count: 5)

        // Analyze color distribution
        let avgBrightness = frames.map { $0.brightness }.average()
        let avgContrast = frames.map { $0.contrast }.average()
        let colorBalance = analyzeColorBalance(frames)
        let saturation = frames.map { $0.saturation }.average()

        return ColorProfile(
            brightness: avgBrightness,
            contrast: avgContrast,
            colorBalance: colorBalance,
            saturation: saturation
        )
    }
}
```

### 2. Smart Transition Selection

```swift
class TransitionEngine {
    /// Automatically select best transition based on scene content
    func selectSmartTransition(
        fromScene: ProcessedVideoScene,
        toScene: ProcessedVideoScene
    ) -> TransitionType {

        // Analyze motion at scene boundaries
        let fromMotion = analyzeMotion(scene: fromScene, atEnd: true)
        let toMotion = analyzeMotion(scene: toScene, atStart: true)

        // Analyze color difference
        let colorDiff = calculateColorDifference(fromScene, toScene)

        // Decision logic
        if colorDiff < 0.1 {
            // Very similar colors - use cut for speed
            return .cut
        } else if fromMotion.speed > 0.5 || toMotion.speed > 0.5 {
            // High motion - use quick crossfade
            return .crossfade  // 0.2s
        } else if colorDiff > 0.6 {
            // Very different colors - use fade to black
            return .fadeToBlack
        } else {
            // Standard case - crossfade
            return .crossfade  // 0.5s
        }
    }

    /// Apply transition with frame-accurate blending
    func applyTransition(
        from: AVAsset,
        to: AVAsset,
        type: TransitionType,
        duration: TimeInterval
    ) async throws -> AVComposition {

        let composition = AVMutableComposition()

        // Add video tracks
        guard let fromTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let toTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoProcessingError.compositionFailed
        }

        // Insert clips with overlap for transition
        let fromDuration = from.duration
        let transitionStart = CMTimeSubtract(
            fromDuration,
            CMTime(seconds: duration, preferredTimescale: 600)
        )

        try fromTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: fromDuration),
            of: from.tracks(withMediaType: .video)[0],
            at: .zero
        )

        try toTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: to.duration),
            of: to.tracks(withMediaType: .video)[0],
            at: transitionStart
        )

        // Apply transition effect using Core Image
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = TransitionCompositor.self

        // Configure transition instruction
        let instruction = TransitionInstruction(
            type: type,
            duration: duration,
            timeRange: CMTimeRange(
                start: transitionStart,
                duration: CMTime(seconds: duration, preferredTimescale: 600)
            )
        )
        videoComposition.instructions = [instruction]

        return composition
    }
}
```

### 3. GPU-Accelerated Processing with Metal

```swift
class MetalVideoProcessor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    /// Apply color grading using Metal compute shader
    func applyColorGrading(
        to texture: MTLTexture,
        config: ColorGradingConfig
    ) throws -> MTLTexture {

        // Create output texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            throw VideoProcessingError.metalResourceCreation
        }

        // Create compute pipeline
        guard let function = library.makeFunction(name: "colorGrading"),
              let pipeline = try? device.makeComputePipelineState(function: function) else {
            throw VideoProcessingError.pipelineCreation
        }

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw VideoProcessingError.commandBufferCreation
        }

        // Set parameters
        var params = ColorGradingParams(from: config)
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<ColorGradingParams>.stride, index: 0)

        // Dispatch threads
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (texture.width + 15) / 16,
            height: (texture.height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return outputTexture
    }
}
```

### 4. Adaptive Bitrate Optimization

```swift
class BitrateOptimizer {
    /// Calculate optimal bitrate based on content complexity
    func optimizeBitrate(
        for asset: AVAsset,
        targetQuality: CompressionQuality,
        targetResolution: CGSize
    ) async -> Int {

        // Analyze video complexity
        let complexity = await analyzeComplexity(asset)

        // Base bitrate for resolution (rule of thumb)
        let pixelCount = targetResolution.width * targetResolution.height
        var baseBitrate: Int

        switch targetQuality {
        case .low:
            baseBitrate = Int(pixelCount * 0.1)  // 0.1 bits per pixel
        case .medium:
            baseBitrate = Int(pixelCount * 0.2)
        case .high:
            baseBitrate = Int(pixelCount * 0.3)
        case .maximum:
            baseBitrate = Int(pixelCount * 0.5)
        case .custom:
            return targetBitrate ?? baseBitrate
        }

        // Adjust based on complexity
        let complexityMultiplier = 0.5 + (complexity.overall * 0.5)  // 0.5x to 1.0x
        let optimizedBitrate = Int(Double(baseBitrate) * complexityMultiplier)

        // Clamp to reasonable limits
        let minBitrate = 500_000   // 500 kbps
        let maxBitrate = 50_000_000 // 50 Mbps
        return max(minBitrate, min(maxBitrate, optimizedBitrate))
    }

    private func analyzeComplexity(_ asset: AVAsset) async -> VideoComplexity {
        // Sample frames throughout video
        let frames = await extractSampleFrames(asset, count: 20)

        // Analyze spatial complexity (detail, textures)
        let spatialComplexity = frames.map { analyzeSpatialComplexity($0) }.average()

        // Analyze temporal complexity (motion)
        let temporalComplexity = analyzeMotionBetweenFrames(frames)

        // Analyze color complexity
        let colorComplexity = frames.map { analyzeColorRange($0) }.average()

        return VideoComplexity(
            spatial: spatialComplexity,
            temporal: temporalComplexity,
            color: colorComplexity
        )
    }
}
```

---

## Built-in Presets

### Scene Processing Presets (Pass 1)

#### 1. Natural & Clean
```swift
VideoPreset(
    name: "Natural & Clean",
    description: "Minimal processing, true-to-life colors",
    processingChain: [
        .autoExposure(subtle: true),
        .whiteBalance(auto: true),
        .colorGrading(preset: .natural),
        .sharpen(amount: 0.2)
    ],
    colorGrading: ColorGradingConfig(
        exposure: 0.0,
        contrast: 1.05,
        saturation: 1.0,
        lookPreset: .natural
    )
)
```

#### 2. Cinematic Pro
```swift
VideoPreset(
    name: "Cinematic Pro",
    description: "Film-like look with rich colors",
    processingChain: [
        .denoise(strength: 0.3),
        .autoExposure(subtle: true),
        .colorGrading(preset: .cinematic),
        .sharpen(amount: 0.4)
    ],
    colorGrading: ColorGradingConfig(
        exposure: -0.1,
        contrast: 1.15,
        highlights: -10,
        shadows: +15,
        saturation: 0.9,
        vibrance: +20,
        lookPreset: .cinematic,
        lutName: "Cinematic_Teal_Orange.cube"
    )
)
```

#### 3. Vibrant Social
```swift
VideoPreset(
    name: "Vibrant Social",
    description: "Punchy colors for social media",
    processingChain: [
        .autoExposure(subtle: false),
        .colorGrading(preset: .vibrant),
        .sharpen(amount: 0.5)
    ],
    colorGrading: ColorGradingConfig(
        exposure: +0.2,
        contrast: 1.2,
        shadows: +20,
        saturation: 1.3,
        vibrance: +40,
        lookPreset: .vibrant
    )
)
```

#### 4. Muted Aesthetic
```swift
VideoPreset(
    name: "Muted Aesthetic",
    description: "Desaturated, moody look",
    processingChain: [
        .denoise(strength: 0.2),
        .colorGrading(preset: .muted),
        .sharpen(amount: 0.3)
    ],
    colorGrading: ColorGradingConfig(
        exposure: -0.1,
        contrast: 0.95,
        highlights: -15,
        blacks: +10,
        saturation: 0.7,
        vibrance: -20,
        lookPreset: .muted
    )
)
```

#### 5. Warm Golden Hour
```swift
VideoPreset(
    name: "Warm Golden Hour",
    description: "Warm, golden tones",
    processingChain: [
        .colorGrading(preset: .warmGolden),
        .sharpen(amount: 0.3)
    ],
    colorGrading: ColorGradingConfig(
        exposure: +0.1,
        contrast: 1.1,
        temperature: +30,
        saturation: 1.1,
        lookPreset: .warmGolden
    )
)
```

#### 6. Broadcast Standard
```swift
VideoPreset(
    name: "Broadcast Standard",
    description: "Professional broadcast quality",
    processingChain: [
        .denoise(strength: 0.4),
        .stabilization(strength: 0.7),
        .autoExposure(subtle: true),
        .colorGrading(preset: .natural),
        .sharpen(amount: 0.4)
    ],
    colorGrading: ColorGradingConfig(
        exposure: 0.0,
        contrast: 1.1,
        saturation: 1.05,
        lookPreset: .natural
    ),
    enableStabilization: true,
    enableDenoise: true
)
```

### Master Processing Presets (Pass 2)

#### 1. Seamless Professional (Default)
```swift
MasterPreset(
    name: "Seamless Professional",
    description: "Smooth transitions, consistent look",
    transitionConfig: TransitionConfig(
        type: .crossfade,
        duration: 0.5,
        autoAdjustDuration: true
    ),
    compressionConfig: CompressionConfig(
        quality: .high,
        codec: .h264,
        outputResolution: .hd1080p
    ),
    enableColorMatching: true,
    colorMatchingStrategy: .autoBalance
)
```

#### 2. Fast Cut Style
```swift
MasterPreset(
    name: "Fast Cut Style",
    description: "Quick cuts, dynamic pacing",
    transitionConfig: TransitionConfig(
        type: .cut,
        duration: 0.0
    ),
    compressionConfig: CompressionConfig(
        quality: .high,
        codec: .h264,
        outputResolution: .hd1080p
    ),
    enableColorMatching: true,
    colorMatchingStrategy: .smoothTransitions
)
```

#### 3. Cinematic Flow
```swift
MasterPreset(
    name: "Cinematic Flow",
    description: "Elegant transitions, film-like",
    transitionConfig: TransitionConfig(
        type: .fadeToBlack,
        duration: 1.0
    ),
    compressionConfig: CompressionConfig(
        quality: .maximum,
        codec: .hevc,
        outputResolution: .uhd4k
    ),
    enableColorMatching: true,
    colorMatchingStrategy: .matchToFirst,
    masterGrading: ColorGradingConfig(
        contrast: 1.1,
        saturation: 0.95,
        lookPreset: .cinematic
    ),
    masterLUT: "Film_Look.cube"
)
```

#### 4. Social Media Optimized
```swift
MasterPreset(
    name: "Social Media Optimized",
    description: "Optimized for Instagram, TikTok",
    transitionConfig: TransitionConfig(
        type: .crossfade,
        duration: 0.3
    ),
    compressionConfig: CompressionConfig(
        quality: .high,
        codec: .h264,
        outputResolution: .hd1080p,
        targetBitrate: 8_000_000,  // 8 Mbps
        frameRate: 30
    ),
    enableColorMatching: true,
    colorMatchingStrategy: .autoBalance,
    multipleResolutions: [.hd1080p, .hd720p]  // Generate both
)
```

#### 5. Broadcast Quality
```swift
MasterPreset(
    name: "Broadcast Quality",
    description: "Professional broadcast standards",
    transitionConfig: TransitionConfig(
        type: .crossfade,
        duration: 0.5
    ),
    compressionConfig: CompressionConfig(
        quality: .maximum,
        codec: .prores,
        outputResolution: .hd1080p,
        frameRate: 30
    ),
    enableColorMatching: true,
    colorMatchingStrategy: .matchToReference
)
```

---

## Integration with Existing Code

### 1. Integration with VideoMerger & AudioEngine

```swift
class UnifiedMediaProcessor {
    let videoEngine = ReTakeVideoEngine.shared
    let audioEngine = ReTakeAudioEngine.shared
    let videoAssembler = SceneVideoAssembler.shared
    let audioAssembler = SceneAudioAssembler.shared

    func processComplete(
        project: Project,
        scenes: [VideoScene],
        videoPreset: VideoPreset,
        audioPreset: AudioPreset,
        masterPreset: MasterPreset,
        audioMergePreset: MergePreset
    ) async throws -> URL {

        // PASS 1A: Process each video take
        var processedVideoTakes: [UUID: URL] = [:]
        for scene in scenes {
            guard let selectedTakeID = scene.selectedTakeID,
                  let take = getTake(selectedTakeID) else { continue }

            let processedVideo = try await videoEngine.process(
                videoURL: take.fileURL,
                preset: videoPreset
            )
            processedVideoTakes[take.id] = processedVideo
        }

        // PASS 1B: Process each audio take (parallel with video)
        var processedAudioTakes: [UUID: URL] = [:]
        for scene in scenes {
            guard let selectedTakeID = scene.selectedTakeID,
                  let take = getTake(selectedTakeID) else { continue }

            let processedAudio = try await audioEngine.process(
                audioURL: take.fileURL,  // Extract audio from video
                preset: audioPreset
            )
            processedAudioTakes[take.id] = processedAudio
        }

        // PASS 2A: Assemble video with transitions and color matching
        let assembledVideo = try await videoAssembler.assemble(
            videoTakes: processedVideoTakes,
            sceneOrder: scenes.map { $0.id },
            masterPreset: masterPreset
        )

        // PASS 2B: Assemble audio with trimming and transitions
        let assembledAudio = try await audioAssembler.assemble(
            audioTakes: processedAudioTakes,
            sceneOrder: scenes.map { $0.id },
            mergePreset: audioMergePreset
        )

        // PASS 3: Combine processed video + audio with perfect sync
        let finalURL = try await combineAudioVideo(
            video: assembledVideo.url,
            audio: assembledAudio.url,
            verifySync: true,
            syncCompensation: assembledAudio.syncCompensation
        )

        // PASS 4: Final encoding with compression settings
        let encodedURL = try await encodeWithCompression(
            sourceURL: finalURL,
            compressionConfig: masterPreset.compressionConfig
        )

        return encodedURL
    }
}
```

### 2. Integration with RecordingController

Add real-time preview of video processing:

```swift
class RecordingController {
    var liveVideoProcessing: Bool = false
    var previewVideoPreset: VideoPreset?

    func setupVideoPreview() {
        // Add live preview with basic color grading
        if liveVideoProcessing, let preset = previewVideoPreset {
            addLiveVideoProcessing(preset: preset)
        }
    }

    private func addLiveVideoProcessing(preset: VideoPreset) {
        // Use CIFilter for real-time preview (lightweight)
        guard let colorGrading = preset.colorGrading else { return }

        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(colorGrading.contrast, forKey: kCIInputContrastKey)
        filter?.setValue(colorGrading.saturation, forKey: kCIInputSaturationKey)
        filter?.setValue(colorGrading.exposure, forKey: kCIInputBrightnessKey)

        // Apply to preview layer
        // (Full processing happens after recording)
    }
}
```

### 3. New UI Components

```swift
// Settings/VideoPresetSelectionView.swift
struct VideoPresetSelectionView: View {
    @Binding var selectedPreset: VideoPreset
    let presets = PresetManager.shared.videoPresets

    var body: some View {
        List(presets) { preset in
            VideoPresetRow(
                preset: preset,
                isSelected: selectedPreset.id == preset.id
            )
            .onTapGesture { selectedPreset = preset }
        }
    }
}

// Features/VideoExport/VideoProcessingPreview.swift
struct VideoProcessingPreview: View {
    let originalURL: URL
    let processedURL: URL

    var body: some View {
        VStack {
            Text("Before/After Comparison")

            HStack {
                VideoPlayerView(url: originalURL, label: "Original")
                VideoPlayerView(url: processedURL, label: "Processed")
            }

            // Side-by-side scrubber
            BeforeAfterScrubber(original: originalURL, processed: processedURL)
        }
    }
}

// Features/VideoExport/TransitionPreview.swift
struct TransitionPreview: View {
    let scene1: VideoScene
    let scene2: VideoScene
    @Binding var transitionType: TransitionType
    @Binding var duration: TimeInterval

    var body: some View {
        VStack {
            Text("Transition Preview")

            VideoPlayerView(url: previewURL)

            Picker("Transition", selection: $transitionType) {
                ForEach(TransitionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            Slider(value: $duration, in: 0.1...2.0) {
                Text("Duration: \(duration, specifier: "%.1f")s")
            }
        }
    }
}
```

### 4. Project Model Updates

```swift
struct Project: Codable, Identifiable {
    // Existing properties...

    // Video processing settings
    var videoPresetID: UUID?
    var masterPresetID: UUID?

    // Audio processing settings (from AUDIO_ENGINE_DESIGN)
    var audioPresetID: UUID?
    var audioMergePresetID: UUID?

    // Processing history
    var lastVideoProcessedDate: Date?
    var lastAudioProcessedDate: Date?
    var videoQualityMetrics: VideoQualityMetrics?
    var audioQualityMetrics: AudioQualityMetrics?
}
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create folder structure
- [ ] Implement `VideoProcessorProtocol`
- [ ] Implement `VideoProcessingContext`
- [ ] Implement `VideoProcessingChain`
- [ ] Create base models (configs, parameters, etc.)
- [ ] Implement `VideoAnalyzer`
- [ ] Implement `ColorAnalyzer`

### Phase 2: Color Processing (Week 2-3)
- [ ] Implement `ColorGraderProcessor`
- [ ] Implement `ColorCorrectionProcessor`
- [ ] Implement `WhiteBalanceProcessor`
- [ ] Implement `LUTProcessor` with LUT file loading
- [ ] Create Metal shaders for color grading
- [ ] Unit tests for color processors

### Phase 3: Quality Enhancement (Week 3-4)
- [ ] Implement `DenoiseProcessor`
- [ ] Implement `SharpenProcessor`
- [ ] Implement `ExposureProcessor`
- [ ] Implement `StabilizationProcessor` (using CIFilter)
- [ ] Unit tests for enhancement processors

### Phase 4: Scene Processing Engine (Week 4-5)
- [ ] Implement `ReTakeVideoEngine`
- [ ] Implement preset system (`VideoPreset`, `PresetManager`)
- [ ] Create default video presets
- [ ] Integration tests with real takes
- [ ] Performance optimization

### Phase 5: Transitions (Week 5-6)
- [ ] Implement `TransitionEngine`
- [ ] Create transition types (crossfade, wipe, etc.)
- [ ] Implement custom Core Image compositor
- [ ] Test all transition types
- [ ] Optimize transition rendering

### Phase 6: Assembly System (Week 6-7)
- [ ] Implement `ColorMatchingEngine`
- [ ] Implement `SceneVideoAssembler`
- [ ] Implement `MasterGradingEngine`
- [ ] Create master presets
- [ ] Integration tests

### Phase 7: Compression & Encoding (Week 7-8)
- [ ] Implement `CompressionProcessor`
- [ ] Implement `BitrateOptimizer`
- [ ] Implement `CodecSelector`
- [ ] Test multiple output formats
- [ ] Optimize encoding performance

### Phase 8: Unified Media Processing (Week 8-9)
- [ ] Implement `UnifiedMediaProcessor`
- [ ] Integrate with audio engine
- [ ] Implement perfect A/V sync
- [ ] End-to-end testing
- [ ] Performance profiling

### Phase 9: UI & Integration (Week 9-10)
- [ ] Create preset selection UI
- [ ] Create before/after preview UI
- [ ] Create transition preview UI
- [ ] Update `Project` model
- [ ] Update export workflow
- [ ] User testing

### Phase 10: Polish & Optimization (Week 10-11)
- [ ] GPU acceleration with Metal
- [ ] Multi-threaded processing
- [ ] Memory optimization
- [ ] Progress tracking
- [ ] Error handling
- [ ] Documentation

---

## Technical Considerations

### 1. Performance Optimization

**GPU Acceleration (Metal)**
```swift
// Use Metal for heavy processing
- Color grading: 10-50x faster
- Denoising: 20-100x faster
- Sharpening: 5-20x faster
- Transitions: 10-30x faster
```

**Multi-threaded Processing**
```swift
// Process multiple scenes in parallel
let processedScenes = await withTaskGroup(of: ProcessedVideoScene.self) { group in
    for scene in scenes {
        group.addTask {
            await videoEngine.process(scene: scene, preset: preset)
        }
    }

    return await group.reduce(into: []) { $0.append($1) }
}
```

**Progressive Rendering**
```swift
// Generate low-res preview first, then full quality
1. Quick preview at 480p (30 seconds)
2. User reviews and approves
3. Full quality render at 1080p (5 minutes)
```

### 2. Memory Management

```swift
// Process in chunks to avoid memory issues
func processLargeVideo(url: URL) async throws -> URL {
    let chunkDuration: TimeInterval = 10.0  // Process 10s at a time

    let asset = AVAsset(url: url)
    let totalDuration = asset.duration.seconds

    var processedChunks: [URL] = []

    for startTime in stride(from: 0, to: totalDuration, by: chunkDuration) {
        let chunk = try await extractChunk(
            from: asset,
            startTime: startTime,
            duration: chunkDuration
        )

        let processed = try await processChunk(chunk)
        processedChunks.append(processed)

        // Release memory
        autoreleasepool {
            // Cleanup
        }
    }

    // Merge chunks
    return try await mergeChunks(processedChunks)
}
```

### 3. Quality Metrics

```swift
struct VideoQualityMetrics: Codable {
    // Input analysis
    var originalResolution: CGSize
    var originalBitrate: Int
    var originalCodec: String
    var originalFileSize: Int64

    // Processing results
    var processedResolution: CGSize
    var processedBitrate: Int
    var processedCodec: String
    var processedFileSize: Int64

    // Quality indicators
    var colorAccuracy: Float           // 0.0 to 1.0
    var sharpness: Float               // 0.0 to 1.0
    var noiseLevel: Float              // 0.0 to 1.0
    var compressionArtifacts: Float    // 0.0 to 1.0

    // Performance
    var processingTime: TimeInterval
    var compressionRatio: Float        // Original / Processed size

    func generateReport() -> String {
        """
        Video Processing Report
        ----------------------
        Input:
          - Resolution: \(originalResolution.width)x\(originalResolution.height)
          - Bitrate: \(originalBitrate / 1_000_000) Mbps
          - File Size: \(originalFileSize / 1_048_576) MB

        Output:
          - Resolution: \(processedResolution.width)x\(processedResolution.height)
          - Bitrate: \(processedBitrate / 1_000_000) Mbps
          - File Size: \(processedFileSize / 1_048_576) MB
          - Compression: \(compressionRatio)x

        Quality:
          - Color Accuracy: \(colorAccuracy * 100)%
          - Sharpness: \(sharpness * 100)%
          - Noise Level: \(noiseLevel * 100)%

        Processing Time: \(processingTime)s
        """
    }
}
```

### 4. Error Handling

```swift
enum VideoProcessingError: LocalizedError {
    case fileNotFound(URL)
    case invalidFormat(String)
    case processingFailed(processor: String, reason: String)
    case encodingFailed(codec: VideoCodec, reason: String)
    case insufficientMemory
    case gpuUnavailable
    case compositionFailed
    case syncDriftDetected(offset: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Video file not found: \(url.lastPathComponent)"
        case .invalidFormat(let format):
            return "Unsupported video format: \(format)"
        case .processingFailed(let processor, let reason):
            return "Failed to process with \(processor): \(reason)"
        case .encodingFailed(let codec, let reason):
            return "Failed to encode with \(codec): \(reason)"
        case .insufficientMemory:
            return "Not enough memory to process video"
        case .gpuUnavailable:
            return "GPU acceleration unavailable"
        case .compositionFailed:
            return "Failed to compose video tracks"
        case .syncDriftDetected(let offset):
            return "Audio/video sync drift detected: \(offset)s"
        }
    }
}
```

---

## Testing Strategy

### Unit Tests
- Test each processor independently
- Test with various resolutions (480p, 720p, 1080p, 4K)
- Test with different codecs (H.264, HEVC)
- Test edge cases (very short clips, single frames)

### Integration Tests
- Test complete processing chains
- Test preset application
- Test scene assembly with real takes
- Test transition rendering
- Test A/V sync accuracy

### Quality Tests
- A/B comparison with professional tools (DaVinci Resolve, Final Cut Pro)
- Subjective quality assessment
- Automated quality metrics validation
- Cross-platform playback testing

### Performance Tests
- Measure processing time for various video lengths
- GPU vs CPU performance comparison
- Memory usage profiling
- Concurrent processing stress tests
- Battery impact testing

---

## Future Enhancements

### V2 Features
- AI-based scene detection and auto-segmentation
- Automatic style transfer (match look to reference video)
- Face detection and beauty filters
- Background replacement (green screen)
- Text-to-video for B-roll suggestions
- Multi-cam sync (if recording with multiple devices)
- 360° video support
- VR/AR export formats

### Advanced Features
- Machine learning-based quality prediction
- Automatic highlight detection
- Speech-to-text for auto-captioning
- Multi-language subtitle generation
- Advanced motion tracking
- 3D LUT creation from reference images
- Batch processing for multiple projects
- Cloud rendering for complex projects

---

## Cross-Reference with Audio Engine

### Synchronized Processing
- Both engines process takes in parallel (Pass 1)
- Assembly happens in coordination (Pass 2)
- Sync verification before final export
- Shared timing information via `SyncCompensation`

### Preset Pairing
```swift
struct MediaPresetPair: Codable {
    var name: String
    var videoPreset: VideoPreset
    var audioPreset: AudioPreset
    var masterVideoPreset: MasterPreset
    var masterAudioPreset: MergePreset

    static let professionalPair = MediaPresetPair(
        name: "Professional",
        videoPreset: .naturalClean,
        audioPreset: .studioVoice,
        masterVideoPreset: .seamlessProfessional,
        masterAudioPreset: .cohesiveMaster
    )
}
```

---

## References & Resources

### Documentation
- [AVFoundation Programming Guide](https://developer.apple.com/av-foundation/)
- [Core Image Programming Guide](https://developer.apple.com/documentation/coreimage)
- [Metal Programming Guide](https://developer.apple.com/metal/)
- [Video Toolbox Documentation](https://developer.apple.com/documentation/videotoolbox)

### Tools for Reference
- DaVinci Resolve (professional color grading)
- Adobe Premiere Pro (video editing)
- Final Cut Pro (Apple's pro video editor)
- FFmpeg (command-line video processing)

### Codec Resources
- [H.264 Specification](https://www.itu.int/rec/T-REC-H.264)
- [HEVC/H.265 Specification](https://www.itu.int/rec/T-REC-H.265)
- [Apple ProRes White Paper](https://www.apple.com/final-cut-pro/docs/Apple_ProRes_White_Paper.pdf)

---

## End of Design Document

This document should be treated as a living specification. Update it as implementation progresses and requirements evolve.

**Last Updated**: 2025-01-30
**Version**: 1.0
**Author**: Design Team
