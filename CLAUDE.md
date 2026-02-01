---
description: 
alwaysApply: true
---

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ReTakeAi is an iOS/macOS video recording application that helps users create professional scene-based videos with AI-powered script generation, teleprompter functionality, and multi-take recording. The app follows a workflow: Script → Scene Generation → Recording (with Teleprompter) → Preview → Export.

## Build & Development

### Building the Project
```bash
# Open in Xcode
open ReTakeAi.xcodeproj

# Build from command line
xcodebuild -project ReTakeAi.xcodeproj -scheme ReTakeAi -configuration Debug build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -project ReTakeAi.xcodeproj -scheme ReTakeAi -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -project ReTakeAi.xcodeproj -scheme ReTakeAi -only-testing:ReTakeAiTests/TestClassName/testMethodName
```

### Configuration
- **Secrets**: OpenAI API key stored in `Secrets.xcconfig` (gitignored)
- **Info.plist**: Privacy permissions for camera/microphone embedded in project settings

## Architecture

### MVVM + Service-Based Architecture

The codebase follows **MVVM** pattern with a centralized service layer:

- **Views**: SwiftUI views (presentation)
- **ViewModels**: `@Observable` classes managing state and business logic
- **Models**: `Codable` structs representing domain entities
- **Services**: Singleton services accessed via `AppEnvironment.shared`

**Entry Point**: `ReTakeAiApp.swift` → `ContentView.swift` → `ProjectListView.swift`

### Core Directory Structure

```
ReTakeAi/
├── Core/
│   ├── Models/           # Domain models (Project, VideoScene, Take)
│   ├── Services/
│   │   ├── Storage/      # ProjectStore, SceneStore, TakeStore, FileStorageManager
│   │   ├── Recording/    # RecordingController, CameraService, AudioService
│   │   ├── MediaProcessing/  # VideoExporter, VideoMerger, ThumbnailGenerator
│   │   └── AI/           # OpenAI integration, scene generation
│   └── Utilities/        # AppEnvironment, AppLogger, Constants, Extensions
│
├── Features/             # Feature modules (each with View + ViewModel)
│   ├── ProjectList/      # Home screen, project management
│   ├── ScriptInput/      # Script creation/editing
│   ├── SceneGeneration/  # AI scene breakdown
│   ├── Shoot/            # Scene shooting workflow
│   ├── Recording/        # Video capture interface
│   ├── Teleprompter/     # Script scrolling overlay
│   ├── VideoExport/      # Final video assembly
│   └── Settings/         # User preferences
│
└── Shared/               # Reusable UI components
```

### Key Data Models

```
Project (root entity)
├── sceneIDs: [UUID]              # References to VideoScenes
├── script: String?                # User's script
├── scriptIntent: ScriptIntent     # Video purpose (explain, promote, etc.)
├── videoAspect: VideoAspect       # Aspect ratio
├── exports: [ExportedVideo]       # Export history
└── status: ProjectStatus          # draft, recording, completed, exported

VideoScene (contains recordings)
├── projectID: UUID
├── scriptText: String             # Scene-specific script
├── takeIDs: [UUID]                # Multiple takes per scene
├── selectedTakeID: UUID?          # Best take for export
├── aiDirection: AIDirection?      # AI-generated performance notes
└── duration: TimeInterval?

Take (individual recording)
├── sceneID: UUID
├── recordedAt: Date
├── duration: TimeInterval
├── fileURL: URL                   # Video file path
├── thumbnailURL: URL?
├── aiScore: Double?               # AI quality rating
└── aiNotes: String?               # AI feedback
```

**Relationships**:
- 1 Project → N VideoScenes (via `sceneIDs`)
- 1 VideoScene → N Takes (via `takeIDs`)
- 1 VideoScene → 1 Selected Take (for final export)

### Service Layer

**AppEnvironment.shared** provides centralized access to all services:

```swift
AppEnvironment.shared.projectStore      // Project CRUD
AppEnvironment.shared.sceneStore        // Scene management
AppEnvironment.shared.takeStore         // Take storage
AppEnvironment.shared.recordingController  // Video recording
AppEnvironment.shared.cameraService     // Camera control
AppEnvironment.shared.aiService         // OpenAI integration
```

**Storage**: File-based JSON persistence using `Codable`
- Directory: `/Documents/ReTakeAi/projects/{projectID}/scenes/{sceneID}/takes/`
- Each entity saved as `.json` file
- Video files stored alongside metadata

**Recording Flow**:
1. `RecordingController` orchestrates AVFoundation
2. `CameraService` manages camera session
3. `AudioService` handles audio configuration
4. `TeleprompterView` syncs with recording
5. Recording auto-stops when teleprompter finishes

**AI Integration**:
- Protocol-based (`AIServiceProtocol`) allows mock/real implementations
- `OpenAINarrationAndScenesService` generates scene breakdowns from scripts
- `SceneBreakdownGenerator` creates structured scene lists
- API key configured in `Secrets.xcconfig`

**Video Export**:
- `VideoMerger` assembles selected takes from multiple scenes
- `VideoExporter` handles encoding and aspect ratio scaling
- Supports transitions between scenes
- Output to user's photo library or file system

## Common Development Tasks

### Adding a New Feature Module

1. Create folder in `Features/` (e.g., `Features/NewFeature/`)
2. Add View: `NewFeatureView.swift` (SwiftUI)
3. Add ViewModel: `NewFeatureViewModel.swift` (use `@Observable`)
4. Add to navigation in appropriate parent view
5. Update `AppEnvironment` if new service needed

### Adding a New Model

1. Create in `Core/Models/`
2. Conform to `Codable` and `Identifiable`
3. Use `StableID()` for UUID generation (ensures backward compat)
4. Add to appropriate Store (ProjectStore, SceneStore, etc.)

### Working with Stores

```swift
// Read
let project = AppEnvironment.shared.projectStore.project(id: projectID)

// Create
let newProject = Project(title: "My Video", scriptIntent: .explain)
try AppEnvironment.shared.projectStore.save(newProject)

// Update
project.title = "Updated Title"
try AppEnvironment.shared.projectStore.save(project)

// Delete
try AppEnvironment.shared.projectStore.delete(projectID: projectID)
```

### Recording Workflow

```swift
// Start recording
AppEnvironment.shared.recordingController.startRecording { result in
    switch result {
    case .success(let url):
        // Create Take from recording
        let take = Take(sceneID: sceneID, fileURL: url, duration: duration)
        try AppEnvironment.shared.takeStore.save(take)
    case .failure(let error):
        // Handle error
    }
}

// Stop recording
AppEnvironment.shared.recordingController.stopRecording()
```

### OpenAI Integration

```swift
// Generate scenes from script
let service = AppEnvironment.shared.aiService
let scenes = try await service.generateScenes(
    from: script,
    intent: .explain,
    toneMood: .professional
)

// Response is structured as [GeneratedSceneDraft]
for sceneDraft in scenes {
    let scene = VideoScene(
        projectID: projectID,
        scriptText: sceneDraft.sceneText,
        aiDirection: sceneDraft.direction
    )
    try AppEnvironment.shared.sceneStore.save(scene)
}
```

## Important Patterns

### State Management
- Use `@Observable` macro for ViewModels (iOS 17+)
- Stores use `@Published` for SwiftUI updates
- `@MainActor` on ViewModels for thread safety

### Error Handling
- Use `AppLogger` for structured logging: `AppLogger.ui.info("message")`
- Categories: `.ui`, `.recording`, `.storage`, `.ai`, `.mediaProcessing`
- ViewModels expose error properties for UI display

### Backward Compatibility
- Models use `decodeIfPresent` for new optional properties
- Maintain file format compatibility across versions
- Test migration from older data formats

### Navigation
- Use `NavigationStack` with `NavigationPath`
- Deep linking supported via path restoration
- Modal sheets for creation flows

### Video Processing
- Use `AVFoundation` for all video/audio operations
- Generate thumbnails asynchronously
- Handle different aspect ratios (9:16, 16:9, 1:1, 4:5)
- Always check camera/microphone permissions before recording

## Testing Considerations

- Mock `AIServiceProtocol` for tests (use `MockAIService`)
- File storage uses app's Documents directory (can be cleared in tests)
- Test recordings should use short durations
- Verify `Codable` compatibility when modifying models

## Key Files to Reference

- `ReTakeAi/Core/Utilities/AppEnvironment.swift` - Service container
- `ReTakeAi/Core/Services/Storage/FileStorageManager.swift` - File organization
- `ReTakeAi/Core/Services/Recording/RecordingController.swift` - Recording logic
- `ReTakeAi/Core/Services/AI/OpenAINarrationAndScenesService.swift` - AI integration
- `ReTakeAi/Core/Services/MediaProcessing/VideoMerger.swift` - Video assembly
- `ReTakeAi/Features/ProjectList/ProjectListViewModel.swift` - Main app logic

## Planned Features

### Audio Processing Engine
See `AUDIO_ENGINE_DESIGN.md` for detailed plans on production-grade audio processing:
- Noise reduction, compression, de-essing, voice enhancement
- Preset-based system (Studio Voice, Podcast Pro, etc.)
- Two-pass processing: Scene-level enhancement → Full-merge assembly
- Dead air trimming at scene boundaries (preserves timing within scenes)
- Smart transitions and full-merge processing for cohesive sound
- Perfect A/V sync with video processing

### Video Processing Engine
See `VIDEO_ENGINE_DESIGN.md` for detailed plans on production-grade video processing:
- Color grading, LUTs, cinematic looks
- Quality enhancements (denoise, sharpen, stabilization)
- Scene transitions (crossfade, fade to black, wipes, etc.)
- Compression & encoding with adaptive bitrate
- Preset-based system (Natural, Cinematic, Vibrant Social, etc.)
- Two-pass processing: Scene-level grading → Master assembly
- Intelligent color matching across scenes
- GPU-accelerated with Metal for performance
- Unified processing with audio engine for perfect sync

## Platform Support

- **Target**: iOS 17.0+, macOS 14.0+
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Dependencies**: None (uses native frameworks only)
