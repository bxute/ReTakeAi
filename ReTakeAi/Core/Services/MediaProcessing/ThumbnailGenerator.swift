//
//  ThumbnailGenerator.swift
//  SceneFlow
//

import AVFoundation
import UIKit

actor ThumbnailGenerator {
    static let shared = ThumbnailGenerator()
    
    private init() {}
    
    func generateThumbnail(
        from videoURL: URL,
        at time: CMTime = .zero,
        size: CGSize = CGSize(width: 200, height: 200)
    ) async throws -> UIImage {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = size
        
        let cgImage = try await imageGenerator.image(at: time).image
        
        return UIImage(cgImage: cgImage)
    }
    
    func saveThumbnail(
        from videoURL: URL,
        to destinationURL: URL,
        at time: CMTime = .zero,
        size: CGSize = CGSize(width: 200, height: 200)
    ) async throws -> URL {
        let thumbnail = try await generateThumbnail(from: videoURL, at: time, size: size)
        
        guard let data = thumbnail.jpegData(compressionQuality: 0.8) else {
            throw ThumbnailError.cannotGenerateImage
        }
        
        try data.write(to: destinationURL)
        
        AppLogger.processing.info("Thumbnail saved: \(destinationURL.lastPathComponent)")
        return destinationURL
    }
    
    func generateMultipleThumbnails(
        from videoURL: URL,
        count: Int = 5,
        size: CGSize = CGSize(width: 200, height: 200)
    ) async throws -> [UIImage] {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        
        let interval = duration.seconds / Double(count + 1)
        var thumbnails: [UIImage] = []
        
        for i in 1...count {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            let thumbnail = try await generateThumbnail(from: videoURL, at: time, size: size)
            thumbnails.append(thumbnail)
        }
        
        return thumbnails
    }
}

enum ThumbnailError: LocalizedError {
    case cannotGenerateImage
    case invalidVideoURL
    
    var errorDescription: String? {
        switch self {
        case .cannotGenerateImage:
            return "Cannot generate thumbnail image"
        case .invalidVideoURL:
            return "Invalid video URL"
        }
    }
}
