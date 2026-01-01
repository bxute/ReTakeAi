//
//  Constants.swift
//  SceneFlow
//

import Foundation

enum Constants {
    enum Storage {
        static let appDirectoryName = "SceneFlow"
        static let projectsDirectoryName = "Projects"
        static let scenesDirectoryName = "Scenes"
        static let takesDirectoryName = "Takes"
        static let exportsDirectoryName = "Exports"
        static let cacheDirectoryName = "Cache"
        static let thumbnailsDirectoryName = "thumbnails"
        
        static let projectFileName = "project.json"
        static let sceneFileName = "scene.json"
        static let takeFilePrefix = "take_"
        static let thumbnailSuffix = "_thumb.jpg"
    }
    
    enum Recording {
        static let videoExtension = "mov"
        static let defaultFrameRate: Int32 = 30
        static let defaultBitRate = 10_000_000
        static let minRecordingDuration: TimeInterval = 0.5
    }
    
    enum AI {
        static let defaultTemperature: Double = 0.7
        static let maxTokens = 2000
    }
    
    enum UI {
        static let defaultAnimationDuration: Double = 0.3
        static let thumbnailSize: CGFloat = 80
        static let cornerRadius: CGFloat = 12
    }
}
