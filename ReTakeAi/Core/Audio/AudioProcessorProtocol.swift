//
//  AudioProcessorProtocol.swift
//  ReTakeAi
//
//  Base protocol for pluggable audio processors
//

import Foundation
import AVFoundation

/// Configuration parameters for a processor
struct ProcessorConfig {
    var parameters: [String: Any]

    init(_ parameters: [String: Any] = [:]) {
        self.parameters = parameters
    }

    subscript(key: String) -> Any? {
        get { parameters[key] }
        set { parameters[key] = newValue }
    }
}

/// Protocol for audio processors that can be plugged into the processing chain
protocol AudioProcessorProtocol {
    /// Unique identifier for the processor
    var id: String { get }

    /// Human-readable name
    var name: String { get }

    /// Default configuration
    var defaultConfig: ProcessorConfig { get }

    /// Process audio from input URL to output URL with given configuration
    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws
}

extension AudioProcessorProtocol {
    /// Convenience method to process with default config
    func process(inputURL: URL, outputURL: URL) async throws {
        try await process(inputURL: inputURL, outputURL: outputURL, config: defaultConfig)
    }
}
