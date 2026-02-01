# Unified Video Processing Pipeline - Implementation Plan

## Overview

This document outlines the step-by-step implementation plan for the 5 critical missing components required for a production-ready automated video processing pipeline in ReTakeAi.

**Context**: This is NOT a video editing app. Users select presets → Click Preview/Export → Automatic A/V processing generates final video.

---

## 1. Unified Coordination Layer (A/V Sync Manager)

### Purpose
Ensure perfect audio/video synchronization when both engines independently process and modify timing (especially when audio trims silence).

### Architecture

```
ReTakeAi/Core/Coordination/
├── UnifiedProcessingCoordinator.swift    // Main orchestrator
├── TimingMap.swift                       // Frame-accurate timing mapping
├── SyncCompensationStrategy.swift        // Sync correction strategies
└── ProcessingSession.swift               // State management for one export session
```

### Step 1.1: Create TimingMap Model

**File**: `ReTakeAi/Core/Coordination/TimingMap.swift`

```swift
import Foundation
import CoreMedia

/// Maps original timeline to processed timeline
struct TimingMap: Codable {
    var sceneID: UUID
    var segments: [TimingSegment]

    /// Calculate cumulative offset at a given time
    func offset(at time: CMTime) -> CMTime {
        var cumulativeOffset = CMTime.zero
        for segment in segments where segment.originalRange.containsTime(time) {
            cumulativeOffset = CMTimeAdd(cumulativeOffset, segment.offset)
        }
        return cumulativeOffset
    }

    /// Get processed time from original time
    func processedTime(from originalTime: CMTime) -> CMTime {
        return CMTimeAdd(originalTime, offset(at: originalTime))
    }
}

struct TimingSegment: Codable {
    var originalRange: CMTimeRange      // Original time range
    var processedRange: CMTimeRange     // After processing
    var offset: CMTime                  // Time difference
    var reason: TimingChangeReason      // Why timing changed
}

enum TimingChangeReason: String, Codable {
    case audioSilenceTrimmed
    case audioSpeedAdjusted
    case videoTransitionApplied
    case videoStabilizationCrop
    case manualAdjustment
}
```

**Tasks**:
- [ ] Create `TimingMap.swift` with models above
- [ ] Add unit tests for time offset calculations
- [ ] Add serialization tests (ensure Codable works)

---

### Step 1.2: Create ProcessingSession

**File**: `ReTakeAi/Core/Coordination/ProcessingSession.swift`

```swift
import Foundation
import AVFoundation

/// Represents one complete video processing session
@Observable
class ProcessingSession: Identifiable {
    let id = UUID()
    let projectID: UUID
    let sceneIDs: [UUID]

    // Preset selections
    var audioPreset: AudioPreset
    var videoPreset: VideoPreset
    var audioMergePreset: MergePreset
    var masterVideoPreset: MasterPreset

    // Processing state
    var state: ProcessingState = .pending
    var progress: ProcessingProgress = ProcessingProgress()

    // Pass 1 results (cached)
    var processedAudioTakes: [UUID: ProcessedTakeResult] = [:]
    var processedVideoTakes: [UUID: ProcessedTakeResult] = [:]

    // Pass 2 results
    var audioTimingMap: TimingMap?
    var videoTimingMap: TimingMap?
    var syncCompensation: SyncCompensation?

    // Final output
    var outputURL: URL?
    var qualityMetrics: CombinedQualityMetrics?

    // Error handling
    var error: ProcessingError?
    var checkpoints: [ProcessingCheckpoint] = []

    init(
        projectID: UUID,
        sceneIDs: [UUID],
        audioPreset: AudioPreset,
        videoPreset: VideoPreset,
        audioMergePreset: MergePreset,
        masterVideoPreset: MasterPreset
    ) {
        self.projectID = projectID
        self.sceneIDs = sceneIDs
        self.audioPreset = audioPreset
        self.videoPreset = videoPreset
        self.audioMergePreset = audioMergePreset
        self.masterVideoPreset = masterVideoPreset
    }
}

enum ProcessingState: String, Codable {
    case pending
    case pass1Audio          // Processing individual audio takes
    case pass1Video          // Processing individual video takes
    case pass2AudioAssembly  // Assembling and trimming audio
    case pass2VideoAssembly  // Assembling video with transitions
    case syncCompensation    // Adjusting video for audio changes
    case finalEncoding       // Combining A/V and encoding
    case completed
    case failed
    case cancelled
}

struct ProcessedTakeResult: Codable {
    var takeID: UUID
    var processedURL: URL
    var originalDuration: CMTime
    var processedDuration: CMTime
    var timingMap: TimingMap?
    var qualityMetrics: String?  // JSON serialized metrics
}

struct ProcessingCheckpoint: Codable, Identifiable {
    var id = UUID()
    var state: ProcessingState
    var timestamp: Date
    var completedItems: [UUID]  // Scene/Take IDs completed
    var canResumeFrom: Bool
}
```

**Tasks**:
- [ ] Create `ProcessingSession.swift`
- [ ] Add checkpoint save/restore methods
- [ ] Add state machine validation (ensure valid transitions)
- [ ] Unit tests for state transitions

---

### Step 1.3: Create UnifiedProcessingCoordinator

**File**: `ReTakeAi/Core/Coordination/UnifiedProcessingCoordinator.swift`

```swift
import Foundation
import AVFoundation
import Combine

/// Main orchestrator for unified A/V processing
@MainActor
class UnifiedProcessingCoordinator: ObservableObject {
    static let shared = UnifiedProcessingCoordinator()

    // Dependencies
    private let audioEngine = ReTakeAudioEngine.shared
    private let videoEngine = ReTakeVideoEngine.shared
    private let audioAssembler = SceneAudioAssembler.shared
    private let videoAssembler = SceneVideoAssembler.shared
    private let cacheManager = ProcessingCacheManager.shared

    @Published private(set) var activeSessions: [ProcessingSession] = []

    /// Start a new processing session
    func startProcessing(
        project: Project,
        scenes: [VideoScene],
        audioPreset: AudioPreset,
        videoPreset: VideoPreset,
        audioMergePreset: MergePreset,
        masterVideoPreset: MasterPreset
    ) async throws -> ProcessingSession {

        // Create session
        let session = ProcessingSession(
            projectID: project.id,
            sceneIDs: scenes.map { $0.id },
            audioPreset: audioPreset,
            videoPreset: videoPreset,
            audioMergePreset: audioMergePreset,
            masterVideoPreset: masterVideoPreset
        )

        activeSessions.append(session)

        do {
            // Execute processing pipeline
            try await executeProcessingPipeline(session: session, scenes: scenes)
            return session
        } catch {
            session.state = .failed
            session.error = ProcessingError.pipelineFailed(error.localizedDescription)
            throw error
        }
    }

    /// Execute complete processing pipeline
    private func executeProcessingPipeline(
        session: ProcessingSession,
        scenes: [VideoScene]
    ) async throws {

        // PASS 1A & 1B: Process individual takes (parallel)
        session.state = .pass1Audio
        try await processPass1(session: session, scenes: scenes)
        session.checkpoints.append(ProcessingCheckpoint(
            state: .pass1Video,
            timestamp: Date(),
            completedItems: session.processedAudioTakes.keys.map { $0 },
            canResumeFrom: true
        ))

        // PASS 2A: Assemble audio (with potential timing changes)
        session.state = .pass2AudioAssembly
        let audioResult = try await assembleAudio(session: session, scenes: scenes)
        session.audioTimingMap = audioResult.timingMap

        // PASS 2B: Assemble video (with transitions)
        session.state = .pass2VideoAssembly
        let videoResult = try await assembleVideo(session: session, scenes: scenes)
        session.videoTimingMap = videoResult.timingMap

        // CRITICAL: Sync Compensation
        session.state = .syncCompensation
        let syncResult = try await applySyncCompensation(
            audioTimingMap: audioResult.timingMap,
            videoTimingMap: videoResult.timingMap,
            audioURL: audioResult.url,
            videoURL: videoResult.url
        )
        session.syncCompensation = syncResult

        // PASS 3: Final combine and encode
        session.state = .finalEncoding
        let finalURL = try await combineAndEncode(
            audioURL: audioResult.url,
            videoURL: videoResult.url,
            syncCompensation: syncResult,
            compressionConfig: session.masterVideoPreset.compressionConfig
        )

        session.outputURL = finalURL
        session.state = .completed

        AppLogger.mediaProcessing.info("Processing completed: \(finalURL.lastPathComponent)")
    }

    // MARK: - Pass 1: Individual Take Processing

    private func processPass1(
        session: ProcessingSession,
        scenes: [VideoScene]
    ) async throws {

        // Collect all takes
        var takesToProcess: [(UUID, URL)] = []
        for scene in scenes {
            guard let selectedTakeID = scene.selectedTakeID,
                  let take = AppEnvironment.shared.takeStore.take(id: selectedTakeID) else {
                continue
            }
            takesToProcess.append((take.id, take.fileURL))
        }

        // Check cache first
        let cachedResults = cacheManager.getCachedResults(
            takeIDs: takesToProcess.map { $0.0 },
            audioPreset: session.audioPreset,
            videoPreset: session.videoPreset
        )

        session.processedAudioTakes = cachedResults.audio
        session.processedVideoTakes = cachedResults.video

        // Process uncached takes
        let uncached = takesToProcess.filter { takeID, _ in
            !cachedResults.audio.keys.contains(takeID)
        }

        // Process in parallel (audio + video for each take)
        try await withThrowingTaskGroup(of: (UUID, ProcessedTakeResult, ProcessedTakeResult).self) { group in
            for (takeID, fileURL) in uncached {
                group.addTask {
                    // Process audio
                    let audioResult = try await self.audioEngine.process(
                        audioURL: fileURL,
                        preset: session.audioPreset,
                        progress: { progress in
                            session.progress.updatePass1Audio(takeID: takeID, progress: progress)
                        }
                    )

                    // Process video
                    let videoResult = try await self.videoEngine.process(
                        videoURL: fileURL,
                        preset: session.videoPreset,
                        progress: { progress in
                            session.progress.updatePass1Video(takeID: takeID, progress: progress)
                        }
                    )

                    return (takeID, audioResult, videoResult)
                }
            }

            // Collect results
            for try await (takeID, audioResult, videoResult) in group {
                session.processedAudioTakes[takeID] = audioResult
                session.processedVideoTakes[takeID] = videoResult

                // Cache results
                cacheManager.cacheResult(
                    takeID: takeID,
                    audioResult: audioResult,
                    videoResult: videoResult,
                    audioPreset: session.audioPreset,
                    videoPreset: session.videoPreset
                )
            }
        }
    }

    // MARK: - Pass 2: Assembly

    private func assembleAudio(
        session: ProcessingSession,
        scenes: [VideoScene]
    ) async throws -> AudioAssemblyResult {

        let result = try await audioAssembler.assemble(
            audioTakes: session.processedAudioTakes,
            sceneOrder: session.sceneIDs,
            mergePreset: session.audioMergePreset,
            progress: { progress in
                session.progress.audioAssembly = progress
            }
        )

        return result
    }

    private func assembleVideo(
        session: ProcessingSession,
        scenes: [VideoScene]
    ) async throws -> VideoAssemblyResult {

        let result = try await videoAssembler.assemble(
            videoTakes: session.processedVideoTakes,
            sceneOrder: session.sceneIDs,
            masterPreset: session.masterVideoPreset,
            progress: { progress in
                session.progress.videoAssembly = progress
            }
        )

        return result
    }

    // MARK: - Sync Compensation (CRITICAL)

    private func applySyncCompensation(
        audioTimingMap: TimingMap,
        videoTimingMap: TimingMap,
        audioURL: URL,
        videoURL: URL
    ) async throws -> SyncCompensation {

        // Compare timing maps to detect drift
        let drift = calculateDrift(audioMap: audioTimingMap, videoMap: videoTimingMap)

        guard drift.hasDrift else {
            return SyncCompensation(
                strategy: .noCompensationNeeded,
                totalAudioDuration: audioTimingMap.totalDuration,
                totalVideoDuration: videoTimingMap.totalDuration,
                syncOffset: .zero
            )
        }

        // Choose compensation strategy based on drift amount
        let strategy = selectCompensationStrategy(drift: drift)

        switch strategy {
        case .trimVideo:
            // Trim video to match audio timeline
            return try await trimVideoToMatchAudio(
                audioTimingMap: audioTimingMap,
                videoURL: videoURL
            )

        case .volumeAutomation:
            // Keep video as-is, use volume fades in audio
            return try await addVolumeFades(
                audioURL: audioURL,
                videoTimingMap: videoTimingMap
            )

        case .visualTransition:
            // Add video dissolves to mask cuts
            return try await addVisualTransitions(
                videoURL: videoURL,
                audioTimingMap: audioTimingMap
            )
        }
    }

    private func calculateDrift(
        audioMap: TimingMap,
        videoMap: TimingMap
    ) -> SyncDrift {
        let audioDuration = audioMap.totalDuration
        let videoDuration = videoMap.totalDuration
        let difference = CMTimeSubtract(audioDuration, videoDuration)

        return SyncDrift(
            offset: difference,
            hasDrift: abs(CMTimeGetSeconds(difference)) > 0.033  // > 1 frame at 30fps
        )
    }

    private func selectCompensationStrategy(drift: SyncDrift) -> SyncCompensationStrategy {
        let driftSeconds = abs(CMTimeGetSeconds(drift.offset))

        if driftSeconds > 5.0 {
            // Large drift - trim video
            return .trimVideo
        } else if driftSeconds > 1.0 {
            // Medium drift - visual transitions
            return .visualTransition
        } else {
            // Small drift - volume automation
            return .volumeAutomation
        }
    }

    // MARK: - Final Encoding

    private func combineAndEncode(
        audioURL: URL,
        videoURL: URL,
        syncCompensation: SyncCompensation,
        compressionConfig: CompressionConfig
    ) async throws -> URL {

        // Create composition
        let composition = AVMutableComposition()

        // Add video track
        guard let videoAsset = AVAsset(url: videoURL) as AVAsset?,
              let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ),
              let sourceVideoTrack = videoAsset.tracks(withMediaType: .video).first else {
            throw ProcessingError.compositionFailed
        }

        try videoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoAsset.duration),
            of: sourceVideoTrack,
            at: .zero
        )

        // Add audio track with sync compensation applied
        guard let audioAsset = AVAsset(url: audioURL) as AVAsset?,
              let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ),
              let sourceAudioTrack = audioAsset.tracks(withMediaType: .audio).first else {
            throw ProcessingError.compositionFailed
        }

        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: audioAsset.duration),
            of: sourceAudioTrack,
            at: .zero
        )

        // Verify sync
        let syncOffset = CMTimeSubtract(videoAsset.duration, audioAsset.duration)
        let syncOffsetSeconds = abs(CMTimeGetSeconds(syncOffset))
        if syncOffsetSeconds > 0.1 {
            throw ProcessingError.syncDriftDetected(offset: syncOffsetSeconds)
        }

        // Export with compression settings
        let outputURL = FileStorageManager.shared.tempURL(filename: "final_\(UUID().uuidString).mp4")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: compressionConfig.exportPresetName
        ) else {
            throw ProcessingError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = compressionConfig.outputFileType

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw ProcessingError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown")
        }

        return outputURL
    }
}

// MARK: - Supporting Types

struct SyncDrift {
    var offset: CMTime
    var hasDrift: Bool
}

enum SyncCompensationStrategy {
    case trimVideo
    case volumeAutomation
    case visualTransition
}

struct AudioAssemblyResult {
    var url: URL
    var timingMap: TimingMap
    var duration: CMTime
}

struct VideoAssemblyResult {
    var url: URL
    var timingMap: TimingMap
    var duration: CMTime
}

enum ProcessingError: LocalizedError {
    case pipelineFailed(String)
    case compositionFailed
    case syncDriftDetected(offset: TimeInterval)
    case exportSessionCreationFailed
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .pipelineFailed(let reason):
            return "Processing failed: \(reason)"
        case .compositionFailed:
            return "Failed to create video composition"
        case .syncDriftDetected(let offset):
            return "Audio/video sync drift detected: \(offset)s"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}
```

**Tasks**:
- [ ] Implement `UnifiedProcessingCoordinator.swift`
- [ ] Add sync compensation algorithms
- [ ] Add timing map comparison logic
- [ ] Integration tests with sample A/V files
- [ ] Test with various timing scenarios (audio shorter, video shorter, etc.)

---

### Step 1.4: Update AppEnvironment

**File**: `ReTakeAi/Core/Utilities/AppEnvironment.swift`

Add coordinator to shared environment:

```swift
class AppEnvironment {
    static let shared = AppEnvironment()

    // Existing services...

    // NEW: Unified coordinator
    lazy var processingCoordinator = UnifiedProcessingCoordinator.shared
}
```

**Tasks**:
- [ ] Add coordinator to AppEnvironment
- [ ] Update existing VideoMerger to use coordinator
- [ ] Add integration tests

---

## 2. Caching Strategy (Pass 1 Outputs)

### Purpose
Cache processed individual takes (Pass 1 results) to avoid reprocessing when only Pass 2 presets change.

### Architecture

```
ReTakeAi/Core/Caching/
├── ProcessingCacheManager.swift          // Main cache manager
├── CacheKeyGenerator.swift               // Generate cache keys from presets
├── CacheStoragePolicy.swift              // Storage limits and eviction
└── CachedProcessingResult.swift          // Cached result model
```

### Step 2.1: Create Cache Models

**File**: `ReTakeAi/Core/Caching/CachedProcessingResult.swift`

```swift
import Foundation
import CoreMedia

struct CachedProcessingResult: Codable {
    var takeID: UUID
    var resultType: ResultType
    var processedFileURL: URL
    var presetHash: String              // Hash of preset used
    var originalDuration: CMTime
    var processedDuration: CMTime
    var timingMap: TimingMap?
    var cachedDate: Date
    var fileSize: Int64
    var qualityMetrics: String?         // JSON serialized

    enum ResultType: String, Codable {
        case audio
        case video
    }
}

struct CacheMetadata: Codable {
    var totalSize: Int64
    var itemCount: Int
    var oldestItem: Date?
    var lastCleanup: Date
}

struct CacheQueryResult {
    var audio: [UUID: ProcessedTakeResult]
    var video: [UUID: ProcessedTakeResult]
    var cacheHits: Int
    var cacheMisses: Int
}
```

**Tasks**:
- [ ] Create cache models
- [ ] Add Codable tests
- [ ] Add CMTime serialization helpers

---

### Step 2.2: Create CacheKeyGenerator

**File**: `ReTakeAi/Core/Caching/CacheKeyGenerator.swift`

```swift
import Foundation
import CryptoKit

struct CacheKeyGenerator {

    /// Generate cache key for audio processing
    static func audioKey(takeID: UUID, preset: AudioPreset) -> String {
        let presetData = try! JSONEncoder().encode(preset)
        let presetHash = SHA256.hash(data: presetData)
        let hashString = presetHash.compactMap { String(format: "%02x", $0) }.joined()
        return "audio_\(takeID.uuidString)_\(hashString.prefix(16))"
    }

    /// Generate cache key for video processing
    static func videoKey(takeID: UUID, preset: VideoPreset) -> String {
        let presetData = try! JSONEncoder().encode(preset)
        let presetHash = SHA256.hash(data: presetData)
        let hashString = presetHash.compactMap { String(format: "%02x", $0) }.joined()
        return "video_\(takeID.uuidString)_\(hashString.prefix(16))"
    }

    /// Generate preset fingerprint
    static func presetFingerprint<T: Encodable>(_ preset: T) -> String {
        let data = try! JSONEncoder().encode(preset)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}
```

**Tasks**:
- [ ] Implement key generation
- [ ] Add collision tests
- [ ] Test preset hash stability

---

### Step 2.3: Create CacheStoragePolicy

**File**: `ReTakeAi/Core/Caching/CacheStoragePolicy.swift`

```swift
import Foundation

struct CacheStoragePolicy {
    // Storage limits
    var maxCacheSize: Int64 = 2 * 1024 * 1024 * 1024  // 2 GB default
    var maxItemAge: TimeInterval = 7 * 24 * 60 * 60   // 7 days
    var maxItemCount: Int = 100

    // Eviction strategy
    var evictionStrategy: EvictionStrategy = .leastRecentlyUsed

    // Cleanup schedule
    var autoCleanupInterval: TimeInterval = 24 * 60 * 60  // Daily

    enum EvictionStrategy {
        case leastRecentlyUsed
        case oldest
        case largest
    }

    /// Determine if cache needs cleanup
    func needsCleanup(metadata: CacheMetadata) -> Bool {
        // Check size limit
        if metadata.totalSize > maxCacheSize {
            return true
        }

        // Check item count
        if metadata.itemCount > maxItemCount {
            return true
        }

        // Check cleanup interval
        let timeSinceCleanup = Date().timeIntervalSince(metadata.lastCleanup)
        if timeSinceCleanup > autoCleanupInterval {
            return true
        }

        return false
    }

    /// Select items to evict
    func itemsToEvict(
        from items: [CachedProcessingResult],
        targetSize: Int64
    ) -> [CachedProcessingResult] {

        var sorted: [CachedProcessingResult]

        switch evictionStrategy {
        case .leastRecentlyUsed:
            sorted = items.sorted { $0.cachedDate < $1.cachedDate }
        case .oldest:
            sorted = items.sorted { $0.cachedDate < $1.cachedDate }
        case .largest:
            sorted = items.sorted { $0.fileSize > $1.fileSize }
        }

        // Calculate how much to evict
        let currentSize = items.reduce(0) { $0 + $1.fileSize }
        let excessSize = currentSize - targetSize

        var toEvict: [CachedProcessingResult] = []
        var evictedSize: Int64 = 0

        for item in sorted {
            toEvict.append(item)
            evictedSize += item.fileSize
            if evictedSize >= excessSize {
                break
            }
        }

        return toEvict
    }
}
```

**Tasks**:
- [ ] Implement storage policy
- [ ] Add eviction logic tests
- [ ] Test size calculations

---

### Step 2.4: Create ProcessingCacheManager

**File**: `ReTakeAi/Core/Caching/ProcessingCacheManager.swift`

```swift
import Foundation

@MainActor
class ProcessingCacheManager: ObservableObject {
    static let shared = ProcessingCacheManager()

    @Published private(set) var metadata = CacheMetadata(
        totalSize: 0,
        itemCount: 0,
        oldestItem: nil,
        lastCleanup: Date()
    )

    private let policy = CacheStoragePolicy()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var cacheIndex: [String: CachedProcessingResult] = [:]

    init() {
        // Cache location: Documents/ReTakeAi/Cache/
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsDir
            .appendingPathComponent("ReTakeAi")
            .appendingPathComponent("Cache")

        // Create cache directory
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load cache index
        loadCacheIndex()

        // Schedule periodic cleanup
        schedulePeriodicCleanup()
    }

    // MARK: - Cache Operations

    /// Get cached results for multiple takes
    func getCachedResults(
        takeIDs: [UUID],
        audioPreset: AudioPreset,
        videoPreset: VideoPreset
    ) -> CacheQueryResult {

        var audioResults: [UUID: ProcessedTakeResult] = [:]
        var videoResults: [UUID: ProcessedTakeResult] = [:]
        var hits = 0
        var misses = 0

        for takeID in takeIDs {
            // Check audio cache
            let audioKey = CacheKeyGenerator.audioKey(takeID: takeID, preset: audioPreset)
            if let cached = cacheIndex[audioKey],
               fileExists(at: cached.processedFileURL) {
                audioResults[takeID] = ProcessedTakeResult(from: cached)
                hits += 1
            } else {
                misses += 1
            }

            // Check video cache
            let videoKey = CacheKeyGenerator.videoKey(takeID: takeID, preset: videoPreset)
            if let cached = cacheIndex[videoKey],
               fileExists(at: cached.processedFileURL) {
                videoResults[takeID] = ProcessedTakeResult(from: cached)
                hits += 1
            } else {
                misses += 1
            }
        }

        AppLogger.mediaProcessing.info("Cache hits: \(hits), misses: \(misses)")

        return CacheQueryResult(
            audio: audioResults,
            video: videoResults,
            cacheHits: hits,
            cacheMisses: misses
        )
    }

    /// Cache a processing result
    func cacheResult(
        takeID: UUID,
        audioResult: ProcessedTakeResult,
        videoResult: ProcessedTakeResult,
        audioPreset: AudioPreset,
        videoPreset: VideoPreset
    ) {
        // Cache audio
        let audioKey = CacheKeyGenerator.audioKey(takeID: takeID, preset: audioPreset)
        let audioCached = CachedProcessingResult(
            takeID: takeID,
            resultType: .audio,
            processedFileURL: audioResult.processedURL,
            presetHash: CacheKeyGenerator.presetFingerprint(audioPreset),
            originalDuration: audioResult.originalDuration,
            processedDuration: audioResult.processedDuration,
            timingMap: audioResult.timingMap,
            cachedDate: Date(),
            fileSize: fileSize(at: audioResult.processedURL) ?? 0,
            qualityMetrics: audioResult.qualityMetrics
        )
        cacheIndex[audioKey] = audioCached

        // Cache video
        let videoKey = CacheKeyGenerator.videoKey(takeID: takeID, preset: videoPreset)
        let videoCached = CachedProcessingResult(
            takeID: takeID,
            resultType: .video,
            processedFileURL: videoResult.processedURL,
            presetHash: CacheKeyGenerator.presetFingerprint(videoPreset),
            originalDuration: videoResult.originalDuration,
            processedDuration: videoResult.processedDuration,
            timingMap: videoResult.timingMap,
            cachedDate: Date(),
            fileSize: fileSize(at: videoResult.processedURL) ?? 0,
            qualityMetrics: videoResult.qualityMetrics
        )
        cacheIndex[videoKey] = videoCached

        // Update metadata
        updateMetadata()

        // Save index
        saveCacheIndex()

        // Trigger cleanup if needed
        if policy.needsCleanup(metadata: metadata) {
            Task { await cleanup() }
        }
    }

    /// Invalidate cache for a take
    func invalidate(takeID: UUID) {
        let keysToRemove = cacheIndex.filter { $0.value.takeID == takeID }.map { $0.key }
        for key in keysToRemove {
            if let cached = cacheIndex[key] {
                try? fileManager.removeItem(at: cached.processedFileURL)
            }
            cacheIndex.removeValue(forKey: key)
        }
        updateMetadata()
        saveCacheIndex()
    }

    /// Clear all cache
    func clearAll() {
        for (_, cached) in cacheIndex {
            try? fileManager.removeItem(at: cached.processedFileURL)
        }
        cacheIndex.removeAll()
        updateMetadata()
        saveCacheIndex()
        AppLogger.mediaProcessing.info("Cache cleared")
    }

    // MARK: - Cleanup

    func cleanup() async {
        guard policy.needsCleanup(metadata: metadata) else { return }

        AppLogger.mediaProcessing.info("Starting cache cleanup")

        let allItems = Array(cacheIndex.values)

        // Remove expired items
        let now = Date()
        let expired = allItems.filter {
            now.timeIntervalSince($0.cachedDate) > policy.maxItemAge
        }

        for item in expired {
            removeFromCache(item)
        }

        // Remove items if still over limit
        if metadata.totalSize > policy.maxCacheSize {
            let targetSize = policy.maxCacheSize * 80 / 100  // Target 80% of max
            let toEvict = policy.itemsToEvict(
                from: Array(cacheIndex.values),
                targetSize: targetSize
            )

            for item in toEvict {
                removeFromCache(item)
            }
        }

        metadata.lastCleanup = Date()
        saveCacheIndex()

        AppLogger.mediaProcessing.info("Cache cleanup completed. Size: \(metadata.totalSize / 1_048_576) MB")
    }

    private func removeFromCache(_ item: CachedProcessingResult) {
        // Delete file
        try? fileManager.removeItem(at: item.processedFileURL)

        // Remove from index
        let key = item.resultType == .audio
            ? "audio_\(item.takeID.uuidString)_\(item.presetHash)"
            : "video_\(item.takeID.uuidString)_\(item.presetHash)"
        cacheIndex.removeValue(forKey: key)
    }

    private func schedulePeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: policy.autoCleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.cleanup()
            }
        }
    }

    // MARK: - Persistence

    private func loadCacheIndex() {
        let indexURL = cacheDirectory.appendingPathComponent("cache_index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode([String: CachedProcessingResult].self, from: data) else {
            return
        }

        cacheIndex = index
        updateMetadata()
        AppLogger.mediaProcessing.info("Loaded cache index: \(cacheIndex.count) items")
    }

    private func saveCacheIndex() {
        let indexURL = cacheDirectory.appendingPathComponent("cache_index.json")
        guard let data = try? JSONEncoder().encode(cacheIndex) else { return }
        try? data.write(to: indexURL)
    }

    private func updateMetadata() {
        let totalSize = cacheIndex.values.reduce(0) { $0 + $1.fileSize }
        let oldest = cacheIndex.values.map { $0.cachedDate }.min()

        metadata = CacheMetadata(
            totalSize: totalSize,
            itemCount: cacheIndex.count,
            oldestItem: oldest,
            lastCleanup: metadata.lastCleanup
        )
    }

    // MARK: - Helpers

    private func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    private func fileSize(at url: URL) -> Int64? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attrs[.size] as? Int64
    }
}

// MARK: - Extensions

extension ProcessedTakeResult {
    init(from cached: CachedProcessingResult) {
        self.init(
            takeID: cached.takeID,
            processedURL: cached.processedFileURL,
            originalDuration: cached.originalDuration,
            processedDuration: cached.processedDuration,
            timingMap: cached.timingMap,
            qualityMetrics: cached.qualityMetrics
        )
    }
}
```

**Tasks**:
- [ ] Implement cache manager
- [ ] Add persistence tests
- [ ] Test cleanup/eviction logic
- [ ] Test cache hit/miss scenarios
- [ ] Performance testing with large files

---

## 3. Export Queue & Background Processing

### Purpose
Allow exports to continue running when app backgrounds, and queue multiple exports.

### Architecture

```
ReTakeAi/Core/Export/
├── ExportQueue.swift                     // Queue management
├── ExportTask.swift                      // Individual export task
├── BackgroundExportManager.swift         // Background session handling
└── ExportNotificationManager.swift       // User notifications
```

### Step 3.1: Create ExportTask Model

**File**: `ReTakeAi/Core/Export/ExportTask.swift`

```swift
import Foundation
import AVFoundation

@Observable
class ExportTask: Identifiable, Codable {
    let id: UUID
    let projectID: UUID
    let projectTitle: String
    let sceneIDs: [UUID]

    // Presets
    let audioPresetID: UUID
    let videoPresetID: UUID
    let audioMergePresetID: UUID
    let masterVideoPresetID: UUID

    // State
    var state: ExportState = .queued
    var progress: Double = 0.0
    var currentStage: String = ""

    // Timestamps
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?

    // Results
    var outputURL: URL?
    var error: String?
    var qualityMetrics: CombinedQualityMetrics?

    // Background handling
    var backgroundTaskID: UIBackgroundTaskIdentifier?
    var processingSessionID: UUID?

    init(
        id: UUID = UUID(),
        projectID: UUID,
        projectTitle: String,
        sceneIDs: [UUID],
        audioPresetID: UUID,
        videoPresetID: UUID,
        audioMergePresetID: UUID,
        masterVideoPresetID: UUID
    ) {
        self.id = id
        self.projectID = projectID
        self.projectTitle = projectTitle
        self.sceneIDs = sceneIDs
        self.audioPresetID = audioPresetID
        self.videoPresetID = videoPresetID
        self.audioMergePresetID = audioMergePresetID
        self.masterVideoPresetID = masterVideoPresetID
        self.createdAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, projectID, projectTitle, sceneIDs
        case audioPresetID, videoPresetID, audioMergePresetID, masterVideoPresetID
        case state, progress, currentStage
        case createdAt, startedAt, completedAt
        case outputURL, error
        case processingSessionID
    }
}

enum ExportState: String, Codable {
    case queued
    case processing
    case completed
    case failed
    case cancelled
}
```

**Tasks**:
- [ ] Create ExportTask model
- [ ] Add Codable support
- [ ] Add state validation

---

### Step 3.2: Create ExportQueue

**File**: `ReTakeAi/Core/Export/ExportQueue.swift`

```swift
import Foundation
import Combine

@MainActor
class ExportQueue: ObservableObject {
    static let shared = ExportQueue()

    @Published private(set) var tasks: [ExportTask] = []
    @Published private(set) var currentTask: ExportTask?

    private let maxConcurrentExports = 1  // Process one at a time
    private var cancellables = Set<AnyCancellable>()

    private let coordinator = UnifiedProcessingCoordinator.shared
    private let backgroundManager = BackgroundExportManager.shared
    private let notificationManager = ExportNotificationManager.shared

    init() {
        loadQueue()
    }

    // MARK: - Queue Management

    /// Add export to queue
    func enqueue(
        project: Project,
        scenes: [VideoScene],
        audioPreset: AudioPreset,
        videoPreset: VideoPreset,
        audioMergePreset: MergePreset,
        masterVideoPreset: MasterPreset
    ) -> ExportTask {

        let task = ExportTask(
            projectID: project.id,
            projectTitle: project.title,
            sceneIDs: scenes.map { $0.id },
            audioPresetID: audioPreset.id,
            videoPresetID: videoPreset.id,
            audioMergePresetID: audioMergePreset.id,
            masterVideoPresetID: masterVideoPreset.id
        )

        tasks.append(task)
        saveQueue()

        AppLogger.mediaProcessing.info("Export queued: \(project.title)")

        // Start processing if queue was idle
        if currentTask == nil {
            processNextTask()
        }

        return task
    }

    /// Cancel an export
    func cancel(taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }

        if task.state == .processing {
            // Cancel active processing
            if let sessionID = task.processingSessionID {
                coordinator.cancelSession(sessionID: sessionID)
            }
        }

        task.state = .cancelled
        saveQueue()

        // Process next task
        if currentTask?.id == taskID {
            currentTask = nil
            processNextTask()
        }
    }

    /// Remove completed/failed tasks
    func removeTask(taskID: UUID) {
        tasks.removeAll { $0.id == taskID }
        saveQueue()
    }

    /// Clear all completed/failed tasks
    func clearCompleted() {
        tasks.removeAll { $0.state == .completed || $0.state == .failed }
        saveQueue()
    }

    // MARK: - Processing

    private func processNextTask() {
        // Find next queued task
        guard let nextTask = tasks.first(where: { $0.state == .queued }) else {
            currentTask = nil
            return
        }

        currentTask = nextTask
        nextTask.state = .processing
        nextTask.startedAt = Date()
        saveQueue()

        // Register background task
        backgroundManager.beginBackgroundTask(for: nextTask)

        // Start processing
        Task {
            await executeExport(task: nextTask)
        }
    }

    private func executeExport(task: ExportTask) async {
        do {
            // Load presets
            let presetManager = PresetManager.shared
            guard let audioPreset = presetManager.audioPreset(id: task.audioPresetID),
                  let videoPreset = presetManager.videoPreset(id: task.videoPresetID),
                  let audioMergePreset = presetManager.audioMergePreset(id: task.audioMergePresetID),
                  let masterVideoPreset = presetManager.masterVideoPreset(id: task.masterVideoPresetID) else {
                throw ExportError.presetsNotFound
            }

            // Load project and scenes
            guard let project = AppEnvironment.shared.projectStore.project(id: task.projectID) else {
                throw ExportError.projectNotFound
            }

            let scenes = task.sceneIDs.compactMap {
                AppEnvironment.shared.sceneStore.scene(id: $0)
            }

            guard scenes.count == task.sceneIDs.count else {
                throw ExportError.scenesNotFound
            }

            // Start processing
            let session = try await coordinator.startProcessing(
                project: project,
                scenes: scenes,
                audioPreset: audioPreset,
                videoPreset: videoPreset,
                audioMergePreset: audioMergePreset,
                masterVideoPreset: masterVideoPreset
            )

            task.processingSessionID = session.id

            // Monitor progress
            observeProgress(session: session, task: task)

            // Wait for completion
            while session.state != .completed && session.state != .failed {
                try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
            }

            if session.state == .completed, let outputURL = session.outputURL {
                // Success
                task.outputURL = outputURL
                task.state = .completed
                task.completedAt = Date()
                task.qualityMetrics = session.qualityMetrics

                // Send notification
                notificationManager.sendCompletionNotification(for: task)

                AppLogger.mediaProcessing.info("Export completed: \(task.projectTitle)")

            } else if let error = session.error {
                // Failed
                task.state = .failed
                task.error = error.localizedDescription
                task.completedAt = Date()

                notificationManager.sendFailureNotification(for: task)

                AppLogger.mediaProcessing.error("Export failed: \(error.localizedDescription)")
            }

        } catch {
            task.state = .failed
            task.error = error.localizedDescription
            task.completedAt = Date()

            notificationManager.sendFailureNotification(for: task)

            AppLogger.mediaProcessing.error("Export error: \(error.localizedDescription)")
        }

        // End background task
        backgroundManager.endBackgroundTask(for: task)

        // Save state
        saveQueue()

        // Process next
        currentTask = nil
        processNextTask()
    }

    private func observeProgress(session: ProcessingSession, task: ExportTask) {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            Task { @MainActor in
                guard session.state != .completed && session.state != .failed else {
                    timer.invalidate()
                    return
                }

                task.progress = session.progress.overall
                task.currentStage = session.state.rawValue
                self.saveQueue()
            }
        }
    }

    // MARK: - Persistence

    private func loadQueue() {
        let queueURL = FileStorageManager.shared.exportQueueURL()
        guard let data = try? Data(contentsOf: queueURL),
              let loaded = try? JSONDecoder().decode([ExportTask].self, from: data) else {
            return
        }

        tasks = loaded

        // Resume processing if there was an active task
        if let processing = tasks.first(where: { $0.state == .processing }) {
            processing.state = .queued  // Restart
            processNextTask()
        }
    }

    private func saveQueue() {
        let queueURL = FileStorageManager.shared.exportQueueURL()
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: queueURL)
    }
}

enum ExportError: LocalizedError {
    case presetsNotFound
    case projectNotFound
    case scenesNotFound

    var errorDescription: String? {
        switch self {
        case .presetsNotFound:
            return "One or more presets could not be found"
        case .projectNotFound:
            return "Project not found"
        case .scenesNotFound:
            return "One or more scenes could not be found"
        }
    }
}
```

**Tasks**:
- [ ] Implement export queue
- [ ] Add persistence
- [ ] Add queue tests
- [ ] Test concurrent export handling

---

### Step 3.3: Create BackgroundExportManager

**File**: `ReTakeAi/Core/Export/BackgroundExportManager.swift`

```swift
import UIKit

class BackgroundExportManager {
    static let shared = BackgroundExportManager()

    private var backgroundTasks: [UUID: UIBackgroundTaskIdentifier] = [:]

    func beginBackgroundTask(for task: ExportTask) {
        let taskID = UIApplication.shared.beginBackgroundTask(withName: "Export_\(task.id)") {
            // Expiration handler
            AppLogger.mediaProcessing.warning("Background task expiring for export: \(task.id)")
            self.endBackgroundTask(for: task)
        }

        backgroundTasks[task.id] = taskID
        task.backgroundTaskID = taskID

        AppLogger.mediaProcessing.info("Background task started: \(taskID.rawValue)")
    }

    func endBackgroundTask(for task: ExportTask) {
        guard let taskID = backgroundTasks[task.id] else { return }

        UIApplication.shared.endBackgroundTask(taskID)
        backgroundTasks.removeValue(forKey: task.id)
        task.backgroundTaskID = nil

        AppLogger.mediaProcessing.info("Background task ended: \(taskID.rawValue)")
    }
}
```

**Tasks**:
- [ ] Implement background task management
- [ ] Test background task expiration
- [ ] Test app termination scenarios

---

### Step 3.4: Create ExportNotificationManager

**File**: `ReTakeAi/Core/Export/ExportNotificationManager.swift`

```swift
import UserNotifications

class ExportNotificationManager {
    static let shared = ExportNotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                AppLogger.ui.info("Notification permission granted")
            }
        }
    }

    func sendCompletionNotification(for task: ExportTask) {
        let content = UNMutableNotificationContent()
        content.title = "Export Complete"
        content.body = "\(task.projectTitle) is ready to share!"
        content.sound = .default
        content.userInfo = ["taskID": task.id.uuidString]

        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: nil  // Immediate
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendFailureNotification(for task: ExportTask) {
        let content = UNMutableNotificationContent()
        content.title = "Export Failed"
        content.body = "\(task.projectTitle) export encountered an error"
        content.sound = .default
        content.userInfo = ["taskID": task.id.uuidString]

        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

**Tasks**:
- [ ] Implement notification manager
- [ ] Test notification delivery
- [ ] Test notification tap handling

---

## 4. Error Recovery & Checkpoints

### Purpose
Save processing state at key milestones to resume from failure points without starting over.

### Architecture

```
ReTakeAi/Core/ErrorRecovery/
├── CheckpointManager.swift               // Checkpoint save/restore
├── ProcessingRecovery.swift              // Recovery logic
└── ErrorAnalyzer.swift                   // Analyze and categorize errors
```

### Step 4.1: Enhance ProcessingSession with Checkpoints

Already added in Section 1.2, but here's the checkpoint structure:

```swift
struct ProcessingCheckpoint: Codable, Identifiable {
    var id = UUID()
    var state: ProcessingState
    var timestamp: Date
    var completedItems: [UUID]       // Take/Scene IDs completed
    var canResumeFrom: Bool

    // Pass 1 results
    var pass1AudioResults: [UUID: URL]?
    var pass1VideoResults: [UUID: URL]?

    // Pass 2 intermediate results
    var assembledAudioURL: URL?
    var assembledVideoURL: URL?
    var audioTimingMap: TimingMap?
    var videoTimingMap: TimingMap?
}
```

**Tasks**:
- [ ] Add checkpoint data to session model
- [ ] Add checkpoint serialization tests

---

### Step 4.2: Create CheckpointManager

**File**: `ReTakeAi/Core/ErrorRecovery/CheckpointManager.swift`

```swift
import Foundation

class CheckpointManager {
    static let shared = CheckpointManager()

    private let fileManager = FileManager.default
    private let checkpointDirectory: URL

    init() {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.checkpointDirectory = documentsDir
            .appendingPathComponent("ReTakeAi")
            .appendingPathComponent("Checkpoints")

        try? fileManager.createDirectory(at: checkpointDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save Checkpoint

    func saveCheckpoint(session: ProcessingSession) {
        let checkpointURL = checkpointDirectory.appendingPathComponent("\(session.id.uuidString).json")

        guard let data = try? JSONEncoder().encode(session) else {
            AppLogger.mediaProcessing.error("Failed to encode checkpoint")
            return
        }

        do {
            try data.write(to: checkpointURL)
            AppLogger.mediaProcessing.info("Checkpoint saved: \(session.state.rawValue)")
        } catch {
            AppLogger.mediaProcessing.error("Failed to save checkpoint: \(error)")
        }
    }

    // MARK: - Load Checkpoint

    func loadCheckpoint(sessionID: UUID) -> ProcessingSession? {
        let checkpointURL = checkpointDirectory.appendingPathComponent("\(sessionID.uuidString).json")

        guard let data = try? Data(contentsOf: checkpointURL),
              let session = try? JSONDecoder().decode(ProcessingSession.self, from: data) else {
            return nil
        }

        AppLogger.mediaProcessing.info("Checkpoint loaded: \(session.state.rawValue)")
        return session
    }

    // MARK: - Resume from Checkpoint

    func canResume(session: ProcessingSession) -> Bool {
        // Check if last checkpoint is resumable
        guard let lastCheckpoint = session.checkpoints.last else {
            return false
        }

        return lastCheckpoint.canResumeFrom
    }

    func findResumePoint(session: ProcessingSession) -> ProcessingCheckpoint? {
        // Find most recent resumable checkpoint
        return session.checkpoints
            .filter { $0.canResumeFrom }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }

    // MARK: - Cleanup

    func deleteCheckpoint(sessionID: UUID) {
        let checkpointURL = checkpointDirectory.appendingPathComponent("\(sessionID.uuidString).json")
        try? fileManager.removeItem(at: checkpointURL)
    }

    func deleteOldCheckpoints(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        guard let files = try? fileManager.contentsOfDirectory(at: checkpointDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }

        for file in files {
            guard let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                  let creationDate = attrs[.creationDate] as? Date,
                  creationDate < cutoffDate else {
                continue
            }

            try? fileManager.removeItem(at: file)
        }
    }
}
```

**Tasks**:
- [ ] Implement checkpoint manager
- [ ] Add checkpoint persistence tests
- [ ] Test resume logic

---

### Step 4.3: Create ProcessingRecovery

**File**: `ReTakeAi/Core/ErrorRecovery/ProcessingRecovery.swift`

```swift
import Foundation

class ProcessingRecovery {
    static let shared = ProcessingRecovery()

    private let checkpointManager = CheckpointManager.shared
    private let coordinator = UnifiedProcessingCoordinator.shared

    /// Attempt to resume a failed session
    func resumeSession(sessionID: UUID) async throws -> ProcessingSession {
        guard let session = checkpointManager.loadCheckpoint(sessionID: sessionID) else {
            throw RecoveryError.checkpointNotFound
        }

        guard let resumePoint = checkpointManager.findResumePoint(session: session) else {
            throw RecoveryError.noResumableCheckpoint
        }

        AppLogger.mediaProcessing.info("Resuming from: \(resumePoint.state.rawValue)")

        // Resume based on checkpoint state
        switch resumePoint.state {
        case .pass1Video:
            // Pass 1 audio completed, resume video processing
            return try await resumeFromPass1(session: session, checkpoint: resumePoint)

        case .pass2AudioAssembly:
            // Pass 1 completed, resume assembly
            return try await resumeFromPass2Audio(session: session, checkpoint: resumePoint)

        case .pass2VideoAssembly:
            // Audio assembly done, resume video assembly
            return try await resumeFromPass2Video(session: session, checkpoint: resumePoint)

        case .syncCompensation:
            // Both assemblies done, resume sync
            return try await resumeFromSync(session: session, checkpoint: resumePoint)

        default:
            throw RecoveryError.invalidResumePoint(resumePoint.state)
        }
    }

    private func resumeFromPass1(
        session: ProcessingSession,
        checkpoint: ProcessingCheckpoint
    ) async throws -> ProcessingSession {
        // Restore Pass 1 audio results from checkpoint
        if let audioResults = checkpoint.pass1AudioResults {
            for (takeID, url) in audioResults {
                session.processedAudioTakes[takeID] = ProcessedTakeResult(
                    takeID: takeID,
                    processedURL: url,
                    originalDuration: .zero,  // Load from metadata if needed
                    processedDuration: .zero
                )
            }
        }

        // Continue with remaining video processing
        // ... (delegate to coordinator)

        return session
    }

    private func resumeFromPass2Audio(
        session: ProcessingSession,
        checkpoint: ProcessingCheckpoint
    ) async throws -> ProcessingSession {
        // Restore Pass 1 results
        // Continue from audio assembly
        // ... (delegate to coordinator)

        return session
    }

    private func resumeFromPass2Video(
        session: ProcessingSession,
        checkpoint: ProcessingCheckpoint
    ) async throws -> ProcessingSession {
        // Restore assembled audio
        // Continue from video assembly
        // ... (delegate to coordinator)

        return session
    }

    private func resumeFromSync(
        session: ProcessingSession,
        checkpoint: ProcessingCheckpoint
    ) async throws -> ProcessingSession {
        // Restore assembled A/V
        // Continue from sync compensation
        // ... (delegate to coordinator)

        return session
    }
}

enum RecoveryError: LocalizedError {
    case checkpointNotFound
    case noResumableCheckpoint
    case invalidResumePoint(ProcessingState)

    var errorDescription: String? {
        switch self {
        case .checkpointNotFound:
            return "Checkpoint file not found"
        case .noResumableCheckpoint:
            return "No valid checkpoint to resume from"
        case .invalidResumePoint(let state):
            return "Cannot resume from state: \(state.rawValue)"
        }
    }
}
```

**Tasks**:
- [ ] Implement recovery manager
- [ ] Add resume logic for each checkpoint
- [ ] Test failure/recovery scenarios
- [ ] Integration tests with coordinator

---

### Step 4.4: Create ErrorAnalyzer

**File**: `ReTakeAi/Core/ErrorRecovery/ErrorAnalyzer.swift`

```swift
import Foundation
import AVFoundation

class ErrorAnalyzer {

    /// Analyze error and determine if recovery is possible
    func analyze(error: Error) -> ErrorAnalysis {
        let category = categorize(error: error)
        let recoverable = isRecoverable(category: category)
        let suggestion = suggestRecovery(category: category)

        return ErrorAnalysis(
            error: error,
            category: category,
            recoverable: recoverable,
            suggestion: suggestion
        )
    }

    private func categorize(error: Error) -> ErrorCategory {
        if isMemoryError(error) {
            return .insufficientMemory
        } else if isStorageError(error) {
            return .insufficientStorage
        } else if isNetworkError(error) {
            return .networkFailure
        } else if isCorruptFileError(error) {
            return .corruptFile
        } else if isCancelledError(error) {
            return .userCancelled
        } else {
            return .unknown
        }
    }

    private func isRecoverable(category: ErrorCategory) -> Bool {
        switch category {
        case .insufficientMemory:
            return true  // Can retry with lower quality
        case .insufficientStorage:
            return false  // User must free space
        case .networkFailure:
            return true  // Can retry
        case .corruptFile:
            return false  // Source file issue
        case .userCancelled:
            return true  // Can restart
        case .unknown:
            return true  // Attempt retry
        }
    }

    private func suggestRecovery(category: ErrorCategory) -> String {
        switch category {
        case .insufficientMemory:
            return "Try closing other apps or reduce video quality"
        case .insufficientStorage:
            return "Free up storage space and try again"
        case .networkFailure:
            return "Check your internet connection"
        case .corruptFile:
            return "The source video file may be corrupted"
        case .userCancelled:
            return "Export was cancelled"
        case .unknown:
            return "An unexpected error occurred. Try again."
        }
    }

    // MARK: - Error Type Detection

    private func isMemoryError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == 3072
    }

    private func isStorageError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == 640
    }

    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private func isCorruptFileError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == AVFoundationErrorDomain
    }

    private func isCancelledError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}

struct ErrorAnalysis {
    var error: Error
    var category: ErrorCategory
    var recoverable: Bool
    var suggestion: String
}

enum ErrorCategory {
    case insufficientMemory
    case insufficientStorage
    case networkFailure
    case corruptFile
    case userCancelled
    case unknown
}
```

**Tasks**:
- [ ] Implement error analyzer
- [ ] Add error categorization tests
- [ ] Test recovery suggestions

---

## 5. Progress Tracking

### Purpose
Provide detailed, accurate progress information to users during processing.

### Architecture

```
ReTakeAi/Core/Progress/
├── ProcessingProgress.swift              // Progress model
└── ProgressEstimator.swift               // Estimate remaining time
```

### Step 5.1: Create ProcessingProgress Model

**File**: `ReTakeAi/Core/Progress/ProcessingProgress.swift`

```swift
import Foundation

@Observable
class ProcessingProgress: Codable {
    // Overall progress (0.0 to 1.0)
    var overall: Double = 0.0
    var currentStage: String = "Preparing..."

    // Pass 1 progress (per take)
    var pass1Audio: [UUID: Double] = [:]
    var pass1Video: [UUID: Double] = [:]
    var pass1TotalTakes: Int = 0

    // Pass 2 progress
    var audioAssembly: Double = 0.0
    var videoAssembly: Double = 0.0
    var syncCompensation: Double = 0.0
    var finalEncoding: Double = 0.0

    // Time estimation
    var estimatedTimeRemaining: TimeInterval?
    var processingSpeed: Double = 1.0  // x realtime

    // Stage weights (sum to 1.0)
    private let weights = ProcessingWeights(
        pass1Audio: 0.25,
        pass1Video: 0.30,
        audioAssembly: 0.15,
        videoAssembly: 0.15,
        syncCompensation: 0.05,
        finalEncoding: 0.10
    )

    /// Update Pass 1 audio progress
    func updatePass1Audio(takeID: UUID, progress: Double) {
        pass1Audio[takeID] = progress
        recalculateOverall()
    }

    /// Update Pass 1 video progress
    func updatePass1Video(takeID: UUID, progress: Double) {
        pass1Video[takeID] = progress
        recalculateOverall()
    }

    /// Recalculate overall progress
    private func recalculateOverall() {
        var total: Double = 0.0

        // Pass 1 Audio (average across all takes)
        let audioProgress = pass1Audio.values.reduce(0.0, +) / Double(max(pass1TotalTakes, 1))
        total += audioProgress * weights.pass1Audio

        // Pass 1 Video
        let videoProgress = pass1Video.values.reduce(0.0, +) / Double(max(pass1TotalTakes, 1))
        total += videoProgress * weights.pass1Video

        // Pass 2
        total += audioAssembly * weights.audioAssembly
        total += videoAssembly * weights.videoAssembly
        total += syncCompensation * weights.syncCompensation
        total += finalEncoding * weights.finalEncoding

        overall = total
    }

    /// Update current stage
    func updateStage(_ stage: ProcessingState) {
        switch stage {
        case .pending:
            currentStage = "Preparing..."
        case .pass1Audio:
            currentStage = "Processing audio..."
        case .pass1Video:
            currentStage = "Processing video..."
        case .pass2AudioAssembly:
            currentStage = "Assembling audio..."
        case .pass2VideoAssembly:
            currentStage = "Assembling video..."
        case .syncCompensation:
            currentStage = "Synchronizing..."
        case .finalEncoding:
            currentStage = "Encoding final video..."
        case .completed:
            currentStage = "Complete!"
        case .failed:
            currentStage = "Failed"
        case .cancelled:
            currentStage = "Cancelled"
        }
    }
}

struct ProcessingWeights: Codable {
    var pass1Audio: Double
    var pass1Video: Double
    var audioAssembly: Double
    var videoAssembly: Double
    var syncCompensation: Double
    var finalEncoding: Double
}
```

**Tasks**:
- [ ] Implement progress model
- [ ] Add progress calculation tests
- [ ] Test weight distribution

---

### Step 5.2: Create ProgressEstimator

**File**: `ReTakeAi/Core/Progress/ProgressEstimator.swift`

```swift
import Foundation
import CoreMedia

class ProgressEstimator {
    private var startTime: Date?
    private var progressHistory: [(timestamp: Date, progress: Double)] = []

    /// Start tracking
    func start() {
        startTime = Date()
        progressHistory.removeAll()
    }

    /// Update progress
    func update(progress: Double) {
        progressHistory.append((Date(), progress))

        // Keep only recent history (last 30 seconds)
        let cutoff = Date().addingTimeInterval(-30)
        progressHistory.removeAll { $0.timestamp < cutoff }
    }

    /// Estimate time remaining
    func estimateTimeRemaining(currentProgress: Double) -> TimeInterval? {
        guard let start = startTime,
              currentProgress > 0.01,
              progressHistory.count > 5 else {
            return nil
        }

        // Calculate average progress rate
        let elapsed = Date().timeIntervalSince(start)
        let progressRate = currentProgress / elapsed  // progress per second

        // Estimate remaining time
        let remainingProgress = 1.0 - currentProgress
        let estimatedRemaining = remainingProgress / progressRate

        // Smooth estimate using recent history
        let recentRate = calculateRecentRate()
        let smoothedEstimate = recentRate > 0 ? remainingProgress / recentRate : estimatedRemaining

        return smoothedEstimate
    }

    /// Calculate processing speed (x realtime)
    func calculateProcessingSpeed(videoDuration: CMTime, elapsed: TimeInterval) -> Double {
        let videoSeconds = CMTimeGetSeconds(videoDuration)
        guard elapsed > 0 else { return 0 }
        return videoSeconds / elapsed
    }

    private func calculateRecentRate() -> Double {
        guard progressHistory.count >= 2 else { return 0 }

        let recent = progressHistory.suffix(10)
        guard let first = recent.first, let last = recent.last else { return 0 }

        let progressDelta = last.progress - first.progress
        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)

        guard timeDelta > 0 else { return 0 }
        return progressDelta / timeDelta
    }

    /// Format time remaining for display
    func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60

        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
```

**Tasks**:
- [ ] Implement progress estimator
- [ ] Add time estimation tests
- [ ] Test accuracy over time

---

### Step 5.3: Create ProgressView UI

**File**: `ReTakeAi/Features/VideoExport/ProgressView.swift`

```swift
import SwiftUI

struct ExportProgressView: View {
    @ObservedObject var task: ExportTask

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text(task.projectTitle)
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    ExportQueue.shared.cancel(taskID: task.id)
                }
                .foregroundColor(.red)
            }

            // Overall progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.currentStage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(task.progress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)

                if let estimatedTime = task.processingSession?.progress.estimatedTimeRemaining {
                    Text("About \(ProgressEstimator().formatTimeRemaining(estimatedTime)) remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Detailed progress (expandable)
            if let session = task.processingSession {
                DetailedProgressView(progress: session.progress)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct DetailedProgressView: View {
    let progress: ProcessingProgress
    @State private var isExpanded = false

    var body: some View {
        VStack {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text("Details")
                        .font(.caption)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressRow(label: "Audio Processing", value: avgProgress(progress.pass1Audio))
                    ProgressRow(label: "Video Processing", value: avgProgress(progress.pass1Video))
                    ProgressRow(label: "Audio Assembly", value: progress.audioAssembly)
                    ProgressRow(label: "Video Assembly", value: progress.videoAssembly)
                    ProgressRow(label: "Final Encoding", value: progress.finalEncoding)
                }
                .padding(.top, 8)
            }
        }
    }

    private func avgProgress(_ dict: [UUID: Double]) -> Double {
        guard !dict.isEmpty else { return 0 }
        return dict.values.reduce(0, +) / Double(dict.count)
    }
}

struct ProgressRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(value * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
```

**Tasks**:
- [ ] Implement progress UI
- [ ] Add animations
- [ ] Test UI updates

---

## Integration Plan

### Phase 1: Core Infrastructure (Week 1-2)
1. Implement Unified Coordination Layer
2. Add TimingMap and SyncCompensation
3. Integration tests

### Phase 2: Caching System (Week 2-3)
1. Implement ProcessingCacheManager
2. Add cache key generation
3. Test cache hit/miss scenarios

### Phase 3: Export Queue (Week 3-4)
1. Implement ExportQueue
2. Add background processing
3. Test queue management

### Phase 4: Error Recovery (Week 4-5)
1. Implement CheckpointManager
2. Add recovery logic
3. Test failure scenarios

### Phase 5: Progress Tracking (Week 5-6)
1. Implement progress models
2. Add time estimation
3. Build progress UI

### Phase 6: Integration & Testing (Week 6-7)
1. Integrate all components
2. End-to-end testing
3. Performance optimization
4. User testing

---

## Testing Strategy

### Unit Tests
- [ ] TimingMap calculations
- [ ] Cache key generation
- [ ] Progress calculations
- [ ] Error categorization
- [ ] Checkpoint serialization

### Integration Tests
- [ ] Complete export pipeline
- [ ] Cache hit/miss scenarios
- [ ] Resume from checkpoint
- [ ] Background task handling
- [ ] A/V sync verification

### Performance Tests
- [ ] Large video processing (>10 min)
- [ ] Multiple concurrent exports
- [ ] Cache performance
- [ ] Memory usage during export
- [ ] Background processing efficiency

### User Experience Tests
- [ ] Progress accuracy
- [ ] Time estimation accuracy
- [ ] Background export completion
- [ ] Error message clarity
- [ ] Recovery success rate

---

## Files to Update

### Existing Files
- `ReTakeAi/Core/Utilities/AppEnvironment.swift` - Add coordinator
- `ReTakeAi/Core/Services/MediaProcessing/VideoMerger.swift` - Use coordinator
- `ReTakeAi/Core/Models/Project.swift` - Add preset IDs
- `ReTakeAi/Features/VideoExport/VideoExportViewModel.swift` - Use export queue

### New Files
See folder structure at beginning of each section.

---

## Success Criteria

✅ **Unified Coordination**
- Perfect A/V sync (<100ms drift) in all exports
- Timing changes properly compensated

✅ **Caching**
- >80% cache hit rate for preset reuse
- Processing 5x faster when cached
- Cache stays under 2GB

✅ **Export Queue**
- Exports complete in background
- Queue persists across app restarts
- Notifications delivered reliably

✅ **Error Recovery**
- >90% of failures recoverable
- Resume within 5s of restart
- No data loss on failure

✅ **Progress**
- Progress updates at least 2x per second
- Time estimates within 20% accuracy
- No frozen/hung indicators

---

## End of Implementation Plan

**Last Updated**: 2025-01-31
**Version**: 1.0
**Status**: Ready for Implementation
