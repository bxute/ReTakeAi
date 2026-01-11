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

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
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
            do {
                let thumb = try await ThumbnailGenerator.shared.generateThumbnail(
                    from: videoURL,
                    at: CMTime(seconds: 0.0, preferredTimescale: 600),
                    size: CGSize(width: 360, height: 360)
                )
                self.image = thumb
            } catch {
                self.image = nil
            }
        }
    }
}


