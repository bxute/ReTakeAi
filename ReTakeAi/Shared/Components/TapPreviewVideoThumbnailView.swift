//
//  TapPreviewVideoThumbnailView.swift
//  ReTakeAi
//

import SwiftUI
import AVFoundation

@MainActor
final class TapPreviewPlayerController: ObservableObject {
    let player: AVPlayer
    private var stopWorkItem: DispatchWorkItem?

    @Published var isPlaying = false

    init(url: URL) {
        self.player = AVPlayer(url: url)
        self.player.isMuted = true
        self.player.volume = 0
        self.player.actionAtItemEnd = .pause
        self.player.rate = 0
    }

    func playPreview(maxSeconds: TimeInterval) {
        stopWorkItem?.cancel()
        isPlaying = true

        player.isMuted = true
        player.volume = 0
        player.seek(to: .zero)
        player.play()

        let clamped = max(0.1, min(maxSeconds, 3.0))
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.player.pause()
            self.player.seek(to: .zero)
            self.isPlaying = false
        }
        stopWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + clamped, execute: item)
    }

    func stop() {
        stopWorkItem?.cancel()
        stopWorkItem = nil
        player.pause()
        player.seek(to: .zero)
        isPlaying = false
    }
}

struct TapPreviewVideoThumbnailView: View {
    let url: URL
    let maxPreviewSeconds: TimeInterval
    let isPortrait: Bool

    @StateObject private var controller: TapPreviewPlayerController

    init(
        url: URL,
        maxPreviewSeconds: TimeInterval = 2.5,
        isPortrait: Bool
    ) {
        self.url = url
        self.maxPreviewSeconds = maxPreviewSeconds
        self.isPortrait = isPortrait
        _controller = StateObject(wrappedValue: TapPreviewPlayerController(url: url))
    }

    var body: some View {
        Button {
            controller.playPreview(maxSeconds: maxPreviewSeconds)
        } label: {
            ZStack {
                PlayerLayerView(player: controller.player)
                    .aspectRatio(isPortrait ? (9.0 / 16.0) : (16.0 / 9.0), contentMode: .fill)
                    .clipped()

                if !controller.isPlaying {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .offset(x: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .onDisappear {
            controller.stop()
        }
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}


