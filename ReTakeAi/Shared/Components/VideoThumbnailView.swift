//
//  VideoThumbnailView.swift
//  ReTakeAi
//

import SwiftUI
import AVFoundation

struct VideoThumbnailView: View {
    let videoURL: URL
    let isPortrait: Bool
    let durationText: String?
    var maxPixelSize: CGSize = CGSize(width: 1024, height: 1024)

    @State private var image: UIImage?
    @State private var loadingComplete = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loadingComplete {
                // File missing or failed to generate
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "video.slash")
                        .foregroundStyle(.secondary)
                }
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    ProgressView()
                }
            }
        }
        .aspectRatio(isPortrait ? (9.0 / 16.0) : (16.0 / 9.0), contentMode: .fill)
        .clipped()
        .overlay(alignment: .bottomTrailing) {
            if let durationText, !durationText.isEmpty {
                Text(durationText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(6)
            }
        }
        .task(id: videoURL) {
            loadingComplete = false
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                self.image = nil
                loadingComplete = true
                return
            }
            do {
                let thumb = try await ThumbnailGenerator.shared.generateThumbnail(
                    from: videoURL,
                    at: CMTime(seconds: 0.5, preferredTimescale: 600),
                    size: maxPixelSize
                )
                self.image = thumb
            } catch {
                self.image = nil
            }
            loadingComplete = true
        }
    }
}


