//
//  Logger.swift
//  SceneFlow
//

import Foundation
import os.log

struct AppLogger {
    static let recording = Logger(subsystem: "com.retakeai", category: "Recording")
    static let storage = Logger(subsystem: "com.retakeai", category: "Storage")
    static let processing = Logger(subsystem: "com.retakeai", category: "Processing")
    static let mediaProcessing = Logger(subsystem: "com.retakeai", category: "MediaProcessing")
    static let ui = Logger(subsystem: "com.retakeai", category: "UI")
    static let ai = Logger(subsystem: "com.retakeai", category: "AI")
}
